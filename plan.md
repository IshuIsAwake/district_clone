# Zomato District Clone — Project Plan

## Project overview

A Zomato District-style event discovery and booking platform. Users can browse events (concerts, comedy shows, DJ nights, food festivals), book tickets, save favourites, and leave reviews. The database handles the full lifecycle: event listing → booking → payment → review.

**Tech stack:**
- **Database:** MySQL (local), accessed via `mysql-connector-python`
- **SQL runner:** Python scripts (no Workbench)
- **Frontend:** Static HTML/CSS/JS hosted on GitHub Pages
- **Diagrams:** draw.io (ER diagram + class diagram already made)

---

## What the rubric actually wants (40 marks)

| # | Criterion | Marks | What "Good" looks like |
|---|-----------|-------|------------------------|
| 1 | Project file handling & structure | 10 | Clean repo, organized folders, follows report template, <10% plagiarism, zero AI plagiarism |
| 2 | Problem definition & ER design | 8 | Clear problem statement, correct ER with entities + attributes + PKs + cardinality + M:N handled via bridge entities |
| 3 | Schema design & normalization | 8 | Proper PK/FK on all tables, fully normalized to 3NF, no redundancy, basic indexing |
| 4 | SQL implementation | 10 | DDL + DML + DQL + TCL working, JOINs + GROUP BY + HAVING, subqueries, views, stored procedures, functions — all correct and meaningful |
| 5 | Testing & explanation | 4 | Correct output shown, can explain query logic, why each query was used, what the result means |

**Viva topics to prepare:** Project overview, ER diagram, schema design, normalization (1NF/2NF/3NF), keys, SQL basics, joins, GROUP BY & HAVING, subqueries, aggregate & scalar functions, views, stored procedures, transactions (ACID/COMMIT/ROLLBACK), indexing basics, output explanation.

---

## Repository structure

```
zomato-district/
├── README.md
├── plan.md                  (this file)
├── report/
│   ├── report.docx          (final report following Sample.doc template)
│   └── screenshots/         (query outputs, ER diagram, frontend screenshots)
├── database/
│   ├── schema.sql           (all CREATE TABLE statements, standalone)
│   ├── seed_data.sql         (all INSERT statements, standalone)
│   ├── queries.sql           (all SELECT queries with comments)
│   ├── advanced.sql          (views, procedures, functions, TCL, DCL)
│   └── run_all.py            (Python script that executes everything)
├── frontend/
│   ├── index.html            (home — event listing + filters)
│   ├── event.html            (event detail page)
│   ├── booking.html          (booking confirmation page)
│   ├── css/
│   │   └── style.css
│   ├── js/
│   │   ├── data.js           (hardcoded event data as JS arrays)
│   │   ├── home.js           (filter/search/render logic for home)
│   │   ├── event.js          (event detail page logic)
│   │   └── booking.js        (booking page logic)
│   └── assets/               (any images/icons)
└── diagrams/
    ├── ER_Diagram_DJ.drawio
    └── Class_Diagram_DJ.drawio
```

---

## Schema — based on the class diagram

These are the 13 tables as they appear in the class diagram, with notes on constraints to add when writing the SQL.

### Independent tables (no foreign keys)

**1. User**
| Column | Type | Constraints |
|--------|------|-------------|
| user_id | INT | PK, AUTO_INCREMENT |
| name | VARCHAR(100) | NOT NULL |
| phone_number | VARCHAR(15) | |
| email | VARCHAR(100) | NOT NULL, UNIQUE |
| gender | VARCHAR(10) | CHECK IN ('Male','Female','Other') |
| dob | DATE | |
| marital_status | VARCHAR(15) | CHECK IN ('Single','Married','Other') |
| anniversary_date | DATE | nullable — only relevant if married |
| occupation | VARCHAR(50) | |
| city | VARCHAR(50) | |

**2. Event_Category**
| Column | Type | Constraints |
|--------|------|-------------|
| category_id | INT | PK, AUTO_INCREMENT |
| category_name | VARCHAR(50) | NOT NULL, UNIQUE |

*Optional: add a `description` TEXT column — gives you something to query with scalar functions like LENGTH() or UPPER().*

**3. Location**
| Column | Type | Constraints |
|--------|------|-------------|
| location_id | INT | PK, AUTO_INCREMENT |
| venue_name | VARCHAR(100) | NOT NULL |
| city | VARCHAR(50) | NOT NULL |
| state | VARCHAR(50) | NOT NULL |
| locality | VARCHAR(100) | |
| pin_code | VARCHAR(10) | NOT NULL |
| max_event_capacity | INT | NOT NULL, CHECK > 0 |

**4. Host**
| Column | Type | Constraints |
|--------|------|-------------|
| host_id | INT | PK, AUTO_INCREMENT |
| host_name | VARCHAR(100) | NOT NULL |
| contact_email | VARCHAR(100) | NOT NULL, UNIQUE |
| contact_number | VARCHAR(15) | |

**5. Performer**
| Column | Type | Constraints |
|--------|------|-------------|
| performer_id | INT | PK, AUTO_INCREMENT |
| name | VARCHAR(100) | NOT NULL |
| performer_type | VARCHAR(50) | e.g. 'Singer', 'Band', 'DJ', 'Comedian', 'Speaker' |

**6. Offer**
| Column | Type | Constraints |
|--------|------|-------------|
| offer_id | INT | PK, AUTO_INCREMENT |
| code | VARCHAR(20) | NOT NULL, UNIQUE |
| type | VARCHAR(20) | e.g. 'percentage', 'flat' |
| discount_value | DECIMAL(10,2) | NOT NULL, CHECK > 0 |
| start_date | DATE | NOT NULL |
| end_date | DATE | NOT NULL, CHECK >= start_date |
| is_active | BOOLEAN | DEFAULT TRUE |

### Dependent tables (have foreign keys)

**7. Event**
| Column | Type | Constraints |
|--------|------|-------------|
| event_id | INT | PK, AUTO_INCREMENT |
| title | VARCHAR(150) | NOT NULL |
| event_date | DATE | NOT NULL |
| start_time | TIME | NOT NULL |
| duration | INT | NOT NULL, CHECK > 0 (in minutes) |
| age_limit | INT | DEFAULT 0 (0 = no restriction) |
| seats_available | INT | NOT NULL, CHECK >= 0 |
| price | DECIMAL(10,2) | NOT NULL, CHECK >= 0 |
| description | TEXT | |
| category_id | INT | FK → Event_Category.category_id, NOT NULL |
| location_id | INT | FK → Location.location_id, NOT NULL |
| host_id | INT | FK → Host.host_id, NOT NULL |

*Note on seats_available: this is a stored value you UPDATE on each booking. You'll also write a function that computes it dynamically from Booking data — having both shows you understand the tradeoff (stored = fast reads, computed = always accurate). Good viva talking point.*

**8. Booking**
| Column | Type | Constraints |
|--------|------|-------------|
| booking_id | INT | PK, AUTO_INCREMENT |
| user_id | INT | FK → User.user_id, NOT NULL |
| event_id | INT | FK → Event.event_id, NOT NULL |
| number_of_people | INT | NOT NULL, CHECK > 0 |
| total_price | DECIMAL(10,2) | NOT NULL, CHECK >= 0 |
| booking_date | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'confirmed', CHECK IN ('confirmed','cancelled','pending') |

**9. Transaction**
| Column | Type | Constraints |
|--------|------|-------------|
| transaction_id | INT | PK, AUTO_INCREMENT |
| booking_id | INT | FK → Booking.booking_id, NOT NULL, UNIQUE |
| payment_method | VARCHAR(30) | NOT NULL, CHECK IN ('UPI','credit_card','debit_card','net_banking','wallet') |
| amount | DECIMAL(10,2) | NOT NULL, CHECK >= 0 |
| payment_status | VARCHAR(20) | NOT NULL, DEFAULT 'completed', CHECK IN ('completed','pending','failed','refunded') |
| transaction_date | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

**10. Review**
| Column | Type | Constraints |
|--------|------|-------------|
| review_id | INT | PK, AUTO_INCREMENT |
| user_id | INT | FK → User.user_id, NOT NULL |
| event_id | INT | FK → Event.event_id, NOT NULL |
| rating | INT | NOT NULL, CHECK BETWEEN 1 AND 5 |
| comment | TEXT | |
| review_date | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| | | UNIQUE(user_id, event_id) — one review per user per event |

### Bridge tables (M:N resolution)

**11. Saved_Item**
| Column | Type | Constraints |
|--------|------|-------------|
| user_id | INT | FK → User.user_id, NOT NULL |
| event_id | INT | FK → Event.event_id, NOT NULL |
| | | PK(user_id, event_id) |

*Optional:* `saved_date DATE DEFAULT CURRENT_DATE` — lets you query "recently saved items" or "items saved in the last week."

**12. Event_Performer**
| Column | Type | Constraints |
|--------|------|-------------|
| event_id | INT | FK → Event.event_id, NOT NULL |
| performer_id | INT | FK → Performer.performer_id, NOT NULL |
| | | PK(event_id, performer_id) |

*Optional:* `performance_order INT DEFAULT 1` — distinguishes opening act vs headliner. Makes ORDER BY queries more meaningful.

**13. Booking_Offer**
| Column | Type | Constraints |
|--------|------|-------------|
| booking_id | INT | FK → Booking.booking_id, NOT NULL |
| offer_id | INT | FK → Offer.offer_id, NOT NULL |
| | | PK(booking_id, offer_id) |

*Optional:* `discount_applied DECIMAL(10,2)` — actual rupee amount deducted. Useful for SUM/AVG queries on discounts.

---

## Relationships & cardinality

| From | To | Cardinality | Relationship |
|------|----|-------------|--------------|
| User | Booking | 1 : N | one user makes many bookings |
| User | Review | 1 : N | one user writes many reviews |
| User ↔ Event | M : N | resolved via Saved_Item |
| Event | Booking | 1 : N | one event has many bookings |
| Event → Event_Category | N : 1 | many events belong to one category |
| Event → Location | N : 1 | many events held at one location |
| Event → Host | N : 1 | many events organized by one host |
| Event ↔ Performer | M : N | resolved via Event_Performer |
| Booking → Transaction | 1 : 1 | one booking generates one transaction |
| Booking ↔ Offer | M : N | resolved via Booking_Offer |

---

## ER diagram — what to update

Your class diagram is the finished schema. The ER diagram needs to match it:

- Add attribute ovals to every entity (currently only PKs shown in the ER)
- Pull the attribute names from the class diagram tables above
- Add cardinality labels (1, N) on every relationship line
- Underline all primary keys
- Bridge entities (Saved_Item, Event_Performer, Booking_Offer) should use double-bordered rectangles
- FK attributes should be visible on dependent entities (Event, Booking, Transaction, Review)

---

## Normalization argument (for report & viva)

**1NF:** Every column holds atomic values. No repeating groups. An event's performers aren't stored as a comma-separated list — they're in Event_Performer. A user's saved events aren't a list column — they're in Saved_Item.

**2NF:** Every non-key attribute depends on the entire primary key. Matters for composite-key tables:
- `Saved_Item(user_id, event_id)` — if you add `saved_date`, it depends on the full combination (when did *this user* save *this event*), not on user_id alone
- `Event_Performer(event_id, performer_id)` — if you add `performance_order`, it depends on which performer at which event
- `Booking_Offer(booking_id, offer_id)` — if you add `discount_applied`, it depends on which offer was used on which booking

**3NF:** No transitive dependencies. Non-key columns depend only on the PK:
- In Event, `venue_name` and `city` could be derived from `location_id` → that's why they live in Location, not Event. Event only stores `location_id` (FK). No transitive chain.
- Same: `category_name` lives in Event_Category. `host_name` lives in Host.
- In User, `city` depends on user_id directly (it's the user's city), so it stays. No violation.
- In Location, `city` and `state` — Indian cities can share names across states (Hyderabad), so both depend on `location_id` directly. No 3NF issue.

---

## Python script plan (`run_all.py`)

Connects to local MySQL, runs everything in sequence.

```
run_all.py
├── connect()              → returns MySQL connection
├── create_database()      → CREATE DATABASE zomato_district + USE
├── create_tables()        → all 13 CREATE TABLEs in FK-dependency order
│   Order: Event_Category, Location, Host, User, Performer, Offer
│          → Event → Booking → Transaction, Review
│          → Saved_Item, Event_Performer, Booking_Offer
├── create_indexes()       → CREATE INDEX on frequently queried columns
├── insert_data()          → all INSERT statements
├── run_queries()          → all SELECT queries, prints results
│   ├── inner_join()
│   ├── left_join()
│   ├── full_outer_join()
│   ├── self_join()
│   ├── group_by_having()
│   ├── subqueries()
│   └── aggregate_scalar()
├── create_views()         → 3 views
├── create_procedures()    → 3 stored procedures
├── create_functions()     → 2 user-defined functions
├── demo_transactions()    → COMMIT, ROLLBACK, SAVEPOINT
├── demo_dcl()             → CREATE USER, GRANT, REVOKE
└── main()                 → calls everything in order
```

**Key things to know:**
- `mysql-connector-python` handles stored procedures without `DELIMITER //`. Just pass the full CREATE PROCEDURE body to `cursor.execute()`.
- Print section headers like `print("=" * 50)` before each query group so terminal screenshots are clean.
- For nice output formatting, use f-strings or the `tabulate` library.

**Sample data quantities:**
- 7 categories (Live Music, Comedy, DJ Night, Food Festival, Workshop, Theatre, Sports)
- 7 locations (real Indian venues across Delhi, Mumbai, Bangalore, Gurugram)
- 5 hosts
- 10 users (Indian names, mix of cities, ages, occupations)
- 8 performers (Prateek Kuhad, Zakir Khan, Nucleya, The Local Train, etc.)
- 10 events (mix of upcoming/completed, various categories and cities)
- 5 offers (FIRST50, EARLYBIRD, ZOMATO10, GROUP25, WEEKEND15)
- ~15 bookings + transactions
- ~5 reviews (only on completed events — keeps it realistic)
- ~8 saved items, bridge entries for Event_Performer and Booking_Offer

---

## SQL implementation checklist

### DDL
- [ ] CREATE DATABASE zomato_district
- [ ] CREATE TABLE × 13 (with PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT)
- [ ] CREATE INDEX — on event_date, category_id, city (Location), user_id (Booking), event_id (Booking, Review)

### DML
- [ ] INSERT INTO × 13 tables
- [ ] UPDATE — cancel a booking (set status = 'cancelled')
- [ ] DELETE — remove a saved item

### DQL — Joins
- [ ] **INNER JOIN** — bookings with user name, event title, venue_name (Booking ⟶ User ⟶ Event ⟶ Location)
- [ ] **LEFT JOIN** — all events with reviews including unreviewed ones (Event ⟗ Review ⟗ User)
- [ ] **RIGHT JOIN** — all transactions with booking details
- [ ] **FULL OUTER JOIN** (UNION of LEFT + RIGHT) — all users and all bookings
- [ ] **SELF JOIN** — users from the same city

### DQL — Aggregation
- [ ] GROUP BY + HAVING — total revenue per event, only where revenue > ₹2000
- [ ] GROUP BY — average rating per event
- [ ] GROUP BY — booking count per payment_method
- [ ] ORDER BY — events by price, date, rating

### DQL — Subqueries
- [ ] Simple — events priced above the average price
- [ ] IN — users who booked more than one distinct event
- [ ] Correlated — highest-value booking for each event

### DQL — Functions
- [ ] Aggregate: COUNT, SUM, AVG, MIN, MAX on Event and Booking
- [ ] Scalar: UPPER(name), LENGTH(email), CONCAT(name, ' - ', city), DATEDIFF(CURRENT_DATE, dob), COALESCE, ROUND

### Views
- [ ] **vw_event_dashboard** — Event + Location + Host + Event_Category + AVG(rating) + COUNT(reviews)
- [ ] **vw_booking_summary** — Booking + User + Event + Transaction + Booking_Offer
- [ ] **vw_event_lineup** — Event + Event_Performer + Performer

### Stored Procedures
- [ ] **sp_book_event(p_user_id, p_event_id, p_num_people, p_pay_method)** — check seats_available, calculate total_price, INSERT Booking + Transaction, UPDATE seats_available
- [ ] **sp_cancel_booking(p_booking_id)** — UPDATE status to 'cancelled', UPDATE payment_status to 'refunded', restore seats_available
- [ ] **sp_search_events(p_city, p_category)** — parameterized search, returns matching upcoming events

### User-defined Functions
- [ ] **fn_seats_remaining(p_event_id)** → computes seats dynamically from Booking data
- [ ] **fn_apply_discount(p_amount, p_offer_code)** → handles both 'percentage' and 'flat' types using the Offer.type column

### TCL (Transactions)
- [ ] **COMMIT** — booking flow: INSERT booking → INSERT transaction → UPDATE seats → COMMIT
- [ ] **ROLLBACK** — failed payment: INSERT booking → simulate failure → ROLLBACK
- [ ] **SAVEPOINT** — partial: save item (SAVEPOINT) → bad review (fails) → ROLLBACK TO SAVEPOINT → COMMIT

### DCL
- [ ] CREATE USER admin + viewer
- [ ] GRANT ALL to admin
- [ ] GRANT SELECT to viewer
- [ ] REVOKE INSERT from viewer

---

## Frontend plan (GitHub Pages)

Three linked HTML pages. Data hardcoded in `data.js` mirroring the database. No backend.

### Page 1: `index.html` — event listing

- Header with logo + "Zomato District"
- Filter bar: category dropdown, city dropdown, text search
- Event cards grid showing: category badge, title, date, start_time, venue_name, city, price, seats_available bar, age_limit badge if > 0
- Click card → `event.html?id=3`

### Page 2: `event.html` — event detail

- Reads `?id=` from URL, finds event in data.js
- Event info: title, description, event_date, start_time, duration, price, age_limit, seats left
- Venue: venue_name, locality, city, state
- Host: host_name, contact_email
- Performer lineup: names + performer_type (from Event_Performer data)
- Reviews: rating stars, comment, reviewer name, review_date
- Buttons: "Book Now" → `booking.html?id=3`, "Save" (localStorage toggle)

### Page 3: `booking.html` — booking flow

- Reads `?id=` from URL
- Event summary (title, date, venue, price)
- Number of people selector (+/-)
- Age limit warning if applicable
- Offer code input + "Apply" (validates against Offer data, handles percentage vs flat)
- Price breakdown: price × people, discount line, total
- Payment method dropdown
- "Confirm" → success message with fake booking_id

### Styling
- Single `style.css`, no frameworks
- Clean sans-serif, white background, one accent colour
- Category badges colour-coded
- Basic mobile-friendliness (flexbox, media queries)

---

## Task order

### Phase 1: Foundation
1. Update ER diagram — add attribute ovals from class diagram, add cardinality labels
2. Write `schema.sql` — 13 CREATE TABLEs in FK-dependency order
3. Write `seed_data.sql` — all INSERTs with realistic data
4. Set up `run_all.py` — connect, run schema + seed, verify

### Phase 2: Queries
5. All JOIN queries
6. GROUP BY / HAVING / ORDER BY
7. Subqueries
8. Aggregate + scalar functions
9. Create 3 views
10. Create stored procedures + functions
11. TCL demos
12. DCL statements

### Phase 3: Frontend (can overlap with Phase 2)
13. Create `data.js`
14. Build `index.html` + `home.js`
15. Build `event.html` + `event.js`
16. Build `booking.html` + `booking.js`
17. Write `style.css`
18. Deploy to GitHub Pages

### Phase 4: Report & viva
19. Write report (Sample.doc template)
20. Terminal screenshots of all query outputs
21. Frontend screenshots
22. Export diagrams for report
23. Viva prep — review all 15 topics

---

## Notes & gotchas

- **DELIMITER in Python:** Not needed. `cursor.execute()` handles procedure bodies natively. Only `.sql` files run in Workbench need `DELIMITER //`.
- **seats_available dual approach:** UPDATE the column in the stored procedure, compute it dynamically in the function. Having both = good viva answer about tradeoffs.
- **Offer.type:** Your `type` column ('percentage' vs 'flat') means fn_apply_discount needs an IF/ELSE — percentage: `amount - (amount * discount_value / 100)`, flat: `amount - discount_value`. Good real-world logic.
- **GitHub Pages:** Static only. The website is a visual demo. All database work lives in run_all.py.
- **Terminal screenshots:** Add print headers before each query section so outputs are self-documenting.
- **Plagiarism:** The rubric flags AI code. Write it yourself using this plan as a map. Understand every query for the viva.
- **Report sections** (from Sample.doc): Certificate, Table of Contents, Abstract, Abbreviations, List of Tables, List of Figures, Introduction, Problem Statement, Methodology, Implementation, Discussion/Results, Concluding Remarks, Societal Relevance, Future Scope, Team Details, References.
