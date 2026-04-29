# Zomato District clone — DBMS project

An event discovery and booking platform modelled on Zomato District. Users browse
concerts, comedy nights, DJ sets and food festivals, filter by city/category,
book tickets with promo codes, and leave reviews. The project has two halves:

- **Database side** — MySQL schema with 13 tables in 3NF, full DDL/DML/DQL/TCL/DCL,
  views, stored procedures, user-defined functions, and pessimistic + optimistic
  locking primitives. Orchestrated from a single Python script so screenshots
  for the report are reproducible.
- **Backend side** — a small Flask app (`backend/app.py`) that exposes the
  database over JSON endpoints and serves the frontend as static files from
  the same origin. Includes a read-only `/api/query` endpoint for the SQL
  playground and an admin console for unrestricted SQL.
- **Frontend side** — plain HTML/CSS/JS that fetches live data from the Flask
  backend. The Discover / Event / Booking pages hit the real `zomato_district`
  database; confirming a booking actually writes to `Booking` + `Transaction`
  via `sp_book_event` (and `Booking_Offer` via `sp_apply_offer_to_booking` if
  a promo is applied).

> **Project framing.** This is graded as a *query-optimization research piece*,
> not a feature-rich Zomato clone. The frontend carries no marks; the SQL,
> normalization rationale, and concurrency/lock comparisons are where the
> evaluation lives. See `documents/DBMS_Marks_Rubrics and Viva.docx` for the
> rubric and `documents/DBMS in Practice_Locking.docx` for the locking
> requirements.

---

## Repository layout

```
dbms_project/
├── README.md                ← you are here
├── plan.md                  ← project plan (rubric mapping + task order)
├── .env                     ← DB credentials (git-ignored)
├── .env.example             ← template for teammates
├── database/
│   ├── schema.sql           ← 13 CREATE TABLEs + indexes, with per-table
│   │                          normalization rationale comments
│   ├── seed_data.sql        ← realistic sample data
│   ├── views.sql            ← 3 views (vw_event_dashboard, …)
│   ├── functions.sql        ← 2 UDFs (fn_seats_remaining, fn_apply_discount)
│   ├── procedures.sql       ← 4 stored procedures, each with a declared
│   │                          transaction policy + lock concept comment
│   ├── queries.sql          ← DQL showcase Q0–Q14 (joins, grouping, subqueries,
│   │                          aggregate + scalar functions); blocks marked
│   │                          with "-- @id <name>" so backend can resolve
│   │                          them by id
│   ├── playground.sql       ← preset-only blocks (raw tables, view demos,
│   │                          UDF demos, metadata)
│   └── run_all.py           ← orchestrator: runs everything end-to-end
├── backend/
│   ├── app.py               ← Flask app (JSON API + serves the frontend)
│   ├── query_guard.py       ← read-only SQL validator for /api/query
│   ├── presets.py           ← thin manifest of preset queries (id, label,
│   │                          group, source file) — SQL itself lives in
│   │                          the .sql files, not duplicated here
│   └── requirements.txt     ← Flask + mysql-connector + python-dotenv
├── frontend/
│   ├── index.html           ← Discover (filter + event grid)
│   ├── event.html           ← event detail page
│   ├── booking.html         ← booking flow
│   ├── queries.html         ← SQL playground (presets + custom editor)
│   ├── admin.html           ← admin console (unrestricted SQL)
│   ├── css/style.css        ← matt-black + red theme
│   └── js/                  ← per-page logic + shared utils
├── diagrams/                ← ER + class diagrams (draw.io)
├── documents/               ← rubric, locking handout, report template, sample
└── report/
    └── screenshots/         ← query outputs, UI shots for the report
```

---

## One-time setup

### 1. MySQL

You need a local MySQL 8.x running on `localhost:3306`.

```bash
sudo mysql -e "CREATE USER IF NOT EXISTS 'ishu'@'localhost' IDENTIFIED BY 'password123';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'ishu'@'localhost' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"
```

The `WITH GRANT OPTION` bit matters — without it the DCL demo in `run_all.py`
(CREATE USER / GRANT / REVOKE) will skip the GRANT statements.

### 2. Python environment

Python 3.9+:

```bash
pip install -r backend/requirements.txt
pip install tabulate          # extra dep used only by run_all.py
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
| 1 | Runs `schema.sql` — drops and recreates `zomato_district`, all 13 tables and indexes |
| 2 | Runs `seed_data.sql` — inserts sample users, events, bookings, reviews, offers… |
| 3 | Runs `views.sql`, `functions.sql`, `procedures.sql` (load order matters: procedures call functions) |
| 4 | DQL showcase — 14 queries covering every join type, GROUP BY/HAVING, subqueries, aggregate + scalar functions |
| 5 | SELECTs from each view |
| 6 | Demonstrates `fn_seats_remaining` and `fn_apply_discount` |
| 7 | Calls the stored procedures (`sp_search_events`, `sp_book_event`, `sp_apply_offer_to_booking`, `sp_cancel_booking`) |
| 8 | TCL — COMMIT, ROLLBACK, SAVEPOINT demos |
| 9 | DCL — CREATE USER / GRANT / REVOKE |

Output is tidy and labelled — pipe to a file for the report screenshots:

```bash
python3 database/run_all.py | tee report/screenshots/run_all_output.txt
```

The script is idempotent — every run drops and recreates the database.

---

## Running the web app

```bash
python3 backend/app.py
```

Flask listens on `http://127.0.0.1:5000` and serves both the JSON API under
`/api/...` and the static frontend from `frontend/`.

**Pages:**

- `/` — Discover. Filter by category/city/search, fetched from `/api/events`.
- `/event.html?id=N` — event detail, lineup, reviews.
- `/booking.html?id=N` — counter, promo codes (`EARLYBIRD`, `GROUP25`,
  `WEEKEND15`, `ZOMATO10`, `FIRST50`), payment dropdown. Confirming a booking
  calls `sp_book_event`; if a valid promo is supplied, also calls
  `sp_apply_offer_to_booking` (which uses `fn_apply_discount` internally).
- `/queries.html` — **SQL playground**. Sidebar of preset queries resolved at
  request time from `queries.sql` and `playground.sql`. Textarea for custom
  read-only SQL; `Ctrl/Cmd+Enter` runs it.
- `/admin.html` — admin console for unrestricted SQL (writes are committed
  immediately; use with care).

**Backend API:**

| Method | Path                        | Purpose |
|-------:|-----------------------------|---------|
| GET    | `/api/categories`           | List of event categories |
| GET    | `/api/cities`               | Distinct city list from `Location` |
| GET    | `/api/offers`               | Active promo codes |
| GET    | `/api/events?city=&category=&q=&upcoming=1` | Event listing, includes live `fn_seats_remaining` per row |
| GET    | `/api/events/<id>`          | Event detail + performers + reviews |
| POST   | `/api/bookings`             | `sp_book_event` (+ optional `sp_apply_offer_to_booking`) under one transaction |
| GET    | `/api/presets`              | Preset query list — SQL bodies resolved on demand from `.sql` files |
| POST   | `/api/query`                | Run a read-only SQL query; body: `{"sql": "..."}` |
| POST   | `/api/admin/query`          | Run any SQL (writes commit immediately) |

**Read-only safety on `/api/query`:** `query_guard.py` whitelists the first
token (`SELECT`/`SHOW`/`DESCRIBE`/`EXPLAIN`/`WITH`), strips string literals
and rejects anything containing DDL/DML/DCL keywords, *and* the query runs
inside a `SET SESSION TRANSACTION READ ONLY; START TRANSACTION;` block that
rolls back at the end. Even if the validator misses something, MySQL itself
refuses writes inside a read-only transaction.

**Resetting after a demo:** every booking made through the UI writes a real
row. Re-run `python3 database/run_all.py` to drop and recreate the seeded
state.

---

## Concurrency & locking

All four procedures declare a **transaction policy** in their header
(`procedures.sql`):

| Procedure | Policy | Lock acquired |
|---|---|---|
| `sp_book_event` | caller-managed | X-lock on Event row via `FOR UPDATE` |
| `sp_apply_offer_to_booking` | caller-managed | X-lock on Booking row via `FOR UPDATE` |
| `sp_cancel_booking` | self-managed (`START TRANSACTION ... COMMIT`) | X-lock on Booking row |
| `sp_search_events` | none (read-only) | — |

InnoDB holds X-locks until COMMIT/ROLLBACK by default — that is **Strict 2PL
(S2PL)**. The `Event.version` column is included for the optimistic-locking
ablation (compare-and-swap on update); pessimistic callers don't depend on it
but `sp_book_event` bumps it on every successful booking so the optimistic
path stays consistent.

`/api/bookings` opens an explicit `START TRANSACTION` before calling
`sp_book_event` and commits at the end, so the seat-check, booking insert,
transaction insert, and offer application are one atomic unit covered by
the X-lock acquired inside the procedure.

---

## Schema cheat sheet

13 tables in 3NF, organised in three layers (see header comment in
`schema.sql` for the per-table normalization rationale):

- **Independent entities (no FKs):** `User`, `Event_Category`, `Location`,
  `Host`, `Performer`, `Offer`
- **Dependent entities:** `Event`, `Booking`, `Transaction`, `Review`
- **Bridge tables (M:N resolution, composite PK):** `Saved_Item`,
  `Event_Performer`, `Booking_Offer`

**A useful quirk to know about `Event.seats_available`:**
It stores the *initial* capacity at event creation and is **never
decremented**. Live availability comes from `fn_seats_remaining()` which
derives it from confirmed bookings. This is deliberate — a stored counter
opens a race window between "check seats" and "decrement seats"; deriving
under `FOR UPDATE` on the Event row makes the check atomic. The "stored vs
derived" comparison is one of the live ablations in the project.

---

## Common pitfalls

- **`1698 Access denied for user 'root'@'localhost'`** — your distro's MySQL
  uses auth_socket for root. Use a normal user like the `ishu` one above.
- **`1064 You have an error in your SQL syntax`** when editing `views.sql` /
  `functions.sql` / `procedures.sql` — statements are separated by
  whole-line `-- ===SQL_SPLIT===` markers, not semicolons. Don't remove them.
  Comment text *mentioning* the marker is fine — the splitter only acts on
  lines whose stripped content equals the marker exactly.
- **`@id` markers in `queries.sql` / `playground.sql`** — `backend/presets.py`
  references blocks by id. If you rename one, update both files.
- **GRANT statements silently skipped in Step 9** — the user running
  `run_all.py` doesn't have GRANT OPTION. Re-run the one-liner from setup.
- **Flask shows "Could not load events"** — DB probably isn't seeded. Run
  `run_all.py` once, then reload the page.
- **`/api/query` rejects something that looks safe** — the keyword blacklist
  is strict (any bare `UPDATE`/`DROP`/`INSERT` etc. token after string-literal
  stripping is rejected). `update_flag`, `my_update`, `'UPDATE me' AS note`
  all pass; backtick-quoted identifiers like `` `update` `` fail. Rename the
  identifier to work around this.

---

## Viva prep checklist

Things to actually *understand* before grading:

**Schema & normalization**
- [ ] Difference between primary key, foreign key, unique key, candidate key
- [ ] 1NF / 2NF / 3NF — and the binding constraint per table (see headers in `schema.sql`)
- [ ] Why each bridge table is automatically in 2NF/3NF by construction
- [ ] The `User.city` and `Booking.total_price` denormalizations — when each is justified

**Querying**
- [ ] All join types and what changes in the result set between them
- [ ] GROUP BY vs WHERE vs HAVING (order of execution)
- [ ] Correlated vs non-correlated subqueries
- [ ] Aggregate vs scalar functions (Q13 + Q14 in `queries.sql`)

**Stored objects**
- [ ] View vs function vs procedure — when to use which
- [ ] Why `fn_apply_discount` is NOT declared `DETERMINISTIC` (it reads from `Offer`)
- [ ] Why `sp_book_event` is caller-managed but `sp_cancel_booking` is self-managed

**Transactions & locking**
- [ ] ACID, COMMIT, ROLLBACK, SAVEPOINT
- [ ] X-lock (`FOR UPDATE`) vs S-lock (`LOCK IN SHARE MODE`)
- [ ] Strict 2PL (S2PL) — what InnoDB does by default
- [ ] Pessimistic vs optimistic locking — and why `Event.version` exists
- [ ] What `SIGNAL SQLSTATE '45000'` does and how `EXIT HANDLER FOR SQLEXCEPTION` + `RESIGNAL` works

**Indexing**
- [ ] Which queries each of the 6 indexes in `schema.sql` accelerates
- [ ] How to read an `EXPLAIN` plan (preset "EXPLAIN (revenue query)" in the playground)

Every query in `queries.sql` and every procedure/function in `procedures.sql`
/ `functions.sql` / `views.sql` is labelled with a comment explaining the
*why*, not just the *what* — read through them once before the viva.
