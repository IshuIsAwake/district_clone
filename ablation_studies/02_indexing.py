"""Ablation #2 - Indexing: full table scan vs B-tree range scan.

Builds a benchmark table Event_bench with 50,000 synthetic rows, then runs
the same SELECT three ways:

  basic         - filter on `description LIKE` (no index can help)
  intermediate  - filter on `event_date` with NO index (full scan)
  advanced      - same filter, after CREATE INDEX (B-tree range scan)

For each query we capture the EXPLAIN plan (type / rows / key) AND the
wall-clock for repeated executions. The point is the >10x gap between
"type=ALL, rows=50000" and "type=range, rows=<small>".

Cleans up the benchmark table at the end so the schema returns to baseline.
"""
from __future__ import annotations

from _common import banner, cursor, explain, print_explain, print_table, section, time_query

N_ROWS = 50_000
# Narrow range so the index is actually selective (~1% of rows). With a wide
# predicate the optimizer correctly prefers a full scan even when an index
# exists, which makes a misleading benchmark.
DATE_LO = "2026-12-15"
DATE_HI = "2026-12-20"


def build_bench_table(cur):
    cur.execute("DROP TABLE IF EXISTS Event_bench")
    cur.execute("""
        CREATE TABLE Event_bench (
            id          INT AUTO_INCREMENT PRIMARY KEY,
            title       VARCHAR(150),
            event_date  DATE,
            description TEXT
        )
    """)
    # Recursive CTE to generate N_ROWS without a numbers table.
    cur.execute("SET SESSION cte_max_recursion_depth = %s", (N_ROWS + 100,))
    cur.execute(f"""
        INSERT INTO Event_bench (title, event_date, description)
        WITH RECURSIVE seq(n) AS (
            SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < {N_ROWS}
        )
        SELECT CONCAT('Event ', n),
               DATE_ADD('2026-01-01', INTERVAL (n MOD 365) DAY),
               CONCAT('synthetic event ', n,
                      CASE WHEN n MOD 17 = 0 THEN ' electronic music night' ELSE '' END)
        FROM seq
    """)
    cur.execute("SELECT COUNT(*) FROM Event_bench")
    return cur.fetchone()[0]


def main():
    banner(f"ABLATION #2 - INDEXING (Event_bench, {N_ROWS:,} rows)")

    with cursor() as (cn, cur):
        section("Building Event_bench")
        actual = build_bench_table(cur)
        cn.commit()
        print(f"  rows inserted: {actual:,}")

        # ---------------- Basic: LIKE on unindexed TEXT ----------------
        section("BASIC - LIKE on unindexed description (no index will help)")
        sql_like = "SELECT id, title FROM Event_bench WHERE description LIKE '%electronic%'"
        plan_like = explain(cur, sql_like)
        print_explain(plan_like)
        t_like = time_query(cur, sql_like, repeats=3)
        print(f"  rows returned: {t_like['rows']}, "
              f"median: {t_like['med_ms']:.1f} ms, "
              f"min: {t_like['min_ms']:.1f} ms")

        # ---------------- Intermediate: range filter, no index ----------------
        section(f"INTERMEDIATE - event_date BETWEEN {DATE_LO} AND {DATE_HI}, NO INDEX (full scan)")
        sql_date = (f"SELECT id, title, event_date FROM Event_bench "
                    f"WHERE event_date BETWEEN '{DATE_LO}' AND '{DATE_HI}'")
        plan_noidx = explain(cur, sql_date)
        print_explain(plan_noidx)
        t_noidx = time_query(cur, sql_date, repeats=5)
        print(f"  rows returned: {t_noidx['rows']}, "
              f"median: {t_noidx['med_ms']:.1f} ms, "
              f"min: {t_noidx['min_ms']:.1f} ms")

        # ---------------- Advanced: same query, with B-tree index ----------------
        section("ADVANCED - same query AFTER CREATE INDEX idx_bench_date")
        cur.execute("CREATE INDEX idx_bench_date ON Event_bench(event_date)")
        cn.commit()
        plan_idx = explain(cur, sql_date)
        print_explain(plan_idx)
        t_idx = time_query(cur, sql_date, repeats=5)
        print(f"  rows returned: {t_idx['rows']}, "
              f"median: {t_idx['med_ms']:.1f} ms, "
              f"min: {t_idx['min_ms']:.1f} ms")

        # ---------------- Summary ----------------
        banner("SUMMARY", char="-")
        speedup = t_noidx["med_ms"] / max(t_idx["med_ms"], 0.001)
        rows = [
            ["BASIC LIKE (unindexed)",  plan_like[0]["type"],  plan_like[0]["rows"],  f"{t_like['med_ms']:.1f}"],
            ["INTER  range, no index",  plan_noidx[0]["type"], plan_noidx[0]["rows"], f"{t_noidx['med_ms']:.1f}"],
            ["ADV    range, indexed",   plan_idx[0]["type"],   plan_idx[0]["rows"],   f"{t_idx['med_ms']:.1f}"],
        ]
        print_table(["query", "EXPLAIN type", "rows examined", "median ms"], rows)
        print()
        print(f"Indexed range scan vs full scan: {speedup:.1f}x faster on {N_ROWS:,} rows.")
        print("EXPLAIN type drops from ALL to range; rows examined drops from")
        print(f"~{N_ROWS:,} to a small fraction (the matching range only).")

        # ---------------- Cleanup ----------------
        cur.execute("DROP TABLE Event_bench")
        cn.commit()
        print("\nCleanup: Event_bench dropped.")


if __name__ == "__main__":
    main()
