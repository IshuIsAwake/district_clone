"""Ablation #1 - Concurrent booking: race vs lock.

Three booking implementations face N parallel threads competing for ONE seat.

  basic         - autocommit, separate SELECT (seat-check) and INSERT.
                  TOCTOU window between the two statements.
  intermediate  - START TRANSACTION wrapping check+insert. No FOR UPDATE.
                  Default REPEATABLE READ snapshot - check still races.
  advanced      - CALL sp_book_event under START TRANSACTION. The procedure
                  acquires an X-lock on the Event row via SELECT...FOR UPDATE
                  before checking fn_seats_remaining. Strict 2PL.

Metric: how many threads successfully INSERTed when only 1 seat existed.
        Anything above 1 is an overbooking - data the database refused to
        protect because the chosen strategy did not enforce it.

Setup:  creates a temporary Event with seats_available = 1 and routes all
        three tiers at it. Cleans up afterwards.
"""
from __future__ import annotations

import statistics
import threading
import time

from _common import banner, connect, cursor, print_table, section

N_THREADS = 20
USER_ID = 1  # any seeded user works


def setup_test_event() -> int:
    """Create a 1-seat event (and a host/category/location if missing). Return event_id."""
    with cursor() as (_, cur):
        # Reuse seeded category 1, location 1, host 1.
        cur.execute("""
            INSERT INTO Event (title, event_date, start_time, duration,
                               seats_available, price, description,
                               category_id, location_id, host_id)
            VALUES ('ABLATION-1 race-test event', '2026-12-31', '20:00:00', 60,
                    1, 100.00, 'temp event for concurrency benchmark', 1, 1, 1)
        """)
        cur.execute("SELECT LAST_INSERT_ID()")
        return cur.fetchone()[0]


def reset_event(event_id: int) -> None:
    """Wipe any bookings against this event so the next tier starts fresh."""
    with cursor() as (_, cur):
        cur.execute("DELETE t FROM Transaction t "
                    "JOIN Booking b ON b.booking_id=t.booking_id "
                    "WHERE b.event_id=%s", (event_id,))
        cur.execute("DELETE FROM Booking WHERE event_id=%s", (event_id,))


def cleanup(event_id: int) -> None:
    reset_event(event_id)
    with cursor() as (_, cur):
        cur.execute("DELETE FROM Event WHERE event_id=%s", (event_id,))


# -----------------------------------------------------------------------
# Booking attempt strategies
# -----------------------------------------------------------------------

def attempt_basic(event_id: int) -> tuple[bool, float, str]:
    """No transaction. Auto-committed SELECT then INSERT - classic TOCTOU."""
    cn = connect(autocommit=True)
    cur = cn.cursor()
    t0 = time.perf_counter()
    try:
        cur.execute("SELECT fn_seats_remaining(%s)", (event_id,))
        remaining = cur.fetchone()[0]
        if remaining < 1:
            return False, (time.perf_counter() - t0) * 1000, "seats=0"
        cur.execute("INSERT INTO Booking (user_id, event_id, number_of_people, "
                    "total_price, status) VALUES (%s, %s, 1, 100, 'confirmed')",
                    (USER_ID, event_id))
        booking_id = cur.lastrowid
        cur.execute("INSERT INTO Transaction (booking_id, payment_method, amount, "
                    "payment_status) VALUES (%s, 'UPI', 100, 'completed')",
                    (booking_id,))
        return True, (time.perf_counter() - t0) * 1000, "ok"
    except Exception as e:
        return False, (time.perf_counter() - t0) * 1000, str(e)[:40]
    finally:
        cur.close(); cn.close()


def attempt_intermediate(event_id: int) -> tuple[bool, float, str]:
    """START TRANSACTION wraps check+insert. Still no FOR UPDATE."""
    cn = connect(autocommit=False)
    cur = cn.cursor()
    t0 = time.perf_counter()
    try:
        cur.execute("START TRANSACTION")
        cur.execute("SELECT fn_seats_remaining(%s)", (event_id,))
        remaining = cur.fetchone()[0]
        if remaining < 1:
            cn.rollback()
            return False, (time.perf_counter() - t0) * 1000, "seats=0"
        cur.execute("INSERT INTO Booking (user_id, event_id, number_of_people, "
                    "total_price, status) VALUES (%s, %s, 1, 100, 'confirmed')",
                    (USER_ID, event_id))
        booking_id = cur.lastrowid
        cur.execute("INSERT INTO Transaction (booking_id, payment_method, amount, "
                    "payment_status) VALUES (%s, 'UPI', 100, 'completed')",
                    (booking_id,))
        cn.commit()
        return True, (time.perf_counter() - t0) * 1000, "ok"
    except Exception as e:
        cn.rollback()
        return False, (time.perf_counter() - t0) * 1000, str(e)[:40]
    finally:
        cur.close(); cn.close()


def attempt_advanced(event_id: int) -> tuple[bool, float, str]:
    """CALL sp_book_event under START TRANSACTION. FOR UPDATE inside the proc."""
    cn = connect(autocommit=False)
    cur = cn.cursor()
    t0 = time.perf_counter()
    try:
        cur.execute("START TRANSACTION")
        cur.callproc("sp_book_event", (USER_ID, event_id, 1, "UPI"))
        cn.commit()
        return True, (time.perf_counter() - t0) * 1000, "ok"
    except Exception as e:
        cn.rollback()
        msg = str(e)
        # The procedure raises SIGNAL SQLSTATE '45000' for "Not enough seats".
        return False, (time.perf_counter() - t0) * 1000, "blocked/seats=0" if "seats" in msg.lower() else msg[:40]
    finally:
        cur.close(); cn.close()


# -----------------------------------------------------------------------
# Driver
# -----------------------------------------------------------------------

def run_tier(name: str, fn, event_id: int) -> dict:
    section(f"Tier: {name}  (firing {N_THREADS} parallel attempts)")
    reset_event(event_id)

    results: list[tuple[bool, float, str]] = []
    lock = threading.Lock()

    def worker():
        r = fn(event_id)
        with lock:
            results.append(r)

    # Build threads first, then release them as close to simultaneously as we can.
    barrier = threading.Barrier(N_THREADS)

    def gated():
        barrier.wait()
        worker()

    threads = [threading.Thread(target=gated) for _ in range(N_THREADS)]
    t0 = time.perf_counter()
    for t in threads: t.start()
    for t in threads: t.join()
    wall = (time.perf_counter() - t0) * 1000.0

    successes = sum(1 for ok, _, _ in results if ok)
    fail_reasons: dict[str, int] = {}
    for ok, _, reason in results:
        if not ok:
            fail_reasons[reason] = fail_reasons.get(reason, 0) + 1
    latencies = [ms for _, ms, _ in results]
    overbookings = max(0, successes - 1)

    print(f"  successes:    {successes} / {N_THREADS}")
    print(f"  overbookings: {overbookings}  (anything > 0 is data corruption)")
    print(f"  median lat:   {statistics.median(latencies):.1f} ms")
    print(f"  max lat:      {max(latencies):.1f} ms")
    print(f"  wall clock:   {wall:.1f} ms")
    if fail_reasons:
        print(f"  failure reasons:")
        for r, c in sorted(fail_reasons.items(), key=lambda kv: -kv[1]):
            print(f"    {c:3d} x {r}")

    return {
        "tier": name,
        "successes": successes,
        "overbookings": overbookings,
        "median_ms": statistics.median(latencies),
        "max_ms": max(latencies),
        "wall_ms": wall,
    }


def main():
    banner("ABLATION #1 - CONCURRENT BOOKING (race vs lock)")
    print(f"Setup: 1-seat event, {N_THREADS} parallel booking attempts, "
          f"each asking for 1 seat.")

    event_id = setup_test_event()
    print(f"Test event_id = {event_id}")

    try:
        rows = []
        for name, fn in [
            ("basic (no txn)",      attempt_basic),
            ("intermediate (txn)",  attempt_intermediate),
            ("advanced (FOR UPDATE)", attempt_advanced),
        ]:
            r = run_tier(name, fn, event_id)
            rows.append([
                r["tier"],
                f"{r['successes']}/{N_THREADS}",
                r["overbookings"],
                f"{r['median_ms']:.1f}",
                f"{r['max_ms']:.1f}",
                f"{r['wall_ms']:.1f}",
            ])

        banner("SUMMARY", char="-")
        print_table(
            ["tier", "ok/total", "overbook", "median ms", "max ms", "wall ms"],
            rows,
        )
        print()
        print("Reading the table:")
        print("  - 'overbook' is the number of confirmed bookings beyond capacity (1).")
        print("  - basic and intermediate should both leak; only advanced stays at 0.")
        print("  - advanced pays a latency cost: threads queue on the X-lock, but")
        print("    correctness is enforced regardless of arrival order.")
    finally:
        cleanup(event_id)
        print("\nCleanup: test event + bookings deleted.")


if __name__ == "__main__":
    main()
