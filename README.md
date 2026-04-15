# Zomato District Clone - DBMS Project

An event discovery and booking platform modelled on Zomato District. Users browse
concerts, comedy nights, DJ sets and food festivals, filter by city/category,
book tickets with promo codes, and leave reviews. The project has two halves:

- **Database side** - MySQL schema with 13 tables, full DDL/DML/DQL/TCL/DCL,
  views, stored procedures, user-defined functions. Orchestrated from a single
  Python script so screenshots for the report are reproducible.
- **Backend side** - a small Flask app (`backend/app.py`) that exposes the
  database over JSON endpoints and serves the frontend as static files from
  the same origin. Also exposes a read-only `/api/query` endpoint used by the
  SQL playground page.
- **Frontend side** - plain HTML/CSS/JS that fetches live data from the Flask
  backend. The Discover / Event / Booking pages hit the real `zomato_district`
  database; confirming a booking actually writes to `Booking` + `Transaction`
  via `sp_book_event`. A new **Queries** page lets you run ad-hoc SQL
  (SELECT/SHOW/DESCRIBE/EXPLAIN/WITH only) or pick from a curated list of
  preset queries pulled straight out of `queries.sql` and `advanced.sql`.

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
├── backend/
│   ├── app.py               ← Flask app (JSON API + serves the frontend)
│   ├── query_guard.py       ← read-only SQL validator for /api/query
│   ├── presets.py           ← preset query list for the playground page
│   └── requirements.txt     ← Flask + mysql-connector + python-dotenv
├── frontend/
│   ├── index.html           ← event listing + filters
│   ├── event.html           ← event detail page
│   ├── booking.html         ← booking flow
│   ├── queries.html         ← SQL playground (presets + custom editor)
│   ├── css/style.css        ← matt-black + red theme
│   └── js/
│       ├── utils.js         ← shared helpers + tiny fetch wrapper
│       ├── home.js          ← filter + render (fetches /api/events)
│       ├── event.js         ← event detail (fetches /api/events/:id)
│       ├── booking.js       ← counter, promo codes, POST /api/bookings
│       └── queries.js       ← presets sidebar + custom query runner
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
and tested against MySQL 8.0 on Mint Cinnamon.

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
pip install mysql-connector-python tabulate python-dotenv flask
```

Or install everything the backend needs from its requirements file:

```bash
pip install -r backend/requirements.txt
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

## Running the web app (backend + frontend)

The frontend now talks to MySQL via the Flask backend, so there's one command
to start and a single URL to open.

**Step 1 - seed the database** (one-time per machine, or whenever you reset):

```bash
python3 database/run_all.py
```

**Step 2 - start the backend:**

```bash
python3 backend/app.py
```

Flask listens on `http://127.0.0.1:5000` and serves both the JSON API under
`/api/...` and the static frontend from `frontend/`.

Open `http://127.0.0.1:5000/` in a browser. No other server needed.

**Pages:**

- `/` (index.html) - filter by category/city/search, fetched from `/api/events`
- `/event.html?id=N` - event detail, lineup, reviews, save-for-later
- `/booking.html?id=N` - counter, promo codes (`EARLYBIRD`, `GROUP25`,
  `WEEKEND15`, `ZOMATO10`, `FIRST50`), payment dropdown. Confirming a booking
  calls `sp_book_event`, writes real rows into `Booking` + `Transaction`,
  decrements `Event.seats_available`, and (if a promo was applied) inserts
  into `Booking_Offer`.
- `/queries.html` - **SQL playground**. Sidebar of preset queries taken
  straight from `queries.sql` and `advanced.sql` (all 14 DQL showcase queries,
  all 3 views, both UDFs, schema metadata). Textarea for custom SQL;
  `Ctrl/Cmd+Enter` runs the query.

**Backend API at a glance:**

| Method | Path                        | Purpose |
|-------:|-----------------------------|---------|
| GET    | `/api/categories`           | List of event categories |
| GET    | `/api/cities`               | Distinct city list from `Location` |
| GET    | `/api/offers`               | Active promo codes |
| GET    | `/api/events?city=&category=&q=&upcoming=1` | Event listing, uses `fn_seats_remaining` |
| GET    | `/api/events/<id>`          | Event detail + performers + reviews |
| POST   | `/api/bookings`             | Create booking via `sp_book_event` (optional offer) |
| GET    | `/api/presets`              | Preset query list for the playground |
| POST   | `/api/query`                | Run a read-only SQL query; body: `{"sql": "..."}` |

**Read-only query safety:** `/api/query` runs the validator in
`backend/query_guard.py` (first token must be SELECT/SHOW/DESCRIBE/EXPLAIN/WITH,
no semicolons, blacklist of DDL/DML/DCL keywords after stripping string
literals) *and* every query is executed inside a
`SET SESSION TRANSACTION READ ONLY; START TRANSACTION;` block that is rolled
back at the end. Even if the validator missed something, MySQL itself refuses
writes inside a read-only transaction.

**Styling:** matt-black background with a red accent (`#ff2d45`). All colours
are CSS variables at the top of `css/style.css`, tweak `--bg`, `--red`, etc.
if you want a different palette.

**Can this still be hosted on GitHub Pages?** Not meaningfully. Every page
now requires the Flask backend + a locally-seeded `zomato_district` database,
so without the backend all of them fail to load. Run it locally on whichever
machine has the database (or deploy Flask + MySQL together if you really
want it hosted).

**Resetting after a demo:** every booking made through the UI writes a real
row. Re-run `python3 database/run_all.py` to drop and recreate the database
back to the seeded state.

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
- **Flask page loads but shows "Could not load events"** - the DB probably
  isn't seeded. Run `python3 database/run_all.py` once, then reload the page.
- **`/api/query` rejects something that looks obviously safe** - the keyword
  blacklist is deliberately strict (it flags any bare identifier like
  `UPDATE`, `DROP`, `INSERT`, etc. anywhere in the SQL after string literals
  are stripped). So `` SELECT 'x' AS `update` `` fails, but `update_flag`,
  `my_update`, or `'UPDATE me' AS note` all pass. If you hit this, rename
  the offending identifier.

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
