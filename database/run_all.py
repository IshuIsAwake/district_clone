"""
run_all.py - orchestrates the full Zomato District DB demo.

Connects to a local MySQL instance using credentials from .env, then:
    1. Creates the database + schema (schema.sql)
    2. Loads sample data (seed_data.sql)
    3. Creates views / functions / procedures (advanced.sql)
    4. Runs every query from queries.sql with a labelled header
    5. Demonstrates stored procedures, functions, transactions, DCL

The terminal output is the artifact that goes into the report screenshots,
so every section is preceded by a banner.
"""

import os
import re
import sys
from pathlib import Path

import mysql.connector
from mysql.connector import errorcode
from tabulate import tabulate

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
except ImportError:
    pass

ROOT = Path(__file__).resolve().parent
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "zomato_district")

BANNER_WIDTH = 72


# ---------- helpers ----------------------------------------------------------

def banner(title, char="="):
    print()
    print(char * BANNER_WIDTH)
    print(f" {title}")
    print(char * BANNER_WIDTH)


def subhead(title):
    print()
    print(f"--- {title} " + "-" * max(0, BANNER_WIDTH - len(title) - 5))


def connect(use_db=False):
    cfg = dict(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD,
               autocommit=False)
    if use_db:
        cfg["database"] = DB_NAME
    return mysql.connector.connect(**cfg)


def _strip_sql_comments(chunk):
    """Drop comment-only lines from a chunk while keeping real SQL intact."""
    return "\n".join(
        line for line in chunk.splitlines()
        if line.strip() and not line.strip().startswith("--")
    ).strip()


def run_script_simple(cursor, sql_text):
    """Run a .sql file whose statements are separated by ';' (no procedures)."""
    for raw in sql_text.split(";"):
        stmt = _strip_sql_comments(raw)
        if stmt:
            cursor.execute(stmt)


def run_script_split(cursor, sql_text, marker="-- ===SQL_SPLIT==="):
    """Run a .sql file whose statements are split by an explicit marker.
    Required for CREATE PROCEDURE / FUNCTION bodies that contain ';'."""
    for chunk in sql_text.split(marker):
        cleaned = _strip_sql_comments(chunk).rstrip(";").strip()
        if cleaned:
            cursor.execute(cleaned)


def print_result(cursor, title=None):
    if title:
        subhead(title)
    rows = cursor.fetchall()
    cols = [d[0] for d in cursor.description] if cursor.description else []
    if not rows:
        print("(no rows)")
        return
    print(tabulate(rows, headers=cols, tablefmt="simple", floatfmt=".2f"))
    print(f"[{len(rows)} row(s)]")


def run_query(cursor, title, sql, params=None):
    subhead(title)
    cursor.execute(sql, params or ())
    rows = cursor.fetchall()
    cols = [d[0] for d in cursor.description] if cursor.description else []
    if rows:
        print(tabulate(rows, headers=cols, tablefmt="simple", floatfmt=".2f"))
        print(f"[{len(rows)} row(s)]")
    else:
        print("(no rows)")


# ---------- sections ---------------------------------------------------------

def create_database_and_schema():
    banner("Step 1  Create database + schema")
    schema_sql = (ROOT / "schema.sql").read_text()
    conn = connect(use_db=False)
    try:
        cur = conn.cursor()
        run_script_simple(cur, schema_sql)
        conn.commit()
        print("schema.sql executed ok")
    finally:
        conn.close()


def insert_seed():
    banner("Step 2  Insert sample data")
    seed_sql = (ROOT / "seed_data.sql").read_text()
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()
        run_script_simple(cur, seed_sql)
        conn.commit()
        cur.execute("SELECT COUNT(*) FROM Event")
        n_events = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM Booking")
        n_bookings = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM User")
        n_users = cur.fetchone()[0]
        print(f"seeded: {n_users} users, {n_events} events, {n_bookings} bookings")
    finally:
        conn.close()


def create_advanced_objects():
    banner("Step 3  Create views, functions and stored procedures")
    adv_sql = (ROOT / "advanced.sql").read_text()
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()
        run_script_split(cur, adv_sql)
        conn.commit()
        print("advanced.sql executed ok (3 views, 2 functions, 3 procedures)")
    finally:
        conn.close()


def run_queries_showcase():
    banner("Step 4  DQL showcase (joins / grouping / subqueries / functions)")
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()

        run_query(cur, "Q1. INNER JOIN - confirmed bookings with user + venue", """
            SELECT b.booking_id, u.name AS customer, e.title AS event_title,
                   l.venue_name, l.city, b.number_of_people, b.total_price
            FROM Booking b
            JOIN User u ON u.user_id = b.user_id
            JOIN Event e ON e.event_id = b.event_id
            JOIN Location l ON l.location_id = e.location_id
            WHERE b.status = 'confirmed'
            ORDER BY b.booking_id
        """)

        run_query(cur, "Q2. LEFT JOIN - all events + reviews (unreviewed included)", """
            SELECT e.event_id, e.title, u.name AS reviewer, r.rating, r.comment
            FROM Event e
            LEFT JOIN Review r ON r.event_id = e.event_id
            LEFT JOIN User u ON u.user_id = r.user_id
            ORDER BY e.event_id, r.review_id
        """)

        run_query(cur, "Q3. RIGHT JOIN - all transactions with booking status", """
            SELECT t.transaction_id, t.payment_method, t.amount,
                   t.payment_status, b.booking_id, b.status AS booking_status
            FROM Booking b
            RIGHT JOIN Transaction t ON t.booking_id = b.booking_id
            ORDER BY t.transaction_id
        """)

        run_query(cur, "Q4. FULL OUTER JOIN (UNION of LEFT + RIGHT)", """
            SELECT u.user_id, u.name, b.booking_id, b.total_price
            FROM User u LEFT JOIN Booking b ON b.user_id = u.user_id
            UNION
            SELECT u.user_id, u.name, b.booking_id, b.total_price
            FROM User u RIGHT JOIN Booking b ON b.user_id = u.user_id
            ORDER BY user_id, booking_id
        """)

        run_query(cur, "Q5. SELF JOIN - users from the same city", """
            SELECT a.name AS user_a, b.name AS user_b, a.city
            FROM User a JOIN User b
                 ON a.city = b.city AND a.user_id < b.user_id
            ORDER BY a.city, a.name
        """)

        run_query(cur, "Q6. GROUP BY + HAVING - revenue per event (> 2000)", """
            SELECT e.event_id, e.title,
                   SUM(b.total_price) AS revenue,
                   COUNT(*) AS confirmed_bookings
            FROM Event e
            JOIN Booking b ON b.event_id = e.event_id
            WHERE b.status = 'confirmed'
            GROUP BY e.event_id, e.title
            HAVING SUM(b.total_price) > 2000
            ORDER BY revenue DESC
        """)

        run_query(cur, "Q7. GROUP BY - avg rating per reviewed event", """
            SELECT e.event_id, e.title,
                   ROUND(AVG(r.rating), 2) AS avg_rating,
                   COUNT(r.review_id) AS review_count
            FROM Event e JOIN Review r ON r.event_id = e.event_id
            GROUP BY e.event_id, e.title
            ORDER BY avg_rating DESC
        """)

        run_query(cur, "Q8. GROUP BY - bookings + revenue by payment method", """
            SELECT payment_method, COUNT(*) AS txn_count,
                   SUM(amount) AS total_collected
            FROM Transaction
            GROUP BY payment_method
            ORDER BY txn_count DESC
        """)

        run_query(cur, "Q9. ORDER BY - upcoming events by price", """
            SELECT event_id, title, event_date, price
            FROM Event
            WHERE event_date >= CURRENT_DATE
            ORDER BY price DESC, event_date ASC
        """)

        run_query(cur, "Q10. Simple subquery - events above avg price", """
            SELECT event_id, title, price
            FROM Event
            WHERE price > (SELECT AVG(price) FROM Event)
            ORDER BY price DESC
        """)

        run_query(cur, "Q11. IN subquery - users with >1 distinct booking", """
            SELECT user_id, name, email FROM User
            WHERE user_id IN (
                SELECT user_id FROM Booking
                WHERE status = 'confirmed'
                GROUP BY user_id
                HAVING COUNT(DISTINCT event_id) > 1
            )
        """)

        run_query(cur, "Q12. Correlated subquery - highest booking per event", """
            SELECT b.booking_id, b.event_id, b.user_id, b.total_price
            FROM Booking b
            WHERE b.status = 'confirmed'
              AND b.total_price = (
                  SELECT MAX(b2.total_price)
                  FROM Booking b2
                  WHERE b2.event_id = b.event_id AND b2.status = 'confirmed'
              )
            ORDER BY b.event_id
        """)

        run_query(cur, "Q13. Aggregates on Event", """
            SELECT COUNT(*) AS total_events,
                   MIN(price) AS cheapest,
                   MAX(price) AS priciest,
                   ROUND(AVG(price), 2) AS avg_price,
                   SUM(seats_available) AS total_seats_left
            FROM Event
        """)

        run_query(cur, "Q14. Scalar functions on User", """
            SELECT user_id,
                   UPPER(name) AS name_upper,
                   LENGTH(email) AS email_length,
                   CONCAT(name, ' - ', city) AS tag,
                   FLOOR(DATEDIFF(CURRENT_DATE, dob) / 365) AS age_years,
                   COALESCE(CAST(anniversary_date AS CHAR), 'n/a') AS anniv
            FROM User
            ORDER BY user_id
        """)
    finally:
        conn.close()


def demo_views():
    banner("Step 5  Views in action")
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()
        run_query(cur, "vw_event_dashboard", "SELECT * FROM vw_event_dashboard ORDER BY event_date")
        run_query(cur, "vw_booking_summary (first 8)",
                  "SELECT * FROM vw_booking_summary ORDER BY booking_id LIMIT 8")
        run_query(cur, "vw_event_lineup", "SELECT * FROM vw_event_lineup")
    finally:
        conn.close()


def demo_functions():
    banner("Step 6  User-defined functions")
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()
        run_query(cur, "fn_seats_remaining - stored vs. computed", """
            SELECT e.event_id, e.title,
                   e.seats_available       AS stored_value,
                   fn_seats_remaining(e.event_id) AS computed_value
            FROM Event e
            ORDER BY e.event_id
        """)

        run_query(cur, "fn_apply_discount - apply each active offer to Rs 2000", """
            SELECT code, type, discount_value,
                   fn_apply_discount(2000, code) AS final_amount
            FROM Offer ORDER BY offer_id
        """)
    finally:
        conn.close()


def demo_procedures():
    banner("Step 7  Stored procedures")
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()

        subhead("sp_search_events('Bangalore', NULL) - upcoming in Bangalore")
        cur.callproc("sp_search_events", ("Bangalore", None))
        for result in cur.stored_results():
            rows = result.fetchall()
            cols = [d[0] for d in result.description]
            print(tabulate(rows, headers=cols, tablefmt="simple", floatfmt=".2f"))
            print(f"[{len(rows)} row(s)]")

        subhead("sp_book_event(3, 5, 2, 'UPI') - Rohan books Local Train")
        cur.callproc("sp_book_event", (3, 5, 2, "UPI"))
        for result in cur.stored_results():
            rows = result.fetchall()
            cols = [d[0] for d in result.description]
            print(tabulate(rows, headers=cols, tablefmt="simple", floatfmt=".2f"))
        conn.commit()

        run_query(cur, "Event 5 seats after booking", """
            SELECT event_id, title, seats_available FROM Event WHERE event_id = 5
        """)

        subhead("sp_cancel_booking(4) - cancel booking 4")
        cur.callproc("sp_cancel_booking", (4,))
        conn.commit()
        run_query(cur, "Booking 4 + event 3 after cancellation", """
            SELECT b.booking_id, b.status, t.payment_status,
                   e.event_id, e.seats_available
            FROM Booking b
            JOIN Transaction t ON t.booking_id = b.booking_id
            JOIN Event e ON e.event_id = b.event_id
            WHERE b.booking_id = 4
        """)
    finally:
        conn.close()


def demo_transactions():
    banner("Step 8  TCL - COMMIT / ROLLBACK / SAVEPOINT")
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()

        subhead("COMMIT - Aarav (1) books Food Fest (4), 3 people")
        cur.execute("START TRANSACTION")
        cur.execute("""
            INSERT INTO Booking (user_id, event_id, number_of_people, total_price, status)
            VALUES (1, 4, 3, 897.00, 'confirmed')
        """)
        new_booking_id = cur.lastrowid
        cur.execute("""
            INSERT INTO Transaction (booking_id, payment_method, amount, payment_status)
            VALUES (%s, 'UPI', 897.00, 'completed')
        """, (new_booking_id,))
        cur.execute("COMMIT")
        print(f"committed new booking id = {new_booking_id}")

        subhead("ROLLBACK - failed payment simulation on event 6")
        cur.execute("START TRANSACTION")
        cur.execute("""
            INSERT INTO Booking (user_id, event_id, number_of_people, total_price, status)
            VALUES (8, 6, 2, 1998.00, 'pending')
        """)
        rb_id = cur.lastrowid
        print(f"tentative booking id = {rb_id} (before rollback)")
        cur.execute("ROLLBACK")
        cur.execute("SELECT COUNT(*) FROM Booking WHERE booking_id = %s", (rb_id,))
        exists = cur.fetchone()[0]
        print(f"booking {rb_id} exists after rollback? {'yes' if exists else 'no'}")

        subhead("SAVEPOINT - save + review, roll back just the review")
        cur.execute("START TRANSACTION")
        cur.execute("""
            INSERT IGNORE INTO Saved_Item (user_id, event_id) VALUES (7, 3)
        """)
        cur.execute("SAVEPOINT sp_before_review")
        try:
            cur.execute("""
                INSERT INTO Review (user_id, event_id, rating, comment)
                VALUES (7, 3, 6, 'invalid rating on purpose')
            """)
        except mysql.connector.Error as err:
            print(f"review insert failed (expected): {err.msg}")
            cur.execute("ROLLBACK TO sp_before_review")
        cur.execute("COMMIT")
        cur.execute("SELECT COUNT(*) FROM Saved_Item WHERE user_id=7 AND event_id=3")
        print(f"saved item persisted? {'yes' if cur.fetchone()[0] else 'no'}")
    finally:
        conn.close()


def demo_dcl():
    banner("Step 9  DCL - CREATE USER / GRANT / REVOKE")
    conn = connect(use_db=True)
    try:
        cur = conn.cursor()
        for stmt in [
            "DROP USER IF EXISTS 'zomato_admin'@'localhost'",
            "DROP USER IF EXISTS 'zomato_viewer'@'localhost'",
            "CREATE USER 'zomato_admin'@'localhost'  IDENTIFIED BY 'AdminPass_123'",
            "CREATE USER 'zomato_viewer'@'localhost' IDENTIFIED BY 'ViewerPass_123'",
            "GRANT ALL PRIVILEGES ON zomato_district.* TO 'zomato_admin'@'localhost'",
            "GRANT SELECT, INSERT          ON zomato_district.* TO 'zomato_viewer'@'localhost'",
            "REVOKE INSERT                 ON zomato_district.* FROM 'zomato_viewer'@'localhost'",
            "FLUSH PRIVILEGES",
        ]:
            try:
                cur.execute(stmt)
                print(f"ok  {stmt}")
            except mysql.connector.Error as err:
                print(f"skip {stmt}  ({err.msg})")

        run_query(cur, "Privileges for zomato_viewer", """
            SELECT GRANTEE, PRIVILEGE_TYPE
            FROM information_schema.SCHEMA_PRIVILEGES
            WHERE GRANTEE LIKE '%zomato_viewer%'
        """)
    finally:
        conn.close()


# ---------- main -------------------------------------------------------------

def main():
    try:
        create_database_and_schema()
        insert_seed()
        create_advanced_objects()
        run_queries_showcase()
        demo_views()
        demo_functions()
        demo_procedures()
        demo_transactions()
        demo_dcl()
        banner("DONE", char="#")
        print("All sections executed successfully.")
    except mysql.connector.Error as err:
        print(f"\nMySQL error: {err}")
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print("Fix DB_USER / DB_PASSWORD in .env and try again.")
        elif err.errno == errorcode.CR_CONN_HOST_ERROR:
            print("Could not reach the DB host. Is MySQL running?")
        sys.exit(1)


if __name__ == "__main__":
    main()
