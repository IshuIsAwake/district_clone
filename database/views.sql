-- ============================================================================
-- views.sql - Stored views (virtual tables)
-- ============================================================================
-- A view is a named SELECT - the rows are not stored, they are recomputed
-- every time the view is queried. Views give us:
--   - a stable read interface decoupled from the underlying schema:
--     consumers query vw_event_dashboard without knowing which tables
--     contributed to it;
--   - one canonical aggregation: AVG(rating) per event lives in
--     vw_event_dashboard once, instead of being copy-pasted across the
--     app.py, run_all.py and presets.
--
-- Trade-off vs materialised: MySQL CREATE VIEW is always virtual (no
-- materialisation). Every read pays the JOIN cost. For this dataset
-- (handfuls of rows) that is free; on a real workload one would either
-- (a) keep the JOINs and rely on indexes, or (b) maintain a denormalised
-- summary table updated by triggers. We chose (a) because the dataset is
-- small and the report wants normalisation, not denormalisation.
--
-- Statements separated by '-- ===SQL_SPLIT===' so run_all.py can feed each
-- DROP/CREATE pair to cursor.execute() individually.
-- ============================================================================

USE zomato_district
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- vw_event_dashboard - the "event card" projection.
--
-- One row per event with everything a list/grid card needs: title, when,
-- where, who hosts, price, live seat count, average rating, review count.
-- Replaces what would otherwise be a 5-table JOIN repeated in every
-- consumer that lists events.
--
-- Where used:
--   - Playground preset "View: event dashboard".
--   - run_all.py demo section.
--   - NOT yet used by the Flask /api/events handler (which inlines the
--     joins). That is itself an ablation candidate (#3) - "view vs
--     inline JOIN" comparison.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_event_dashboard
-- ===SQL_SPLIT===
CREATE VIEW vw_event_dashboard AS
SELECT e.event_id,
       e.title,
       e.event_date,
       e.start_time,
       e.price,
       e.seats_available,
       c.category_name,
       l.venue_name,
       l.city,
       h.host_name,
       COALESCE(ROUND(AVG(r.rating), 2), 0) AS avg_rating,
       COUNT(r.review_id)                   AS review_count
FROM Event e
JOIN Event_Category c ON c.category_id = e.category_id
JOIN Location       l ON l.location_id = e.location_id
JOIN Host           h ON h.host_id     = e.host_id
LEFT JOIN Review    r ON r.event_id    = e.event_id
GROUP BY e.event_id, e.title, e.event_date, e.start_time, e.price,
         e.seats_available, c.category_name, l.venue_name, l.city, h.host_name
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- vw_booking_summary - the "my bookings" projection.
--
-- One row per booking with the human-readable fields a user wants to see
-- (their event title, customer name, payment method, applied offer).
-- The LEFT JOINs on Transaction and Booking_Offer/Offer mean bookings
-- without a payment record or without an applied coupon still show up
-- (with NULL on the missing columns), which is what we want here -
-- INNER would drop them silently.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_booking_summary
-- ===SQL_SPLIT===
CREATE VIEW vw_booking_summary AS
SELECT b.booking_id,
       u.name           AS customer,
       e.title          AS event_title,
       e.event_date,
       b.number_of_people,
       b.total_price,
       b.status,
       t.payment_method,
       t.payment_status,
       o.code           AS offer_code,
       bo.discount_applied
FROM Booking b
JOIN User             u  ON u.user_id      = b.user_id
JOIN Event            e  ON e.event_id     = b.event_id
LEFT JOIN Transaction   t  ON t.booking_id = b.booking_id
LEFT JOIN Booking_Offer bo ON bo.booking_id = b.booking_id
LEFT JOIN Offer         o  ON o.offer_id    = bo.offer_id
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- vw_event_lineup - the "who is performing" projection.
--
-- One row per (event, performer) pair, ordered by performance_order.
-- INNER JOIN on Event_Performer is intentional - events with no
-- performers (e.g. a food festival) are absent here, which is correct
-- for a lineup view.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_event_lineup
-- ===SQL_SPLIT===
CREATE VIEW vw_event_lineup AS
SELECT e.event_id,
       e.title,
       p.name                 AS performer_name,
       p.performer_type,
       ep.performance_order
FROM Event           e
JOIN Event_Performer ep ON ep.event_id     = e.event_id
JOIN Performer       p  ON p.performer_id  = ep.performer_id
ORDER BY e.event_id, ep.performance_order
-- ===SQL_SPLIT===
