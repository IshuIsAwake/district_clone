"""Ablation #3 - N+1 vs correlated subquery vs single GROUP BY.

Question:  for every event, fetch (event_id, title, avg_rating, review_count).

  basic         - N+1: SELECT events; loop in Python; one AVG query per event.
  intermediate  - one round-trip with a correlated subquery in the SELECT.
  advanced      - one round-trip, single LEFT JOIN + GROUP BY (the shape
                  used in vw_event_dashboard).

Returns the same answer; we time wall-clock (median over repeats) and
report the gap. The seeded Event table is small, so the difference
demonstrates the SHAPE of the cost (linear in rows for N+1) rather than
absolute headline numbers - that distinction is fine for the report.
"""
from __future__ import annotations

import statistics
import time

from _common import banner, cursor, print_table, section, time_query

REPEATS = 7


def run_n_plus_one(cur) -> dict:
    """Iterate from Python: one query for the list, then one per event."""
    timings = []
    rows_out = 0
    for _ in range(REPEATS):
        t0 = time.perf_counter()
        cur.execute("SELECT event_id, title FROM Event ORDER BY event_id")
        events = cur.fetchall()
        results = []
        for event_id, title in events:
            cur.execute("SELECT ROUND(AVG(rating), 2), COUNT(*) "
                        "FROM Review WHERE event_id=%s", (event_id,))
            avg, count = cur.fetchone()
            results.append((event_id, title, avg, count))
        timings.append((time.perf_counter() - t0) * 1000)
        rows_out = len(results)
    return {
        "rows":   rows_out,
        "med_ms": statistics.median(timings),
        "min_ms": min(timings),
        "queries": rows_out + 1,
    }


def main():
    banner("ABLATION #3 - N+1 vs CORRELATED vs GROUP BY")

    with cursor() as (_, cur):
        section("BASIC - N+1 from Python (1 list query + N AVG queries)")
        t_basic = run_n_plus_one(cur)
        print(f"  rows: {t_basic['rows']}, "
              f"server round-trips: {t_basic['queries']}, "
              f"median: {t_basic['med_ms']:.2f} ms, "
              f"min: {t_basic['min_ms']:.2f} ms")

        section("INTERMEDIATE - correlated subquery in SELECT (1 round-trip)")
        sql_corr = """
            SELECT e.event_id, e.title,
                   (SELECT ROUND(AVG(r.rating), 2)
                      FROM Review r WHERE r.event_id = e.event_id) AS avg_rating,
                   (SELECT COUNT(*)
                      FROM Review r WHERE r.event_id = e.event_id) AS review_count
            FROM Event e
            ORDER BY e.event_id
        """
        t_corr = time_query(cur, sql_corr, repeats=REPEATS)
        print(f"  rows: {t_corr['rows']}, "
              f"median: {t_corr['med_ms']:.2f} ms, "
              f"min: {t_corr['min_ms']:.2f} ms")

        section("ADVANCED - single LEFT JOIN + GROUP BY (1 round-trip)")
        sql_group = """
            SELECT e.event_id, e.title,
                   COALESCE(ROUND(AVG(r.rating), 2), 0) AS avg_rating,
                   COUNT(r.review_id)                   AS review_count
            FROM Event e
            LEFT JOIN Review r ON r.event_id = e.event_id
            GROUP BY e.event_id, e.title
            ORDER BY e.event_id
        """
        t_group = time_query(cur, sql_group, repeats=REPEATS)
        print(f"  rows: {t_group['rows']}, "
              f"median: {t_group['med_ms']:.2f} ms, "
              f"min: {t_group['min_ms']:.2f} ms")

        banner("SUMMARY", char="-")
        rows = [
            ["BASIC  N+1 from Python",        t_basic["queries"], f"{t_basic['med_ms']:.2f}", f"{t_basic['min_ms']:.2f}"],
            ["INTER  correlated subquery",    1,                  f"{t_corr['med_ms']:.2f}",  f"{t_corr['min_ms']:.2f}"],
            ["ADV    LEFT JOIN + GROUP BY",   1,                  f"{t_group['med_ms']:.2f}", f"{t_group['min_ms']:.2f}"],
        ]
        print_table(["query", "round-trips", "median ms", "min ms"], rows)
        print()
        print("Cost shape:")
        print("  - N+1's wall-clock grows linearly with the number of events,")
        print("    because every iteration pays parse+plan+execute + protocol overhead.")
        print("  - Correlated and GROUP BY are both single round-trips; the optimizer")
        print("    often rewrites the correlated form to something close to the JOIN.")


if __name__ == "__main__":
    main()
