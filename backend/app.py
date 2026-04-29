import os
import re
import time
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv
from flask import Flask, jsonify, request

from presets import PRESETS
from query_guard import validate as validate_readonly

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "database"
load_dotenv(ROOT / ".env")


# ---------- SQL block loader -------------------------------------------------
# Each preset references a (file, id) pair. A block is delimited inside the
# .sql file by a line of the form "-- @id <id>". The block runs from one
# such line to the next "-- @id" line (or to EOF). The marker line itself
# is stripped from the returned SQL so the playground shows clean code.

_ID_RE = re.compile(r"^\s*--\s*@id\s+(\S+)\s*$")


def _parse_blocks(text: str) -> dict[str, str]:
    blocks: dict[str, str] = {}
    current_id: str | None = None
    current_lines: list[str] = []
    for line in text.splitlines():
        m = _ID_RE.match(line)
        if m:
            if current_id is not None:
                blocks[current_id] = "\n".join(current_lines).strip()
            current_id = m.group(1)
            current_lines = []
        elif current_id is not None:
            current_lines.append(line)
    if current_id is not None:
        blocks[current_id] = "\n".join(current_lines).strip()
    return blocks


def load_block(source: str, block_id: str) -> str:
    # Read on every call - files are small, this runs on localhost, and
    # dev-mode edits to .sql files take effect without restart.
    text = (DB_DIR / source).read_text()
    blocks = _parse_blocks(text)
    if block_id not in blocks:
        raise KeyError(f"preset id '{block_id}' not found in {source}")
    return blocks[block_id]

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", "3306")),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "zomato_district"),
}

DEMO_USER_ID = int(os.getenv("DEMO_USER_ID", "1"))

app = Flask(
    __name__,
    static_folder=str(ROOT / "frontend"),
    static_url_path="",
)


# ---------- helpers ----------------------------------------------------------

def get_conn():
    return mysql.connector.connect(**DB_CONFIG)


def jsonable(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, timedelta):
        total = int(value.total_seconds())
        h, rem = divmod(total, 3600)
        m, s = divmod(rem, 60)
        return f"{h:02d}:{m:02d}:{s:02d}"
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8")
        except UnicodeDecodeError:
            return value.hex()
    return value


def rows_to_json(columns, rows):
    out = []
    for row in rows:
        out.append({col: jsonable(val) for col, val in zip(columns, row)})
    return out


def db_error(exc):
    msg = str(exc)
    if hasattr(exc, "msg"):
        msg = exc.msg
    return jsonify({"error": msg}), 400


# ---------- static routes ----------------------------------------------------

@app.route("/")
def root():
    return app.send_static_file("index.html")


# ---------- reference data ---------------------------------------------------

@app.route("/api/categories")
def list_categories():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "SELECT category_id, category_name FROM Event_Category ORDER BY category_name"
        )
        data = rows_to_json([c[0] for c in cur.description], cur.fetchall())
        cur.close(); conn.close()
        return jsonify(data)
    except mysql.connector.Error as e:
        return db_error(e)


@app.route("/api/cities")
def list_cities():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT DISTINCT city FROM Location ORDER BY city")
        data = [r[0] for r in cur.fetchall()]
        cur.close(); conn.close()
        return jsonify(data)
    except mysql.connector.Error as e:
        return db_error(e)


@app.route("/api/offers")
def list_offers():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "SELECT offer_id, code, type, discount_value, is_active "
            "FROM Offer WHERE is_active = TRUE ORDER BY code"
        )
        data = rows_to_json([c[0] for c in cur.description], cur.fetchall())
        cur.close(); conn.close()
        return jsonify(data)
    except mysql.connector.Error as e:
        return db_error(e)


# ---------- events -----------------------------------------------------------

@app.route("/api/events")
def list_events():
    city = request.args.get("city", "").strip()
    category = request.args.get("category", "").strip()
    q = request.args.get("q", "").strip()
    upcoming_only = request.args.get("upcoming", "1") == "1"

    sql = [
        "SELECT e.event_id, e.title, e.event_date, e.start_time, e.duration,",
        "       e.age_limit, e.seats_available, e.price, e.description,",
        "       e.category_id, c.category_name,",
        "       e.location_id, l.venue_name, l.city, l.state, l.locality, l.pin_code,",
        "       e.host_id, h.host_name,",
        "       fn_seats_remaining(e.event_id) AS seats_remaining",
        "FROM Event e",
        "JOIN Event_Category c ON c.category_id = e.category_id",
        "JOIN Location       l ON l.location_id = e.location_id",
        "JOIN Host           h ON h.host_id     = e.host_id",
        "WHERE 1=1",
    ]
    params: list = []
    if upcoming_only:
        sql.append("  AND e.event_date >= CURRENT_DATE")
    if city:
        sql.append("  AND l.city = %s"); params.append(city)
    if category:
        sql.append("  AND c.category_id = %s"); params.append(int(category))
    if q:
        sql.append(
            "  AND (e.title LIKE %s OR e.description LIKE %s "
            "   OR l.venue_name LIKE %s OR l.city LIKE %s)"
        )
        like = f"%{q}%"
        params.extend([like, like, like, like])
    sql.append("ORDER BY e.event_date ASC, e.start_time ASC")

    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("\n".join(sql), params)
        data = rows_to_json([c[0] for c in cur.description], cur.fetchall())
        cur.close(); conn.close()
        return jsonify(data)
    except mysql.connector.Error as e:
        return db_error(e)


@app.route("/api/events/<int:event_id>")
def get_event(event_id: int):
    try:
        conn = get_conn()
        cur = conn.cursor()

        cur.execute(
            """
            SELECT e.event_id, e.title, e.event_date, e.start_time, e.duration,
                   e.age_limit, e.seats_available, e.price, e.description,
                   c.category_id, c.category_name,
                   l.location_id, l.venue_name, l.city, l.state, l.locality, l.pin_code,
                   h.host_id, h.host_name, h.contact_email,
                   fn_seats_remaining(e.event_id) AS seats_remaining,
                   (SELECT ROUND(AVG(rating),2) FROM Review WHERE event_id = e.event_id) AS avg_rating,
                   (SELECT COUNT(*) FROM Review WHERE event_id = e.event_id) AS review_count
            FROM Event e
            JOIN Event_Category c ON c.category_id = e.category_id
            JOIN Location       l ON l.location_id = e.location_id
            JOIN Host           h ON h.host_id     = e.host_id
            WHERE e.event_id = %s
            """,
            (event_id,),
        )
        row = cur.fetchone()
        if not row:
            cur.close(); conn.close()
            return jsonify({"error": "Event not found"}), 404
        event = rows_to_json([c[0] for c in cur.description], [row])[0]

        cur.execute(
            """
            SELECT p.performer_id, p.name, p.performer_type, ep.performance_order
            FROM Event_Performer ep
            JOIN Performer p ON p.performer_id = ep.performer_id
            WHERE ep.event_id = %s
            ORDER BY ep.performance_order
            """,
            (event_id,),
        )
        event["performers"] = rows_to_json(
            [c[0] for c in cur.description], cur.fetchall()
        )

        cur.execute(
            """
            SELECT r.review_id, u.name AS reviewer, r.rating, r.comment, r.review_date
            FROM Review r
            JOIN User u ON u.user_id = r.user_id
            WHERE r.event_id = %s
            ORDER BY r.review_date DESC, r.review_id DESC
            """,
            (event_id,),
        )
        event["reviews"] = rows_to_json(
            [c[0] for c in cur.description], cur.fetchall()
        )

        cur.close(); conn.close()
        return jsonify(event)
    except mysql.connector.Error as e:
        return db_error(e)


# ---------- booking ----------------------------------------------------------

@app.route("/api/bookings", methods=["POST"])
def create_booking():
    payload = request.get_json(silent=True) or {}
    try:
        event_id = int(payload.get("event_id"))
        num_people = int(payload.get("num_people", 1))
        payment_method = str(payload.get("payment_method") or "UPI")
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid payload."}), 400

    if num_people < 1:
        return jsonify({"error": "num_people must be at least 1."}), 400
    if payment_method not in {"UPI", "credit_card", "debit_card", "net_banking", "wallet"}:
        return jsonify({"error": "Invalid payment method."}), 400

    offer_code = (payload.get("offer_code") or "").strip() or None
    user_id = int(payload.get("user_id") or DEMO_USER_ID)

    # Transaction policy for /api/bookings:
    #   Caller-managed (this handler) - sp_book_event acquires an X-lock
    #   on the Event row via FOR UPDATE; that lock is held until the
    #   COMMIT below, so the seat-check + Booking insert + Transaction
    #   insert + offer application all happen atomically. Any error
    #   between the START TRANSACTION and COMMIT triggers a ROLLBACK
    #   that releases the lock and undoes every write.
    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()

        cur.execute("START TRANSACTION")

        cur.callproc("sp_book_event", [user_id, event_id, num_people, payment_method])
        new_booking_id = None
        amount_charged = None
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                new_booking_id = int(row[0])
                amount_charged = float(row[1])
        if new_booking_id is None:
            raise RuntimeError("sp_book_event returned no booking id")

        # Offer application is delegated to sp_apply_offer_to_booking, which
        # uses fn_apply_discount internally. The procedure is caller-managed
        # so it composes with the outer transaction we opened above. Bad or
        # inactive offer codes are quietly passed through (final_amount =
        # original amount, discount = 0); the procedure only SIGNALs for
        # genuine bugs (missing booking_id). This is ablation #5 in action:
        # one callproc instead of nine lines of duplicated discount math.
        discount = 0.0
        applied_code = None
        if offer_code:
            cur.callproc("sp_apply_offer_to_booking", [new_booking_id, offer_code])
            for result in cur.stored_results():
                row = result.fetchone()
                if row:
                    amount_charged = float(row[0])
                    discount = float(row[1])
                    applied_code = row[2]

        cur.execute("COMMIT")
        cur.close(); conn.close()

        return jsonify(
            {
                "booking_id": new_booking_id,
                "amount_charged": amount_charged,
                "discount": discount,
                "offer_code": applied_code,
                "payment_method": payment_method,
                "num_people": num_people,
            }
        )
    except mysql.connector.Error as e:
        if conn:
            try: conn.rollback()
            except Exception: pass
            try: conn.close()
            except Exception: pass
        return db_error(e)


# ---------- custom queries ---------------------------------------------------

@app.route("/api/presets")
def list_presets():
    # Resolve each manifest entry to {id, label, group, sql} by reading
    # the referenced block from its .sql file. The SQL is stored exactly
    # once on disk; this endpoint is the only place it is materialised
    # for the frontend.
    out = []
    for p in PRESETS:
        try:
            sql = load_block(p["source"], p["id"])
        except (KeyError, FileNotFoundError) as e:
            sql = f"-- ERROR: {e}"
        out.append({"id": p["id"], "label": p["label"], "group": p["group"], "sql": sql})
    return jsonify(out)


@app.route("/api/query", methods=["POST"])
def run_query():
    payload = request.get_json(silent=True) or {}
    sql = payload.get("sql", "")

    ok, cleaned, err = validate_readonly(sql)
    if not ok:
        return jsonify({"error": err}), 400

    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SET SESSION TRANSACTION READ ONLY")
        cur.execute("START TRANSACTION")
        start = time.perf_counter()
        cur.execute(cleaned)
        rows = cur.fetchall() if cur.description else []
        elapsed_ms = round((time.perf_counter() - start) * 1000, 2)
        columns = [c[0] for c in cur.description] if cur.description else []
        data = rows_to_json(columns, rows)
        cur.execute("ROLLBACK")
        cur.execute("SET SESSION TRANSACTION READ WRITE")
        cur.close(); conn.close()

        return jsonify(
            {
                "columns": columns,
                "rows": data,
                "row_count": len(data),
                "elapsed_ms": elapsed_ms,
            }
        )
    except mysql.connector.Error as e:
        if conn:
            try: conn.close()
            except Exception: pass
        return db_error(e)


# ---------- admin (unrestricted SQL) -----------------------------------------

@app.route("/api/admin/query", methods=["POST"])
def run_admin_query():
    payload = request.get_json(silent=True) or {}
    sql = (payload.get("sql") or "").strip().rstrip(";").strip()
    if not sql:
        return jsonify({"error": "Query is empty."}), 400

    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()
        start = time.perf_counter()
        cur.execute(sql)
        elapsed_ms = round((time.perf_counter() - start) * 1000, 2)

        if cur.description:
            columns = [c[0] for c in cur.description]
            rows = cur.fetchall()
            data = rows_to_json(columns, rows)
            conn.commit()
            cur.close(); conn.close()
            return jsonify(
                {
                    "columns": columns,
                    "rows": data,
                    "row_count": len(data),
                    "affected_rows": None,
                    "elapsed_ms": elapsed_ms,
                }
            )

        affected = cur.rowcount
        conn.commit()
        cur.close(); conn.close()
        return jsonify(
            {
                "columns": [],
                "rows": [],
                "row_count": 0,
                "affected_rows": affected,
                "elapsed_ms": elapsed_ms,
            }
        )
    except mysql.connector.Error as e:
        if conn:
            try: conn.rollback()
            except Exception: pass
            try: conn.close()
            except Exception: pass
        return db_error(e)


# ---------- main -------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="127.0.0.1", port=port, debug=True)
