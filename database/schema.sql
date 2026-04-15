-- Zomato District clone - schema (13 tables, 3NF)
-- Create DB and select it
DROP DATABASE IF EXISTS zomato_district;
CREATE DATABASE zomato_district;
USE zomato_district;

-- ------------------------------------------------------------
-- Independent tables (no FKs)
-- ------------------------------------------------------------

CREATE TABLE User (
    user_id         INT             AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    phone_number    VARCHAR(15),
    email           VARCHAR(100)    NOT NULL UNIQUE,
    gender          VARCHAR(10)     CHECK (gender IN ('Male','Female','Other')),
    dob             DATE,
    marital_status  VARCHAR(15)     CHECK (marital_status IN ('Single','Married','Other')),
    anniversary_date DATE,
    occupation      VARCHAR(50),
    city            VARCHAR(50)
);

CREATE TABLE Event_Category (
    category_id     INT             AUTO_INCREMENT PRIMARY KEY,
    category_name   VARCHAR(50)     NOT NULL UNIQUE,
    description     TEXT
);

CREATE TABLE Location (
    location_id         INT         AUTO_INCREMENT PRIMARY KEY,
    venue_name          VARCHAR(100) NOT NULL,
    city                VARCHAR(50) NOT NULL,
    state               VARCHAR(50) NOT NULL,
    locality            VARCHAR(100),
    pin_code            VARCHAR(10) NOT NULL,
    max_event_capacity  INT         NOT NULL CHECK (max_event_capacity > 0)
);

CREATE TABLE Host (
    host_id         INT             AUTO_INCREMENT PRIMARY KEY,
    host_name       VARCHAR(100)    NOT NULL,
    contact_email   VARCHAR(100)    NOT NULL UNIQUE,
    contact_number  VARCHAR(15)
);

CREATE TABLE Performer (
    performer_id    INT             AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    performer_type  VARCHAR(50)
);

CREATE TABLE Offer (
    offer_id        INT             AUTO_INCREMENT PRIMARY KEY,
    code            VARCHAR(20)     NOT NULL UNIQUE,
    type            VARCHAR(20)     NOT NULL CHECK (type IN ('percentage','flat')),
    discount_value  DECIMAL(10,2)   NOT NULL CHECK (discount_value > 0),
    start_date      DATE            NOT NULL,
    end_date        DATE            NOT NULL,
    is_active       BOOLEAN         DEFAULT TRUE,
    CHECK (end_date >= start_date)
);

-- ------------------------------------------------------------
-- Dependent tables (with FKs)
-- ------------------------------------------------------------

CREATE TABLE Event (
    event_id        INT             AUTO_INCREMENT PRIMARY KEY,
    title           VARCHAR(150)    NOT NULL,
    event_date      DATE            NOT NULL,
    start_time      TIME            NOT NULL,
    duration        INT             NOT NULL CHECK (duration > 0),
    age_limit       INT             DEFAULT 0,
    seats_available INT             NOT NULL CHECK (seats_available >= 0),
    price           DECIMAL(10,2)   NOT NULL CHECK (price >= 0),
    description     TEXT,
    category_id     INT             NOT NULL,
    location_id     INT             NOT NULL,
    host_id         INT             NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Event_Category(category_id),
    FOREIGN KEY (location_id) REFERENCES Location(location_id),
    FOREIGN KEY (host_id)     REFERENCES Host(host_id)
);

CREATE TABLE Booking (
    booking_id       INT            AUTO_INCREMENT PRIMARY KEY,
    user_id          INT            NOT NULL,
    event_id         INT            NOT NULL,
    number_of_people INT            NOT NULL CHECK (number_of_people > 0),
    total_price      DECIMAL(10,2)  NOT NULL CHECK (total_price >= 0),
    booking_date     DATE           NOT NULL DEFAULT (CURRENT_DATE),
    status           VARCHAR(20)    NOT NULL DEFAULT 'confirmed'
                     CHECK (status IN ('confirmed','cancelled','pending')),
    FOREIGN KEY (user_id)  REFERENCES User(user_id),
    FOREIGN KEY (event_id) REFERENCES Event(event_id)
);

CREATE TABLE Transaction (
    transaction_id   INT            AUTO_INCREMENT PRIMARY KEY,
    booking_id       INT            NOT NULL UNIQUE,
    payment_method   VARCHAR(30)    NOT NULL
                     CHECK (payment_method IN ('UPI','credit_card','debit_card','net_banking','wallet')),
    amount           DECIMAL(10,2)  NOT NULL CHECK (amount >= 0),
    payment_status   VARCHAR(20)    NOT NULL DEFAULT 'completed'
                     CHECK (payment_status IN ('completed','pending','failed','refunded')),
    transaction_date DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
);

CREATE TABLE Review (
    review_id    INT          AUTO_INCREMENT PRIMARY KEY,
    user_id      INT          NOT NULL,
    event_id     INT          NOT NULL,
    rating       INT          NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    review_date  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    UNIQUE (user_id, event_id),
    FOREIGN KEY (user_id)  REFERENCES User(user_id),
    FOREIGN KEY (event_id) REFERENCES Event(event_id)
);

-- ------------------------------------------------------------
-- Bridge tables (M:N resolution)
-- ------------------------------------------------------------

CREATE TABLE Saved_Item (
    user_id     INT     NOT NULL,
    event_id    INT     NOT NULL,
    saved_date  DATE    NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (user_id, event_id),
    FOREIGN KEY (user_id)  REFERENCES User(user_id),
    FOREIGN KEY (event_id) REFERENCES Event(event_id)
);

CREATE TABLE Event_Performer (
    event_id           INT  NOT NULL,
    performer_id       INT  NOT NULL,
    performance_order  INT  DEFAULT 1,
    PRIMARY KEY (event_id, performer_id),
    FOREIGN KEY (event_id)     REFERENCES Event(event_id),
    FOREIGN KEY (performer_id) REFERENCES Performer(performer_id)
);

CREATE TABLE Booking_Offer (
    booking_id        INT            NOT NULL,
    offer_id          INT            NOT NULL,
    discount_applied  DECIMAL(10,2),
    PRIMARY KEY (booking_id, offer_id),
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id),
    FOREIGN KEY (offer_id)   REFERENCES Offer(offer_id)
);

-- ------------------------------------------------------------
-- Indexes on frequently queried columns
-- ------------------------------------------------------------

CREATE INDEX idx_event_date      ON Event(event_date);
CREATE INDEX idx_event_category  ON Event(category_id);
CREATE INDEX idx_location_city   ON Location(city);
CREATE INDEX idx_booking_user    ON Booking(user_id);
CREATE INDEX idx_booking_event   ON Booking(event_id);
CREATE INDEX idx_review_event    ON Review(event_id);
