# Instructions for generating the Elysium DBMS report

You are writing the end-term DBMS project report for a project called **Elysium**
(coursework framing: a Zomato District clone). This document is the complete
brief — the codebase is on GitHub at
**https://github.com/IshuIsAwake/district_clone** and the reader is expected
to visit it; the report does not need to re-print the entire codebase.

The user will dissect what you produce. Bias for honesty over polish.

---

## Voice rules — non-negotiable

1. **Blunt and direct.** No throat-clearing. No "in today's digital world…".
   No "this innovative system…". Open paragraphs with the claim, not a wind-up.
2. **Only describe what exists in the repo.** No aspirational features, no
   "the system could…", no inventing capabilities. If the codebase has it,
   describe it. If not, omit. When something is *deliberately* not built (e.g.
   distributed locking, materialised views), say so plainly in one line and
   move on — do not pad it into a "future scope" section.
3. **Zero marketing language.** Forbidden words/phrases: *seamless, robust,
   leveraging, cutting-edge, comprehensive, holistic, innovative, paradigm,
   revolutionise, empower, ensure user satisfaction, enhances the user
   experience.* If a sentence still works after deleting an adjective, delete it.
4. **Report engineering decisions, not feelings.** Every non-trivial design
   choice gets one line of *why*, ideally with the alternative considered.
   "Booking.total_price is stored, not derived, because it locks in the
   price at booking time" — that's the shape.
5. **Honest about trade-offs and known soft spots.** If a denormalisation was
   accepted (it was — in three places), name it. If `fn_apply_discount` reads
   from a mutable table and was NOT marked `DETERMINISTIC` for that reason,
   say so.
6. **Recommend the GitHub repo aggressively.** Several sections should end with
   a one-line "Full source: [github.com/IshuIsAwake/district_clone](https://github.com/IshuIsAwake/district_clone) →
   `<file_path>`" pointer. Do not paste long code listings into the report when
   a link will do — paste only the 5-15 line excerpt the prose is discussing.
7. **Third person, technical.** "The system" / "the procedure" / "the schema",
   not "we" or "I" — except in the Team Details section.
8. **No emojis. No icons. No box-drawing decoration.** Plain prose, plain
   tables, plain code blocks.

---

## Sections to produce — and sections to skip

The university template
([documents/DBMS report format updated.docx](../documents/DBMS%20report%20format%20updated.docx))
lists these sections. Produce only the ones marked **KEEP**. Treat the rest
as filler — do not generate them.

| Section in template          | Decision | Notes |
|------------------------------|----------|-------|
| Title page                   | KEEP     | Boilerplate. |
| Certificate                  | KEEP     | Boilerplate, supervisor-signed. |
| Table of Contents            | KEEP     | Auto-generated style. |
| Abstract                     | KEEP     | One paragraph. No buzzwords. |
| Abbreviations                | KEEP     | Just the ones we actually use. |
| List of Tables               | KEEP     | If we have ≥3 tables. |
| List of Figures              | KEEP     | If we have ≥3 figures. |
| Introduction                 | KEEP     | Tight. ≤ half a page. |
| Problem Statement            | KEEP     | One paragraph. |
| Methodology                  | KEEP     | The substantive section. |
| **Design Choices & Code Walkthrough** | **ADD (new)** | The heart of the report. |
| **Results — Ablation Studies**        | **ADD (new)** | Numbers, replaces "Discussion". |
| Concluding Remarks           | KEEP     | One short paragraph. No "in conclusion this project demonstrates". |
| Societal Relevance           | **SKIP** | Words wasted. The user does not want this. |
| Future Scope                 | **SKIP** | Words wasted. If something matters, it's already in scope; if not, omit. |
| Team Details and Contribution| KEEP     | Honest split. |
| References                   | KEEP     | Real, citable sources only. |

The university format requires the boilerplate front matter. The grading rubric
([documents/DBMS_Marks_Rubrics and Viva.docx](../documents/DBMS_Marks_Rubrics%20and%20Viva.docx))
rewards SQL depth, normalisation rationale, and concurrency proof — that lives
in **Methodology + Design Choices + Ablation Studies**.

---

## Project facts (use these directly; do not fabricate around them)

### What was built

Elysium is an event-discovery and booking platform — a District clone in
product framing, a query-optimisation and concurrency-control study in
engineering framing.

- **Backend:** Flask app at [`backend/app.py`](https://github.com/IshuIsAwake/district_clone/blob/main/backend/app.py).
  JSON API + serves the static frontend.
- **Frontend:** plain HTML/CSS/JS under [`frontend/`](https://github.com/IshuIsAwake/district_clone/tree/main/frontend).
  Five pages: Discover, Event detail, Booking, SQL Playground, Admin console.
  **The frontend carries zero marks** per the rubric — it exists because the
  template expects a working demo. Do not over-describe it.
- **Database:** MySQL 8.x, single database `zomato_district`, 13 tables in
  3NF.
- **Orchestrator:** [`database/run_all.py`](https://github.com/IshuIsAwake/district_clone/blob/main/database/run_all.py)
  drops/recreates the schema, seeds it, and exercises every SQL artifact in
  one reproducible run.

### Schema — 13 tables in three layers

Layer 1 — **independent entities** (no outgoing FKs): `User`, `Event_Category`,
`Location`, `Host`, `Performer`, `Offer`.

Layer 2 — **dependent entities** (FK into layer 1): `Event`, `Booking`,
`Transaction`, `Review`.

Layer 3 — **bridge tables** (M:N resolution, composite PK): `Saved_Item`,
`Event_Performer`, `Booking_Offer`.

Six explicit indexes beyond the auto-indexed PK/UNIQUE columns:
`idx_event_date`, `idx_event_category`, `idx_location_city`, `idx_booking_user`,
`idx_booking_event`, `idx_review_event`. Each one accelerates a specific
read path; the rationale per index is in the schema header comment.

Three documented denormalisations, all justified:
- **`User.city`** kept as VARCHAR rather than FK to a city lookup — the
  lookup table would have one column and gain nothing.
- **`Booking.total_price`** stored, not derived — locks in the price at
  booking time so a later event-price edit does not retroactively change
  what the user paid; needed for refund and audit trails.
- **`Booking_Offer.discount_applied`** stored alongside `Offer.discount_value`
  — Offer is mutable (campaign edits), the rupees already deducted are not.

### SQL surface

- **DDL**: `CREATE DATABASE / TABLE / INDEX / VIEW / FUNCTION / PROCEDURE`,
  drops on every rerun.
- **DML**: `INSERT` (seeding + booking flow), `UPDATE` (booking status,
  Event.version bump), `DELETE` (saved-item demo).
- **DQL** showcase — 14 queries (Q0–Q14) in
  [`database/queries.sql`](https://github.com/IshuIsAwake/district_clone/blob/main/database/queries.sql),
  each labelled with `-- @id`. Covers INNER / LEFT / RIGHT / FULL OUTER
  (UNION-emulated, since MySQL has no FULL OUTER) / SELF JOIN; GROUP BY +
  HAVING; non-correlated, IN, and correlated subqueries; aggregate functions
  (COUNT/MIN/MAX/AVG/SUM); scalar functions (UPPER/LENGTH/CONCAT/FLOOR/
  DATEDIFF/COALESCE).
- **TCL**: COMMIT, ROLLBACK, SAVEPOINT — demonstrated in `run_all.py` step 8.
- **DCL**: CREATE USER / GRANT / REVOKE — `run_all.py` step 9.
- **3 views**:
  - `vw_event_dashboard` — per-event card projection with avg rating + review
    count (5-table JOIN + LEFT JOIN on Review + GROUP BY).
  - `vw_booking_summary` — per-booking projection joining User, Event,
    Transaction, Booking_Offer, Offer (LEFT joins on the optional ones).
  - `vw_event_lineup` — performers per event, ordered by `performance_order`.
- **2 user-defined functions**:
  - `fn_seats_remaining(event_id) RETURNS INT` — derives live seat count from
    `seats_available − SUM(confirmed booking sizes)`. Declared `READS SQL DATA`,
    NOT `DETERMINISTIC` (it reads a mutable table).
  - `fn_apply_discount(amount, code) RETURNS DECIMAL(10,2)` — applies a
    percentage or flat discount, floors at 0, quietly returns the original
    amount on missing/inactive code. Also `READS SQL DATA`, NOT `DETERMINISTIC`
    — same reason.
- **4 stored procedures**:
  - `sp_book_event(user, event, qty, payment)` — caller-managed transaction,
    `SELECT … FOR UPDATE` on the Event row, seat check via
    `fn_seats_remaining`, INSERT Booking + Transaction, `SIGNAL SQLSTATE
    '45000'` on insufficient seats.
  - `sp_apply_offer_to_booking(booking, code)` — caller-managed transaction,
    `FOR UPDATE` on the Booking row, delegates discount math to
    `fn_apply_discount`. Single source of truth for discount math.
  - `sp_cancel_booking(booking)` — self-managed transaction. Flips Booking
    status and Transaction payment_status atomically. Idempotent against
    repeat cancels (raises 'Booking already cancelled').
  - `sp_search_events(city, category)` — read-only parameterised filter
    using the `(p IS NULL OR p = '' OR col = p)` idiom for optional filters.

### Concurrency model

Pessimistic locking is the production path: every booking goes through
`sp_book_event`, which acquires an exclusive row-lock on the Event row via
`SELECT … FOR UPDATE` before computing `fn_seats_remaining` and inserting.
InnoDB holds the X-lock until COMMIT — that is **Strict Two-Phase Locking
(S2PL)** by default.

Optimistic locking is *partly* implemented: `Event.version` exists and is
bumped on every successful booking, so an alternative client can do a
compare-and-swap update. The pessimistic path does not depend on it — both
mechanisms coexist for the ablation. There is **no application-level retry
loop** wired up around the optimistic path; the column is there for the
demonstration and the ablation study, not for production traffic.

### Seats model — derived, not cached

`Event.seats_available` stores the **initial capacity** at event creation
and is **never decremented**. Live availability comes from
`fn_seats_remaining()`. This is deliberate: a stored counter opens a TOCTOU
race between "check seats" and "decrement seats". Deriving from
`Booking` under `FOR UPDATE` on the Event row makes the check atomic.

### Ablation studies — measured numbers

These come from running `python3 ablation_studies/run_all.py` against the
seeded database. All numbers are reproducible by anyone who clones the repo.
Use the actual numbers; do not round excessively.

#### Ablation 1 — Concurrent booking: race vs lock

Setup: a 1-seat event, 20 threads firing booking attempts simultaneously.

| Tier                  | Successes | Overbookings | Median latency | Wall clock |
|-----------------------|-----------|--------------|----------------|------------|
| basic (no txn)        | 2 / 20    | **1**        | 0.6 ms         | 21.0 ms    |
| intermediate (txn)    | 5 / 20    | **4**        | 1.9 ms         | 36.9 ms    |
| advanced (FOR UPDATE) | 1 / 20    | **0**        | 5.6 ms         | 47.9 ms    |

Read: under load, the autocommit and naive-transaction paths *silently
overbook* — that is the database-corruption bug `sp_book_event` exists to
prevent. The advanced tier pays a latency cost (threads queue on the X-lock)
and stays correct regardless of arrival order.

Source: [`ablation_studies/01_concurrency.py`](https://github.com/IshuIsAwake/district_clone/blob/main/ablation_studies/01_concurrency.py).

#### Ablation 2 — Indexing: full scan vs B-tree range scan

Setup: a benchmark table `Event_bench` with 50,000 rows, narrow date
predicate (`event_date BETWEEN '2026-12-15' AND '2026-12-20'`).

| Query                        | EXPLAIN type | Rows examined | Median time |
|------------------------------|--------------|---------------|-------------|
| LIKE on unindexed TEXT       | ALL          | 50,000        | 18.7 ms     |
| Range filter, no index       | ALL          | 50,000        | 11.5 ms     |
| Range filter, with index     | range        | **822**       | **3.6 ms**  |

Read: `type=ALL → range` and `rows=50,000 → 822` is the optimiser switching
from full table scan to B-tree range scan. ~3.2× faster wall-clock at this
size; the gap widens with table size.

Source: [`ablation_studies/02_indexing.py`](https://github.com/IshuIsAwake/district_clone/blob/main/ablation_studies/02_indexing.py).

#### Ablation 3 — N+1 vs single GROUP BY

Setup: compute `(avg_rating, review_count)` per event over the seeded
dataset (small — the seeded table has 10 events).

| Form                       | Server round-trips | Median time |
|----------------------------|--------------------|-------------|
| N+1 from Python loop       | 11                 | 0.48 ms     |
| Correlated subquery        | 1                  | 0.09 ms     |
| LEFT JOIN + GROUP BY       | 1                  | 0.44 ms     |

Read: at 10 events the absolute numbers are tiny, but the round-trip count
shows the cost shape — N+1 is linear in number of events, the others are
constant. State this clearly: the seeded dataset is small on purpose; the
*structural* point is what matters.

Source: [`ablation_studies/03_n_plus_one.py`](https://github.com/IshuIsAwake/district_clone/blob/main/ablation_studies/03_n_plus_one.py).

#### Ablation 4 — Top booking per event: three idioms

Setup: for each event, find the highest-priced confirmed booking. All three
forms return the **identical row set** (asserted before timing).

| Idiom                           | Plan steps | Sum rows examined | Median time |
|---------------------------------|------------|-------------------|-------------|
| Correlated subquery (Q12 shape) | 2          | 26                | 0.19 ms     |
| Tuple IN against derived MAX    | 2          | 48                | 0.13 ms     |
| JOIN against per-event MAX      | 3          | 28                | 0.14 ms     |

Read: same answer, three shapes. The point is that the optimiser handles
all three competently on this dataset; the choice is a readability one.

Source: [`ablation_studies/04_top_booking.py`](https://github.com/IshuIsAwake/district_clone/blob/main/ablation_studies/04_top_booking.py).

### What was NOT built (be explicit, do not pretend otherwise)

- **Materialised views.** `vw_event_dashboard` is recomputed on every read.
  Mentioned as a candidate; not done.
- **Distributed locking** (Redis / advisory locks across nodes). The
  locking handout lists this as advanced/optional. Not done.
- **Optimistic-locking client retry loop.** `Event.version` is maintained
  but no caller compare-and-swaps against it.
- **`vw_event_dashboard` is not used by `/api/events`** — the Flask handler
  inlines the JOINs. The view is exercised in the playground and `run_all.py`
  only.
- **Discount math in the older booking handler** was duplicated in Python;
  it has been refactored to call `sp_apply_offer_to_booking` →
  `fn_apply_discount`. The duplication is gone, but the report should
  acknowledge it existed and was fixed.

---

## Per-section guidance

### Title page
"Elysium — A Query-Optimisation Study via a District-Style Event Booking
Platform". Standard university block. No subtitle gymnastics.

### Abstract
**One paragraph.** State what was built (relational DBMS for event booking,
13 tables 3NF, MySQL 8 + Flask), and the engineering contribution
(quantified ablation studies on concurrency, indexing, query rewriting).
Do not write a second paragraph about "evaluation" — the abstract is
covered in one paragraph.

Forbidden opening clauses: "In today's digital age…", "With the rise of…",
"This research focuses on…". Open with: "Elysium is a relational backend
for an event-booking platform…".

### Abbreviations
Only abbreviations actually used in the report. Likely: DBMS, SQL, DDL/DML/
DQL/TCL/DCL, ER, 3NF, FK/PK, ACID, S2PL, OCC, UDF, X-lock, S-lock, TOCTOU,
CAS, CTE, CRUD. Skip any that you don't use.

### Introduction
Half a page maximum. Two paragraphs:
1. Event-booking platforms are concurrency-heavy: a finite resource (seats)
   under bursty demand. That makes them a natural teaching vehicle for
   transactions, locking, and indexing.
2. Elysium implements the standard read/write paths (browse, book, review,
   cancel) and uses each one as a vehicle for measured comparisons of
   common-but-wrong vs correct SQL. Every non-trivial query exists in
   the codebase with a justification comment; the SQL Playground page
   exposes them as runnable presets.

### Problem Statement
One paragraph. State the four deliverables literally:
(a) a normalised schema for an event-booking domain;
(b) full SQL surface coverage (DDL/DML/DQL/TCL/DCL, views, functions,
    procedures);
(c) demonstrable concurrency safety on the booking path;
(d) measured justification for each non-trivial query and locking choice.

### Methodology
Three subsections. Use the schema/index/UDF/procedure facts above directly.

**Design.**
- ER diagram (figure — exported from `diagrams/ER_Diagram_DJ.drawio.html`).
- The 13-table schema split into the three layers above. One paragraph
  per layer is enough — the per-table normalisation rationale lives in
  the schema file's comments and the report should cite that file rather
  than re-printing 13 tables of CREATE statements.
- Normalisation: state explicitly that every table is in 3NF; call out
  the three documented denormalisations by name and reason (one
  sentence each).
- Indexes: the six indexes plus the per-index justification (one line
  each, in a single bullet list).

**Implementation.**
Stack: MySQL 8.x, Python 3.9+, Flask, mysql-connector, plain HTML/CSS/JS
frontend. One sentence each on what `run_all.py`, `app.py`, and
`query_guard.py` do. Do not describe Flask. Do not describe HTML.

**Algorithm: `sp_book_event`.** Use the template's *Input / Output / Steps*
shape literally — that's the rubric format.
- Input: `p_user_id INT, p_event_id INT, p_num_people INT, p_pay_method VARCHAR(30)`.
- Output: inserts into Booking and Transaction; raises `SQLSTATE '45000'`
  on insufficient seats.
- Steps:
  1. `SELECT price FROM Event WHERE event_id = p_event_id FOR UPDATE` —
     acquires the X-lock.
  2. If the row is missing → SIGNAL "Event not found".
  3. `v_remaining := fn_seats_remaining(p_event_id)`.
  4. If `v_remaining < p_num_people` → SIGNAL "Not enough seats available".
  5. Compute total. INSERT Booking, capture `LAST_INSERT_ID()`. INSERT
     Transaction.
  6. `UPDATE Event SET version = version + 1` — bumps the optimistic-lock
     counter (does not affect the pessimistic path).
  7. Caller commits.

End the section with: "Full source: github.com/IshuIsAwake/district_clone →
`database/procedures.sql`".

### Design Choices & Code Walkthrough — the substantive section

This is the section that earns the marks. Six subsections, each one
focused, each ending with a "see `<file path>` on GitHub" pointer:

1. **Why 13 tables and not 4–5 fat ones.** Each split is forced by a
   specific normal-form violation. Walk through one example properly
   (recommend `Event_Category`: inlining `category_name` and
   `description` on `Event` would create a transitive dependency and
   cause update anomalies). Cite the schema header comments.

2. **`fn_seats_remaining` and the derived-vs-cached choice.** This is
   the headline DBMS decision in the project. State the alternative
   (a stored counter on Event mutated by the procedure), state the
   problem with it (TOCTOU race between read and decrement), state
   the chosen path (derive from Booking under `FOR UPDATE`), and tie
   it to ablation #1 which proves this empirically. Honest note: the
   column is named `seats_available` but means *initial capacity*; a
   rename was deferred to keep the fix minimal.

3. **`sp_book_event` and S2PL.** Walk through the procedure step by
   step. Call out the `EXIT HANDLER FOR SQLEXCEPTION ... RESIGNAL`
   pattern. Call out why this is **caller-managed** (composes with
   `sp_apply_offer_to_booking` under the same outer transaction)
   while `sp_cancel_booking` is **self-managed** (called from the
   playground where the caller is unlikely to wrap it).

4. **`fn_apply_discount` and discount math as single source of truth.**
   The honest version: this math used to be duplicated in Python in
   `app.py`. The booking handler now calls
   `sp_apply_offer_to_booking`, which calls `fn_apply_discount`. One
   place to change the rule. Also call out the *quiet pass-through*
   on missing/inactive codes (debatable UX choice — typing a bad code
   should not block a booking) and that the function is **NOT** declared
   `DETERMINISTIC` because it reads from `Offer`.

5. **Indexes and EXPLAIN.** The six indexes with their justifications.
   Show one EXPLAIN excerpt (the revenue query Q6, or ablation #2's
   indexed-vs-not pair).

6. **Read-only safety on `/api/query`.** The SQL playground accepts
   user-typed SQL. Two layers of defence: `query_guard.py` whitelists
   first tokens (SELECT/SHOW/DESCRIBE/EXPLAIN/WITH) and rejects
   blacklisted keywords after stripping string literals; the query
   then runs inside a `SET SESSION TRANSACTION READ ONLY; START
   TRANSACTION` block that MySQL itself refuses writes inside. Belt
   and braces — the user wanted to demo a real SQL surface without
   making the database vandalisable.

End with: "The full per-table / per-procedure rationale is in inline
comments in [`database/`](https://github.com/IshuIsAwake/district_clone/tree/main/database).
The reader is encouraged to skim the headers of `schema.sql`,
`procedures.sql`, and `functions.sql` directly."

### Results — Ablation Studies
Reproduce the four tables verbatim from the "Ablation studies — measured
numbers" section above. For each, two short paragraphs: setup, then read
of the result. End the section with one paragraph that states the headline:
**"the FOR UPDATE path is the only configuration that does not silently
overbook a fully-booked event under load. Everything else is theatre."**

End with: "All four benchmarks are reproducible via
`python3 ablation_studies/run_all.py`. Source under
[`ablation_studies/`](https://github.com/IshuIsAwake/district_clone/tree/main/ablation_studies)."

### Concluding Remarks
**One short paragraph.** State what was demonstrated:
- A normalised schema with every denormalisation justified.
- Full SQL surface coverage including views, functions, procedures.
- Pessimistic concurrency control measured to actually prevent
  overbookings.
- Index, query-rewrite, and N+1 ablations with reproducible numbers.

Do **not** write "in conclusion this project demonstrates the power of
DBMS". Do not summarise what the report just said.

### Team Details and Contribution
Honest split. Use whatever the actual breakdown is — placeholders the
user will fill in. Avoid "all members contributed equally" boilerplate
unless it's actually true.

### References
Real, citable sources only. The shortlist:
- Silberschatz, A., Korth, H. F., & Sudarshan, S. (2020). *Database
  System Concepts*. McGraw-Hill.
- Elmasri, R., & Navathe, S. B. (2017). *Fundamentals of Database
  Systems*. Pearson.
- MySQL 8.0 Reference Manual — InnoDB Locking and Transaction Model
  (`https://dev.mysql.com/doc/refman/8.0/en/innodb-locking.html`).
- The course handouts in
  [`documents/`](../documents/) — the locking
  practice document is the one being responded to in the concurrency
  section.

Cite specifically (page or chapter). Do not pad the references list.

---

## Final checks before returning

- Did you remove every adjective that adds nothing? Read it back. If a
  sentence works without the word, the word should not be there.
- Did you cite the GitHub URL at least 5 times (one per major section)?
- Did the report describe anything that is not in the codebase? Cut it.
- Is every number in the report traceable to a script or a query in the
  repo?
- Are Societal Relevance and Future Scope **absent**? They should be.
- Length target: 12–18 pages including front matter. Tighter than the
  template suggests; that is intentional.
