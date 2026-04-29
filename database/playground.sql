-- ============================================================================
-- playground.sql - Preset queries for the SQL playground panel.
-- ============================================================================
-- These blocks are referenced by id from backend/presets.py and resolved
-- by the Flask /api/presets endpoint. They are NOT run by run_all.py
-- (which has its own showcase) - they exist to give the playground UI
-- one-click examples covering tables, views, functions, and metadata.
--
-- Block format identical to queries.sql:
--     -- @id <unique_id>
--     -- <human-readable description>
--     SELECT ...;
-- ============================================================================

USE zomato_district;

-- ============================================================================
-- RAW TABLE DUMPS (group: Tables)
-- ============================================================================

-- @id all_events
-- All events ordered by date.
SELECT * FROM Event ORDER BY event_date;

-- @id all_users
-- All users (selected columns).
SELECT user_id, name, email, city, occupation
FROM User
ORDER BY user_id;

-- @id all_bookings
-- All bookings ordered by id.
SELECT * FROM Booking ORDER BY booking_id;

-- ============================================================================
-- VIEW DEMOS (group: Views)
-- ============================================================================

-- @id vw_event_dashboard
-- The event-card projection - title, when, where, host, price, seats,
-- avg rating, review count - all in one row per event.
SELECT * FROM vw_event_dashboard ORDER BY event_date;

-- @id vw_booking_summary
-- The "my bookings" projection - booking + user + event + payment + offer.
SELECT * FROM vw_booking_summary ORDER BY booking_id;

-- @id vw_event_lineup
-- Who is performing at which event, in performance order.
SELECT * FROM vw_event_lineup;

-- ============================================================================
-- UDF DEMOS (group: Functions)
-- ============================================================================

-- @id fn_seats_remaining
-- Side-by-side: stored initial capacity vs the function-derived live
-- count. The gap is the number of confirmed bookings * party size.
SELECT e.event_id,
       e.title,
       e.seats_available             AS stored_seats,
       fn_seats_remaining(e.event_id) AS computed_seats
FROM Event e
ORDER BY e.event_id;

-- @id fn_apply_discount
-- Discount math demo: every active offer applied to a 1000 and a 5000
-- amount via the canonical UDF.
SELECT code, type, discount_value,
       fn_apply_discount(1000, code) AS on_1000,
       fn_apply_discount(5000, code) AS on_5000
FROM Offer
WHERE is_active = TRUE;

-- ============================================================================
-- METADATA (group: Metadata)
-- ============================================================================

-- @id describe_event
-- Column listing for the Event table.
DESCRIBE Event;

-- @id show_tables
-- Every base table and view in the database.
SHOW TABLES;

-- @id explain_plan
-- EXPLAIN the revenue-per-event query (q6) - shows the join order,
-- access type, and which indexes the planner picks.
EXPLAIN
SELECT e.event_id, e.title, SUM(b.total_price) AS revenue
FROM Event e
JOIN Booking b ON b.event_id = e.event_id
WHERE b.status = 'confirmed'
GROUP BY e.event_id, e.title;
