# Zomato District Clone - DBMS Project

An event discovery and booking platform modelled on Zomato District. Users browse
concerts, comedy nights, DJ sets and food festivals, filter by city/category,
book tickets with promo codes, and leave reviews. The project has two halves:

- **Database side** - MySQL schema with 13 tables, full DDL/DML/DQL/TCL/DCL,
  views, stored procedures, user-defined functions. Orchestrated from a single
  Python script so screenshots for the report are reproducible.
- **Frontend side** - static HTML/CSS/JS (hosted on GitHub Pages) that mirrors
  the database as a small visual demo. No backend - all data lives in
  `frontend/js/data.js`.

---

## Repository layout

```
dbms_project/
├── README.md                ← you are here
├── plan.md                  ← project plan (rubric mapping + task order)
├── .env                     ← DB credentials (git-ignored)
├── .env.example             ← template for teammates
├── database/
│   ├── schema.sql           ← 13 CREATE TABLEs + indexes
│   ├── seed_data.sql        ← realistic sample data
│   ├── queries.sql          ← DQL showcase (joins, grouping, subqueries…)
│   ├── advanced.sql         ← views, functions, stored procedures
│   └── run_all.py           ← orchestrator: runs everything end-to-end
├── frontend/
│   ├── index.html           ← event listing + filters
│   ├── event.html           ← event detail page
│   ├── booking.html         ← booking flow
│   ├── css/style.css        ← matt-black + red theme
│   └── js/
│       ├── data.js          ← hardcoded data mirroring the DB
│       ├── home.js          ← filter + render logic
│       ├── event.js         ← event detail + save-to-localStorage
│       └── booking.js       ← counter, promo codes, summary, confirm
├── diagrams/
│   ├── ER_Diagram_DJ.drawio.html
│   └── Class_Diagram_DJ.drawio.html
└── report/
    └── screenshots/         ← query outputs, UI, diagrams for the report
```

---

## One-time setup

### 1. MySQL

You need a local MySQL 8.x running on `localhost:3306`. The project was built
and tested against MySQL 8.0 on Ubuntu.

Create (or reuse) a user and make sure it can create databases:

```bash
sudo mysql -e "CREATE USER IF NOT EXISTS 'ishu'@'localhost' IDENTIFIED BY 'password123';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'ishu'@'localhost' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"
```

The `WITH GRANT OPTION` bit matters - without it the DCL demo in `run_all.py`
(CREATE USER / GRANT / REVOKE) will skip the GRANT statements.

### 2. Python environment

Python 3.9+ with these packages:

```bash
pip install mysql-connector-python tabulate python-dotenv
```

### 3. Credentials

Copy `.env.example` to `.env` and fill it in:

```
DB_HOST=localhost
DB_PORT=3306
DB_USER=ishu
DB_PASSWORD=password123
DB_NAME=zomato_district
```

`.env` is git-ignored. Never commit passwords.

---

## Running the database demo

From the project root:

```bash
python3 database/run_all.py
```

`run_all.py` executes 9 labelled sections, in order:

| Step | What it does |
|------|--------------|
| 1 | Runs `schema.sql` - drops and recreates `zomato_district` + all 13 tables and indexes |
| 2 | Runs `seed_data.sql` - inserts sample users, events, bookings, reviews, offers… |
| 3 | Runs `advanced.sql` - creates 3 views, 2 UDFs, 3 stored procedures |
| 4 | DQL showcase - 14 queries covering every join type, GROUP BY/HAVING, subqueries, aggregate + scalar functions |
| 5 | SELECTs from each view |
| 6 | Demonstrates `fn_seats_remaining` and `fn_apply_discount` |
| 7 | Calls the stored procedures (`sp_search_events`, `sp_book_event`, `sp_cancel_booking`) |
| 8 | TCL - COMMIT, ROLLBACK, SAVEPOINT demos |
| 9 | DCL - CREATE USER / GRANT / REVOKE |

The output is tidy and labelled - redirect it to a file if you want to grab
screenshots for the report:

```bash
python3 database/run_all.py | tee report/screenshots/run_all_output.txt
```

The script is idempotent. Every run drops and recreates the database, so you
can run it as many times as you like.

---

## Running the frontend

The frontend is pure static HTML/CSS/JS - no build step, no backend.

**Quick local preview:**

```bash
cd frontend
python3 -m http.server 8765
```

Then open http://127.0.0.1:8765/index.html. You don't *have* to use a server
(you can double-click `index.html`) but the server avoids quirky `file://`
behaviour.

**Pages:**

- `index.html` - filter by category/city/search, click a card to see details
- `event.html?id=N` - event detail with lineup, reviews, save-for-later, book now
- `booking.html?id=N` - counter, promo code input (`EARLYBIRD`, `GROUP25`,
  `WEEKEND15`, `ZOMATO10`, `FIRST50`), payment dropdown, fake confirmation

**Styling:** matt-black background with a red accent (`#ff2d45`). All colours
are CSS variables at the top of `css/style.css`, tweak `--bg`, `--red`, etc.
if you want a different palette.

**Deploying to GitHub Pages:** push the whole repo to GitHub, go to Settings
→ Pages, select the `main` branch and `/frontend` folder. Wait a minute, done.

---

## Schema cheat sheet

13 tables, normalized to 3NF. Detailed column lists are in `plan.md` (section
"Schema - based on the class diagram").

**Core entities:** `User`, `Event`, `Event_Category`, `Location`, `Host`,
`Performer`, `Offer`

**Transactional tables:** `Booking`, `Transaction`, `Review`

**Bridge tables (M:N):** `Saved_Item`, `Event_Performer`, `Booking_Offer`

**Key relationships:**
- Event → Category, Location, Host (N:1 each)
- Booking → User, Event (N:1 each); Booking → Transaction (1:1)
- Event ↔ Performer, User ↔ Event (saved), Booking ↔ Offer (all M:N)

**A useful quirk to know about `seats_available`:**
Seeded events store their *initial* capacity in `Event.seats_available` - the
seed inserts bookings directly without decrementing the column. This is on
purpose: it lets `fn_seats_remaining()` illustrate the difference between a
stored value (fast reads, can drift) and a computed value (always accurate).
`sp_book_event()` properly decrements the column for any new bookings made
after seeding.

---

## Who does what

This section is for the team - update it as you split the work.

- **ER / class diagrams**: [teammate name] - in `diagrams/`, currently being
  updated to match the class diagram
- **Database (schema/queries/procedures)**: Ishu
- **Frontend**: Ishu
- **Report (Sample.doc template)**: [teammate name]
- **Terminal + UI screenshots**: whoever runs `run_all.py` last

---

## Common pitfalls

- **`1698 Access denied for user 'root'@'localhost'`** - your distro's MySQL
  uses auth_socket for root. Don't try to fight it, use a normal user like
  the `ishu` one above.
- **`1064 You have an error in your SQL syntax`** when editing `advanced.sql` -
  statements are separated by `-- ===SQL_SPLIT===` markers, not semicolons.
  Don't remove them.
- **GRANT statements silently skipped in Step 9** - the user running
  `run_all.py` doesn't have GRANT OPTION. Re-run the one-liner from the setup
  section.
- **`Duplicate entry` errors during seed** - you edited `seed_data.sql` but
  left the old data in the DB. `run_all.py` drops and recreates every time,
  so just re-run it.

---

## Viva prep checklist

Quick list of things to actually *understand* (not memorize):

- [ ] Difference between primary key, foreign key, unique key, candidate key
- [ ] 1NF / 2NF / 3NF - and why each of our bridge tables is in 2NF
- [ ] All join types and what changes in the result set between them
- [ ] GROUP BY vs WHERE vs HAVING (order of execution)
- [ ] Correlated vs non-correlated subqueries
- [ ] Aggregate vs scalar functions (examples from Q13 and Q14 in queries.sql)
- [ ] Why we have a view - performance, security, abstraction
- [ ] Stored procedure vs function - when to use which
- [ ] ACID properties, and what each of COMMIT / ROLLBACK / SAVEPOINT does
- [ ] Stored vs. computed `seats_available` - the tradeoff story
- [ ] Percentage vs flat offers - why `fn_apply_discount` branches
- [ ] What a CHECK constraint caught during the SAVEPOINT demo (rating > 5)

Each of the queries in `queries.sql` and every procedure/function in
`advanced.sql` is labelled with a comment explaining what it does - read
through them once before the viva.
