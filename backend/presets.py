"""
Manifest of SQL playground presets.

Each preset references a block in a .sql file under database/ by id. The
SQL itself is NOT stored here - it lives in the .sql files (queries.sql,
playground.sql, etc.) and is loaded on demand by the Flask /api/presets
endpoint via load_block() in app.py.

This avoids the duplication that existed previously (SQL strings in
presets.py mirroring queries.sql, drifting independently). Now there is
exactly one source of truth for every preset query.

Block format inside the .sql files:
    -- @id <unique_id>
    -- <description (optional, shown as-is in the playground)>
    SELECT ...;
"""

PRESETS = [
    # ---- raw tables -----------------------------------------------------
    {"id": "all_events",   "label": "All events (raw table)", "group": "Tables", "source": "playground.sql"},
    {"id": "all_users",    "label": "All users",              "group": "Tables", "source": "playground.sql"},
    {"id": "all_bookings", "label": "All bookings",           "group": "Tables", "source": "playground.sql"},

    # ---- views ----------------------------------------------------------
    {"id": "vw_event_dashboard", "label": "View: event dashboard", "group": "Views", "source": "playground.sql"},
    {"id": "vw_booking_summary", "label": "View: booking summary", "group": "Views", "source": "playground.sql"},
    {"id": "vw_event_lineup",    "label": "View: event lineup",    "group": "Views", "source": "playground.sql"},

    # ---- joins ----------------------------------------------------------
    {"id": "q1_inner_join", "label": "Q1 - INNER JOIN (bookings + user + venue)", "group": "Joins", "source": "queries.sql"},
    {"id": "q2_left_join",  "label": "Q2 - LEFT JOIN (events + reviews)",         "group": "Joins", "source": "queries.sql"},
    {"id": "q5_self_join",  "label": "Q5 - SELF JOIN (users in same city)",       "group": "Joins", "source": "queries.sql"},

    # ---- grouping -------------------------------------------------------
    {"id": "q6_revenue_per_event", "label": "Q6 - GROUP BY/HAVING (revenue per event)", "group": "Grouping", "source": "queries.sql"},
    {"id": "q7_avg_rating",        "label": "Q7 - GROUP BY (avg rating per event)",     "group": "Grouping", "source": "queries.sql"},
    {"id": "q8_payment_methods",   "label": "Q8 - GROUP BY (payment methods)",          "group": "Grouping", "source": "queries.sql"},

    # ---- subqueries -----------------------------------------------------
    {"id": "q10_above_avg",     "label": "Q10 - Subquery (events above avg price)",    "group": "Subqueries", "source": "queries.sql"},
    {"id": "q11_multi_bookers", "label": "Q11 - IN subquery (multi-event users)",       "group": "Subqueries", "source": "queries.sql"},
    {"id": "q12_correlated",    "label": "Q12 - Correlated subquery (top per event)",   "group": "Subqueries", "source": "queries.sql"},

    # ---- functions / aggregates ----------------------------------------
    {"id": "q13_aggregates",     "label": "Q13 - Aggregates on Event",        "group": "Functions", "source": "queries.sql"},
    {"id": "q14_scalar",         "label": "Q14 - Scalar string/date fns",     "group": "Functions", "source": "queries.sql"},
    {"id": "fn_seats_remaining", "label": "UDF - fn_seats_remaining per event","group": "Functions", "source": "playground.sql"},
    {"id": "fn_apply_discount",  "label": "UDF - fn_apply_discount sample",   "group": "Functions", "source": "playground.sql"},

    # ---- metadata -------------------------------------------------------
    {"id": "describe_event", "label": "DESCRIBE Event",       "group": "Metadata", "source": "playground.sql"},
    {"id": "show_tables",    "label": "SHOW TABLES",          "group": "Metadata", "source": "playground.sql"},
    {"id": "explain_plan",   "label": "EXPLAIN (revenue query)", "group": "Metadata", "source": "playground.sql"},
]
