-- ============================================================================
-- Zomato District clone - Schema (DDL)
-- ============================================================================
-- 13 tables, designed in 3NF. Grouped into three layers by FK dependency:
--   1. Independent entities (no outgoing FKs):
--        User, Event_Category, Location, Host, Performer, Offer
--   2. Dependent entities (FKs to layer 1, hold the business core):
--        Event, Booking, Transaction, Review
--   3. Bridge tables (resolve M:N relationships, composite PK):
--        Saved_Item, Event_Performer, Booking_Offer
--
-- Why 13 tables and not 4-5 fat ones?
--   Each split below is justified by a specific normalization rule. Collapsing
--   any of them would either violate 1NF (repeating groups), 2NF (partial
--   dependency on a composite key) or 3NF (transitive dependency through a
--   non-key attribute). The price we pay is JOINs at read time; the price we
--   would have paid otherwise is update anomalies and storage redundancy.
--
-- Naming conventions:
--   - Tables: PascalCase singular (User, not Users).
--   - PKs: <table>_id, INT AUTO_INCREMENT (surrogate keys for stability).
--   - FKs: same column name as the referenced PK.
--   - Indexes: idx_<table>_<column>.
--   - Bridge tables: composite PK on the two FK columns.
-- ============================================================================

DROP DATABASE IF EXISTS zomato_district;
CREATE DATABASE zomato_district;
USE zomato_district;

-- ============================================================================
-- LAYER 1 - INDEPENDENT ENTITIES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- User
-- ----------------------------------------------------------------------------
-- An end customer of the platform.
-- Candidate keys: user_id (PK, surrogate), email (UNIQUE, natural candidate key).
-- Normalization:
--   1NF: every column is atomic. dob/anniversary_date stored as DATE, not as
--        a free-text string; phone_number is a single VARCHAR (no separate
--        country_code+number columns we would have to keep in sync).
--   2NF: trivially satisfied - single-column PK so there are no partial
--        dependencies to worry about.
--   3NF: occupation and city are kept inline as VARCHAR rather than FKs to
--        Occupation/City lookup tables. This is a deliberate denormalization:
--        the lookup tables would have one column each (just the name) and
--        give us nothing in return except an extra JOIN. Documented as a
--        trade-off, not an oversight.
-- ----------------------------------------------------------------------------
CREATE TABLE User (
    user_id          INT          AUTO_INCREMENT PRIMARY KEY,
    name             VARCHAR(100) NOT NULL,
    phone_number     VARCHAR(15),
    email            VARCHAR(100) NOT NULL UNIQUE,
    gender           VARCHAR(10)  CHECK (gender IN ('Male','Female','Other')),
    dob              DATE,
    marital_status   VARCHAR(15)  CHECK (marital_status IN ('Single','Married','Other')),
    anniversary_date DATE,
    occupation       VARCHAR(50),
    city             VARCHAR(50)
);

-- ----------------------------------------------------------------------------
-- Event_Category
-- ----------------------------------------------------------------------------
-- A lookup table for event types (Live Music, Comedy, ...).
-- Candidate keys: category_id (PK), category_name (UNIQUE).
-- Normalization:
--   3NF justification - this table exists ONLY to prevent a transitive
--   dependency in Event. If we stored category_name and description directly
--   on Event, then for two rows with the same category_id the description
--   would have to be repeated; updating the description for "Live Music"
--   would require touching every Event row in that category (update anomaly).
--   By promoting category to its own table, description depends only on the
--   category PK - 3NF restored.
-- ----------------------------------------------------------------------------
CREATE TABLE Event_Category (
    category_id   INT          AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50)  NOT NULL UNIQUE,
    description   TEXT
);

-- ----------------------------------------------------------------------------
-- Location
-- ----------------------------------------------------------------------------
-- A physical venue.
-- Candidate keys: location_id (PK). venue_name is NOT unique (chain venues).
-- Normalization:
--   3NF justification - if we inlined venue_name, city, state, locality,
--   pin_code, max_event_capacity onto Event, all of these would be
--   transitively dependent on Event through the venue. Two events at the
--   same Phoenix Marketcity would each carry a duplicate copy of the address;
--   correcting a typo in the pin code would mean updating every Event row.
--   Splitting into Location makes those attributes depend only on
--   location_id - 3NF.
--   1NF: pin_code stays a single atomic VARCHAR (we do not split it into
--        sub-zones - we never query on sub-zone).
-- ----------------------------------------------------------------------------
CREATE TABLE Location (
    location_id        INT          AUTO_INCREMENT PRIMARY KEY,
    venue_name         VARCHAR(100) NOT NULL,
    city               VARCHAR(50)  NOT NULL,
    state              VARCHAR(50)  NOT NULL,
    locality           VARCHAR(100),
    pin_code           VARCHAR(10)  NOT NULL,
    max_event_capacity INT          NOT NULL CHECK (max_event_capacity > 0)
);

-- ----------------------------------------------------------------------------
-- Host
-- ----------------------------------------------------------------------------
-- The organisation putting on an event (BookMyShow Live, Sunburn, ...).
-- Candidate keys: host_id (PK), contact_email (UNIQUE).
-- Normalization:
--   3NF justification - same logic as Event_Category and Location. Without
--   this table, contact_email and contact_number would ride on Event and
--   would be duplicated for every event a host runs.
-- ----------------------------------------------------------------------------
CREATE TABLE Host (
    host_id        INT          AUTO_INCREMENT PRIMARY KEY,
    host_name      VARCHAR(100) NOT NULL,
    contact_email  VARCHAR(100) NOT NULL UNIQUE,
    contact_number VARCHAR(15)
);

-- ----------------------------------------------------------------------------
-- Performer
-- ----------------------------------------------------------------------------
-- An artist or act. Has a many-to-many relationship with Event, resolved
-- through the Event_Performer bridge table below.
-- Normalization:
--   1NF justification - if we tried to put performers directly onto Event,
--   the only options would be (a) a CSV "performers" string column, which is
--   a repeating group and a 1NF violation, or (b) performer_1, performer_2,
--   performer_3 columns, also a repeating group and forcing an arbitrary
--   cap. The bridge-table pattern is the standard 1NF-preserving fix for
--   M:N relationships.
-- ----------------------------------------------------------------------------
CREATE TABLE Performer (
    performer_id   INT          AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    performer_type VARCHAR(50)
);

-- ----------------------------------------------------------------------------
-- Offer
-- ----------------------------------------------------------------------------
-- A discount coupon. Many-to-many with Booking via Booking_Offer.
-- Candidate keys: offer_id (PK), code (UNIQUE - this is what users type).
-- Normalization:
--   3NF justification - type and discount_value are properties of the offer,
--   not of the booking that redeems it. Storing them on Booking_Offer
--   instead would copy the same percentage across every booking that used
--   the same code (update anomaly when the offer changes).
--   Domain CHECKs encode business rules at the schema level (type must be
--   percentage or flat, discount_value > 0, end_date >= start_date) so the
--   database refuses bad data even if the application has a bug.
-- ----------------------------------------------------------------------------
CREATE TABLE Offer (
    offer_id       INT           AUTO_INCREMENT PRIMARY KEY,
    code           VARCHAR(20)   NOT NULL UNIQUE,
    type           VARCHAR(20)   NOT NULL CHECK (type IN ('percentage','flat')),
    discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value > 0),
    start_date     DATE          NOT NULL,
    end_date       DATE          NOT NULL,
    is_active      BOOLEAN       DEFAULT TRUE,
    CHECK (end_date >= start_date)
);

-- ============================================================================
-- LAYER 2 - DEPENDENT ENTITIES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Event
-- ----------------------------------------------------------------------------
-- The core business entity. References Event_Category, Location and Host.
-- Normalization:
--   3NF: title, event_date, start_time, duration, age_limit, price and
--        description all depend on event_id alone. Category, venue and host
--        attributes are deliberately NOT inlined - they are reached by FK
--        join. Read cost: more JOINs. Write cost: zero update anomalies.
-- Concurrency notes (see procedures.sql / advanced.sql):
--   seats_available stores the INITIAL capacity at creation time and is
--   never decremented. The live "seats remaining" figure is derived by
--   fn_seats_remaining() from confirmed bookings. This is a deliberate
--   choice - keeping a mutable counter introduces a race window between
--   the seat check and the decrement; deriving from Booking under
--   FOR UPDATE on the Event row (in sp_book_event) makes the check
--   atomic. Ablation #1 (pessimistic tier) demonstrates this empirically.
--
--   version is the optimistic-locking counter, included purely so we can
--   contrast pessimistic vs optimistic concurrency control in ablation #1.
--   Every successful UPDATE that mutates the Event row should bump version
--   and check the previous value (compare-and-swap). On a CAS miss the
--   client retries or aborts. Pure cost: one INT per row; pure win: no
--   row-level X-lock held for the duration of the transaction. The
--   pessimistic path (FOR UPDATE) does NOT use this column - it relies on
--   InnoDB row locks instead. Both paths coexist so the ablation can show
--   the trade-off side-by-side.
-- ----------------------------------------------------------------------------
CREATE TABLE Event (
    event_id        INT           AUTO_INCREMENT PRIMARY KEY,
    title           VARCHAR(150)  NOT NULL,
    event_date      DATE          NOT NULL,
    start_time      TIME          NOT NULL,
    duration        INT           NOT NULL CHECK (duration > 0),
    age_limit       INT           DEFAULT 0,
    seats_available INT           NOT NULL CHECK (seats_available >= 0),
    price           DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    description     TEXT,
    category_id     INT           NOT NULL,
    location_id     INT           NOT NULL,
    host_id         INT           NOT NULL,
    version         INT           NOT NULL DEFAULT 0,
    FOREIGN KEY (category_id) REFERENCES Event_Category(category_id),
    FOREIGN KEY (location_id) REFERENCES Location(location_id),
    FOREIGN KEY (host_id)     REFERENCES Host(host_id)
);

-- ----------------------------------------------------------------------------
-- Booking
-- ----------------------------------------------------------------------------
-- A user's reservation against an event.
-- Normalization:
--   3NF: does NOT store user_name or event_title - those would be
--        transitive dependencies through user_id / event_id and would go
--        stale if the user renamed themselves or the event was retitled.
-- Design note - total_price is stored, not derived:
--   Strictly, total_price is computable from event.price * number_of_people
--   minus any applied discount, which arguably violates 3NF (it depends on
--   another table). It is stored anyway because:
--     (a) it locks in the price at booking time - if the event price
--         changes later, the booking still reflects what the user paid;
--     (b) refund/audit trails need the as-charged amount, not the current
--         price;
--     (c) it avoids a multi-table JOIN on every booking listing.
--   This is a documented denormalization for auditability.
-- ----------------------------------------------------------------------------
CREATE TABLE Booking (
    booking_id       INT           AUTO_INCREMENT PRIMARY KEY,
    user_id          INT           NOT NULL,
    event_id         INT           NOT NULL,
    number_of_people INT           NOT NULL CHECK (number_of_people > 0),
    total_price      DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    booking_date     DATE          NOT NULL DEFAULT (CURRENT_DATE),
    status           VARCHAR(20)   NOT NULL DEFAULT 'confirmed'
                     CHECK (status IN ('confirmed','cancelled','pending')),
    FOREIGN KEY (user_id)  REFERENCES User(user_id),
    FOREIGN KEY (event_id) REFERENCES Event(event_id)
);

-- ----------------------------------------------------------------------------
-- Transaction
-- ----------------------------------------------------------------------------
-- The payment record for a booking. Currently 1:1 with Booking
-- (booking_id is UNIQUE) but kept as its own table because:
--   (a) payment lifecycle (pending/completed/failed/refunded) is independent
--       of booking lifecycle (confirmed/cancelled/pending) - two state
--       machines, two tables;
--   (b) the 1:1 can be relaxed to 1:N later (split payments, partial
--       refunds) without a schema migration on Booking;
--   (c) keeps payment_method out of the booking listing query for
--       privacy/separation-of-concerns.
-- Normalization: 3NF holds. amount and payment_method depend only on
-- transaction_id.
-- ----------------------------------------------------------------------------
CREATE TABLE Transaction (
    transaction_id   INT           AUTO_INCREMENT PRIMARY KEY,
    booking_id       INT           NOT NULL UNIQUE,
    payment_method   VARCHAR(30)   NOT NULL
                     CHECK (payment_method IN ('UPI','credit_card','debit_card','net_banking','wallet')),
    amount           DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    payment_status   VARCHAR(20)   NOT NULL DEFAULT 'completed'
                     CHECK (payment_status IN ('completed','pending','failed','refunded')),
    transaction_date DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
);

-- ----------------------------------------------------------------------------
-- Review
-- ----------------------------------------------------------------------------
-- One user's rating of one event. The UNIQUE (user_id, event_id) constraint
-- is the business rule "at most one review per user per event"; it also
-- means (user_id, event_id) is a candidate key alongside review_id.
-- Normalization:
--   3NF: rating, comment and review_date depend on review_id alone.
--   Reviewer name and event title are reached by FK, not duplicated.
-- ----------------------------------------------------------------------------
CREATE TABLE Review (
    review_id   INT  AUTO_INCREMENT PRIMARY KEY,
    user_id     INT  NOT NULL,
    event_id    INT  NOT NULL,
    rating      INT  NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    review_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    UNIQUE (user_id, event_id),
    FOREIGN KEY (user_id)  REFERENCES User(user_id),
    FOREIGN KEY (event_id) REFERENCES Event(event_id)
);

-- ============================================================================
-- LAYER 3 - BRIDGE TABLES (M:N RESOLUTION)
-- ============================================================================
-- All three bridges share the same shape: composite PK on the two FK columns,
-- plus optional relationship-specific attributes (saved_date,
-- performance_order, discount_applied). They are 2NF/3NF by construction:
-- the only non-key attributes describe the relationship itself, not either
-- of the joined entities, so there is nowhere for a partial or transitive
-- dependency to hide.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Saved_Item
-- ----------------------------------------------------------------------------
-- Many-to-many between User and Event ("user X has saved event Y").
-- saved_date is a relationship attribute - it describes when this user
-- saved this event, not a property of either the user or the event.
-- ----------------------------------------------------------------------------
CREATE TABLE Saved_Item (
    user_id    INT  NOT NULL,
    event_id   INT  NOT NULL,
    saved_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (user_id, event_id),
    FOREIGN KEY (user_id)  REFERENCES User(user_id),
    FOREIGN KEY (event_id) REFERENCES Event(event_id)
);

-- ----------------------------------------------------------------------------
-- Event_Performer
-- ----------------------------------------------------------------------------
-- Many-to-many between Event and Performer.
-- performance_order is the line-up position - a relationship attribute
-- (the same performer can be the headliner at one event and a support act
-- at another).
-- ----------------------------------------------------------------------------
CREATE TABLE Event_Performer (
    event_id          INT NOT NULL,
    performer_id      INT NOT NULL,
    performance_order INT DEFAULT 1,
    PRIMARY KEY (event_id, performer_id),
    FOREIGN KEY (event_id)     REFERENCES Event(event_id),
    FOREIGN KEY (performer_id) REFERENCES Performer(performer_id)
);

-- ----------------------------------------------------------------------------
-- Booking_Offer
-- ----------------------------------------------------------------------------
-- Many-to-many between Booking and Offer (a booking can stack multiple
-- coupons; an offer applies to many bookings).
-- discount_applied stores the rupee amount actually deducted at redemption
-- time. This is intentionally redundant with Offer.discount_value because
-- Offer.discount_value can change later (campaign edits) but the rupees
-- already taken off this booking must not.
-- ----------------------------------------------------------------------------
CREATE TABLE Booking_Offer (
    booking_id       INT           NOT NULL,
    offer_id         INT           NOT NULL,
    discount_applied DECIMAL(10,2),
    PRIMARY KEY (booking_id, offer_id),
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id),
    FOREIGN KEY (offer_id)   REFERENCES Offer(offer_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
-- All PRIMARY KEY and UNIQUE columns above are automatically B-tree indexed
-- by InnoDB; the indexes below are added explicitly for hot read paths.
-- Each one is justified by a query that runs in the application:
--
--   idx_event_date     - Discover page filters "upcoming events" with
--                        WHERE event_date >= CURRENT_DATE; without this
--                        index that becomes a full table scan. See
--                        ablation #2 for the EXPLAIN before/after.
--   idx_event_category - Category filter dropdown on the Discover page.
--   idx_location_city  - City filter dropdown.
--   idx_booking_user   - "My bookings" lookup by user_id.
--   idx_booking_event  - sp_book_event and fn_seats_remaining both
--                        aggregate Booking by event_id (live seat count);
--                        this index turns that into an index range scan.
--   idx_review_event   - vw_event_dashboard's AVG(rating) aggregation
--                        groups Review by event_id.
-- ============================================================================

CREATE INDEX idx_event_date     ON Event(event_date);
CREATE INDEX idx_event_category ON Event(category_id);
CREATE INDEX idx_location_city  ON Location(city);
CREATE INDEX idx_booking_user   ON Booking(user_id);
CREATE INDEX idx_booking_event  ON Booking(event_id);
CREATE INDEX idx_review_event   ON Review(event_id);
