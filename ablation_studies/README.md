# Ablation studies

Reproducible benchmarks for the four query/locking comparisons we present in
the report. Each script connects to the seeded `zomato_district` database,
runs both the naive and the optimized form of the same problem, and prints a
side-by-side summary suitable for screenshots.

## Mapping to the report

The website's [Queries tab](../frontend/queries.html) introduces five
ablations qualitatively. Four of them are quantitative — those are
benchmarked here. The fifth ("discount math: Python vs UDF") is a
code-quality argument, not a performance one, so it stays in the report's
prose section.

| # | Script | What it measures |
|---|---|---|
| 1 | [`01_concurrency.py`](01_concurrency.py) | Overbookings under 20 parallel requests for a 1-seat event, across three locking strategies |
| 2 | [`02_indexing.py`](02_indexing.py) | EXPLAIN type + rows examined + wall-clock for full-scan vs B-tree range scan on a 50,000-row table |
| 3 | [`03_n_plus_one.py`](03_n_plus_one.py) | Round-trip count and wall-clock for N+1 vs correlated subquery vs single GROUP BY |
| 4 | [`04_top_booking.py`](04_top_booking.py) | Plan shape and timing for three idioms that all compute "top booking per event" |

## How to run

Pre-requisite: the database has been seeded.

```bash
python3 database/run_all.py        # one-time setup of zomato_district
```

Run a single ablation:

```bash
python3 ablation_studies/01_concurrency.py
python3 ablation_studies/02_indexing.py
python3 ablation_studies/03_n_plus_one.py
python3 ablation_studies/04_top_booking.py
```

Run all four end-to-end (recommended for the report — one transcript):

```bash
python3 ablation_studies/run_all.py | tee report/screenshots/ablations.txt
```

Each script cleans up after itself — no leftover test events or benchmark
tables in the database. You can re-run any number of times safely.

## What each script proves

**01 — concurrency.** Creates a temporary 1-seat event, fires 20 threads at
it through three different code paths, then counts confirmed bookings. The
basic and intermediate paths leak (overbookings > 0); the advanced path
(`sp_book_event` with `FOR UPDATE`) keeps the count at exactly 1 regardless
of arrival order. This is the rubric's "demonstrate concurrent access
correctness".

**02 — indexing.** Builds `Event_bench` with 50,000 rows, runs the same date
filter with and without `idx_bench_date`, and prints both EXPLAIN plans.
Expect `type=ALL, rows≈50000` to drop to `type=range, rows<<` — and the
median wall-clock to drop accordingly.

**03 — N+1 vs GROUP BY.** Runs three semantically identical solutions on
the seeded Event/Review tables. The N+1 form pays one round-trip per event;
the GROUP BY form pays one. The seeded dataset is intentionally small, so
the timing gap is modest; the round-trip count tells the structural story.

**04 — top booking idioms.** Three shapes that return the identical row
set (asserted before timing). Reports plan-step count, sum of rows
examined, and wall-clock, so the report can argue "all three are correct;
here's how the optimizer treats each".

## Files

- `_common.py` — shared connection + ASCII table helpers.
- `0X_*.py` — one self-contained script per ablation.
- `run_all.py` — convenience orchestrator for the full transcript.
