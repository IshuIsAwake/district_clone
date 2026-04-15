PRESETS = [
    {
        "id": "all_events",
        "label": "All events (raw table)",
        "group": "Tables",
        "sql": "SELECT * FROM Event ORDER BY event_date;",
    },
    {
        "id": "all_users",
        "label": "All users",
        "group": "Tables",
        "sql": "SELECT user_id, name, email, city, occupation FROM User ORDER BY user_id;",
    },
    {
        "id": "all_bookings",
        "label": "All bookings",
        "group": "Tables",
        "sql": "SELECT * FROM Booking ORDER BY booking_id;",
    },
    {
        "id": "vw_event_dashboard",
        "label": "View: event dashboard",
        "group": "Views",
        "sql": "SELECT * FROM vw_event_dashboard ORDER BY event_date;",
    },
    {
        "id": "vw_booking_summary",
        "label": "View: booking summary",
        "group": "Views",
        "sql": "SELECT * FROM vw_booking_summary ORDER BY booking_id;",
    },
    {
        "id": "vw_event_lineup",
        "label": "View: event lineup",
        "group": "Views",
        "sql": "SELECT * FROM vw_event_lineup;",
    },
    {
        "id": "q1_inner_join",
        "label": "Q1 — INNER JOIN (bookings + user + venue)",
        "group": "Joins",
        "sql": (
            "SELECT b.booking_id, u.name AS customer, e.title AS event_title,\n"
            "       l.venue_name, l.city, b.number_of_people, b.total_price\n"
            "FROM Booking b\n"
            "INNER JOIN User     u ON u.user_id     = b.user_id\n"
            "INNER JOIN Event    e ON e.event_id    = b.event_id\n"
            "INNER JOIN Location l ON l.location_id = e.location_id\n"
            "WHERE b.status = 'confirmed'\n"
            "ORDER BY b.booking_id;"
        ),
    },
    {
        "id": "q2_left_join",
        "label": "Q2 — LEFT JOIN (events + reviews)",
        "group": "Joins",
        "sql": (
            "SELECT e.event_id, e.title, u.name AS reviewer, r.rating, r.comment\n"
            "FROM Event e\n"
            "LEFT JOIN Review r ON r.event_id = e.event_id\n"
            "LEFT JOIN User   u ON u.user_id  = r.user_id\n"
            "ORDER BY e.event_id, r.review_id;"
        ),
    },
    {
        "id": "q5_self_join",
        "label": "Q5 — SELF JOIN (users in same city)",
        "group": "Joins",
        "sql": (
            "SELECT a.name AS user_a, b.name AS user_b, a.city\n"
            "FROM User a\n"
            "JOIN User b ON a.city = b.city AND a.user_id < b.user_id\n"
            "ORDER BY a.city, a.name;"
        ),
    },
    {
        "id": "q6_revenue_per_event",
        "label": "Q6 — GROUP BY/HAVING (revenue per event)",
        "group": "Grouping",
        "sql": (
            "SELECT e.event_id, e.title,\n"
            "       SUM(b.total_price) AS revenue,\n"
            "       COUNT(*)           AS confirmed_bookings\n"
            "FROM Event e\n"
            "JOIN Booking b ON b.event_id = e.event_id\n"
            "WHERE b.status = 'confirmed'\n"
            "GROUP BY e.event_id, e.title\n"
            "HAVING SUM(b.total_price) > 2000\n"
            "ORDER BY revenue DESC;"
        ),
    },
    {
        "id": "q7_avg_rating",
        "label": "Q7 — GROUP BY (avg rating per event)",
        "group": "Grouping",
        "sql": (
            "SELECT e.event_id, e.title,\n"
            "       ROUND(AVG(r.rating), 2) AS avg_rating,\n"
            "       COUNT(r.review_id)      AS review_count\n"
            "FROM Event e\n"
            "JOIN Review r ON r.event_id = e.event_id\n"
            "GROUP BY e.event_id, e.title\n"
            "ORDER BY avg_rating DESC;"
        ),
    },
    {
        "id": "q8_payment_methods",
        "label": "Q8 — GROUP BY (payment methods)",
        "group": "Grouping",
        "sql": (
            "SELECT t.payment_method,\n"
            "       COUNT(*)      AS txn_count,\n"
            "       SUM(t.amount) AS total_collected\n"
            "FROM Transaction t\n"
            "GROUP BY t.payment_method\n"
            "ORDER BY txn_count DESC;"
        ),
    },
    {
        "id": "q10_above_avg",
        "label": "Q10 — Subquery (events above avg price)",
        "group": "Subqueries",
        "sql": (
            "SELECT event_id, title, price\n"
            "FROM Event\n"
            "WHERE price > (SELECT AVG(price) FROM Event)\n"
            "ORDER BY price DESC;"
        ),
    },
    {
        "id": "q11_multi_bookers",
        "label": "Q11 — IN subquery (multi-event users)",
        "group": "Subqueries",
        "sql": (
            "SELECT user_id, name, email\n"
            "FROM User\n"
            "WHERE user_id IN (\n"
            "    SELECT user_id FROM Booking\n"
            "    WHERE status = 'confirmed'\n"
            "    GROUP BY user_id\n"
            "    HAVING COUNT(DISTINCT event_id) > 1\n"
            ");"
        ),
    },
    {
        "id": "q12_correlated",
        "label": "Q12 — Correlated subquery (top booking per event)",
        "group": "Subqueries",
        "sql": (
            "SELECT b.booking_id, b.event_id, b.user_id, b.total_price\n"
            "FROM Booking b\n"
            "WHERE b.status = 'confirmed'\n"
            "  AND b.total_price = (\n"
            "      SELECT MAX(b2.total_price) FROM Booking b2\n"
            "      WHERE b2.event_id = b.event_id AND b2.status = 'confirmed'\n"
            "  )\n"
            "ORDER BY b.event_id;"
        ),
    },
    {
        "id": "q13_aggregates",
        "label": "Q13 — Aggregates on Event",
        "group": "Functions",
        "sql": (
            "SELECT COUNT(*)             AS total_events,\n"
            "       MIN(price)           AS cheapest,\n"
            "       MAX(price)           AS priciest,\n"
            "       ROUND(AVG(price), 2) AS avg_price,\n"
            "       SUM(seats_available) AS total_seats_left\n"
            "FROM Event;"
        ),
    },
    {
        "id": "q14_scalar",
        "label": "Q14 — Scalar string/date fns on User",
        "group": "Functions",
        "sql": (
            "SELECT user_id,\n"
            "       UPPER(name)                              AS name_upper,\n"
            "       LENGTH(email)                            AS email_length,\n"
            "       CONCAT(name, ' - ', city)                AS tag,\n"
            "       FLOOR(DATEDIFF(CURRENT_DATE, dob) / 365) AS age_years,\n"
            "       COALESCE(anniversary_date, 'n/a')        AS anniv\n"
            "FROM User\n"
            "ORDER BY user_id;"
        ),
    },
    {
        "id": "fn_seats_remaining",
        "label": "UDF — fn_seats_remaining per event",
        "group": "Functions",
        "sql": (
            "SELECT e.event_id, e.title,\n"
            "       e.seats_available          AS stored_seats,\n"
            "       fn_seats_remaining(e.event_id) AS computed_seats\n"
            "FROM Event e\n"
            "ORDER BY e.event_id;"
        ),
    },
    {
        "id": "fn_apply_discount",
        "label": "UDF — fn_apply_discount sample",
        "group": "Functions",
        "sql": (
            "SELECT code, type, discount_value,\n"
            "       fn_apply_discount(1000, code) AS on_1000,\n"
            "       fn_apply_discount(5000, code) AS on_5000\n"
            "FROM Offer\n"
            "WHERE is_active = TRUE;"
        ),
    },
    {
        "id": "describe_event",
        "label": "DESCRIBE Event",
        "group": "Metadata",
        "sql": "DESCRIBE Event;",
    },
    {
        "id": "show_tables",
        "label": "SHOW TABLES",
        "group": "Metadata",
        "sql": "SHOW TABLES;",
    },
    {
        "id": "explain_plan",
        "label": "EXPLAIN (revenue query)",
        "group": "Metadata",
        "sql": (
            "EXPLAIN SELECT e.event_id, e.title, SUM(b.total_price) AS revenue\n"
            "FROM Event e JOIN Booking b ON b.event_id = e.event_id\n"
            "WHERE b.status = 'confirmed'\n"
            "GROUP BY e.event_id, e.title;"
        ),
    },
]
