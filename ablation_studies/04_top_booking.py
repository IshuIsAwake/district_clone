"""Ablation #4 - Top booking per event: three idioms, same answer.

For each confirmed booking, find the highest-priced one PER event.

  basic         - correlated subquery (the queries.sql Q12 shape).
  intermediate  - tuple IN against a derived table (one aggregation pass).
  advanced      - INNER JOIN against the per-event MAX (the same idea,
                  expressed as a join).

We assert all three return the same row set, then time them and capture
EXPLAIN. The interesting metric is `EXPLAIN.rows` per idiom and the
median wall-clock - on this size of dataset the absolute numbers are
small, but the rows-examined column reveals what the optimizer does.
"""
from __future__ import annotations

from _common import banner, cursor, explain, print_explain, print_table, section, time_query

REPEATS = 7

SQL_CORRELATED = """
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
WHERE b.status = 'confirmed'
  AND b.total_price = (
      SELECT MAX(b2.total_price)
      FROM Booking b2
      WHERE b2.event_id = b.event_id AND b2.status = 'confirmed'
  )
ORDER BY b.event_id, b.booking_id
"""

SQL_TUPLE_IN = """
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
WHERE b.status = 'confirmed'
  AND (b.event_id, b.total_price) IN (
      SELECT event_id, MAX(total_price)
      FROM Booking
      WHERE status = 'confirmed'
      GROUP BY event_id
  )
ORDER BY b.event_id, b.booking_id
"""

SQL_JOIN_MAX = """
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
JOIN (
    SELECT event_id, MAX(total_price) AS top
    FROM Booking
    WHERE status = 'confirmed'
    GROUP BY event_id
) m ON m.event_id = b.event_id AND m.top = b.total_price
WHERE b.status = 'confirmed'
ORDER BY b.event_id, b.booking_id
"""


def main():
    banner("ABLATION #4 - TOP BOOKING PER EVENT (three idioms)")

    with cursor() as (_, cur):
        # Correctness check first.
        section("Correctness check - all three idioms must return the same rows")
        results = {}
        for name, sql in [("correlated", SQL_CORRELATED),
                          ("tuple_in",   SQL_TUPLE_IN),
                          ("join_max",   SQL_JOIN_MAX)]:
            cur.execute(sql)
            results[name] = sorted(cur.fetchall())
            print(f"  {name:12s}: {len(results[name])} rows")

        ok = results["correlated"] == results["tuple_in"] == results["join_max"]
        print(f"  identical row sets: {ok}")
        if not ok:
            raise SystemExit("Idioms returned different rows - aborting benchmark.")

        # ---------------- Plans + timings ----------------
        for name, label, sql in [
            ("correlated", "BASIC - correlated subquery (Q12 shape)",     SQL_CORRELATED),
            ("tuple_in",   "INTERMEDIATE - tuple IN against derived MAX", SQL_TUPLE_IN),
            ("join_max",   "ADVANCED - JOIN against per-event MAX",       SQL_JOIN_MAX),
        ]:
            section(label)
            plan = explain(cur, sql)
            print_explain(plan)
            t = time_query(cur, sql, repeats=REPEATS)
            results[name + "_t"]    = t
            results[name + "_plan"] = plan
            print(f"  rows: {t['rows']}, median: {t['med_ms']:.2f} ms, min: {t['min_ms']:.2f} ms")

        # ---------------- Summary ----------------
        banner("SUMMARY", char="-")
        rows = []
        for name, label in [("correlated", "BASIC  correlated"),
                            ("tuple_in",   "INTER  tuple IN derived"),
                            ("join_max",   "ADV    JOIN per-event MAX")]:
            t = results[name + "_t"]
            plan = results[name + "_plan"]
            total_rows_examined = sum(int(p.get("rows") or 0) for p in plan)
            rows.append([label,
                         len(plan),
                         total_rows_examined,
                         f"{t['med_ms']:.2f}",
                         f"{t['min_ms']:.2f}"])
        print_table(
            ["idiom", "plan steps", "sum rows examined", "median ms", "min ms"],
            rows,
        )
        print()
        print("All three return the same answer. The point is to see how the optimizer")
        print("treats each shape: 'plan steps' and 'sum rows examined' summarise that.")
        print("On a real workload, the JOIN form is usually the easiest for the")
        print("planner to reason about.")


if __name__ == "__main__":
    main()
