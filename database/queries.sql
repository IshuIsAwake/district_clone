-- ============================================================================
-- queries.sql - DQL showcase (the rubric "Joins / Group By / Subqueries /
--              Aggregate + Scalar Functions" section).
-- ============================================================================
-- Each query block is delimited by an "-- @id <name>" marker so:
--   1. run_all.py can run them in order with labelled headers, and
--   2. backend/presets.py can reference them by id and let the Flask
--      /api/presets endpoint load the SQL on demand. Single source of
--      truth - the SQL lives here, not duplicated as Python strings.
--
-- Block convention:
--     -- @id <unique_id>
--     -- <human-readable description>
--     SELECT ...;
-- A block runs from one "@id" line to the next.
-- ============================================================================

USE zomato_district;

-- ============================================================================
-- DML (UPDATE / DELETE) - rubric DML coverage
-- ============================================================================

-- @id q0a_update_cancel
-- UPDATE: cancel booking 8 (idempotent - already cancelled in seed).
UPDATE Booking SET status = 'cancelled' WHERE booking_id = 8;

-- @id q0b_delete_saved
-- DELETE + INSERT: remove a saved item, then restore it so the rest of
-- the report stays consistent across reruns.
DELETE FROM Saved_Item WHERE user_id = 1 AND event_id = 2;
INSERT IGNORE INTO Saved_Item (user_id, event_id, saved_date)
VALUES (1, 2, '2026-03-28');

-- ============================================================================
-- JOINS
-- ============================================================================

-- @id q1_inner_join
-- INNER JOIN: confirmed bookings with user name, event title and venue.
-- Bookings without a matching user/event/location row are dropped (the
-- whole point of INNER) - here that is the right behaviour because every
-- booking MUST have all three FKs set.
SELECT b.booking_id,
       u.name            AS customer,
       e.title           AS event_title,
       l.venue_name,
       l.city,
       b.number_of_people,
       b.total_price
FROM Booking b
INNER JOIN User     u ON u.user_id     = b.user_id
INNER JOIN Event    e ON e.event_id    = b.event_id
INNER JOIN Location l ON l.location_id = e.location_id
WHERE b.status = 'confirmed'
ORDER BY b.booking_id;

-- @id q2_left_join
-- LEFT JOIN: every event with its reviews, including events that have
-- never been reviewed. Switching to INNER JOIN here would silently
-- remove unreviewed events from the listing - common bug.
SELECT e.event_id,
       e.title,
       u.name     AS reviewer,
       r.rating,
       r.comment
FROM Event e
LEFT JOIN Review r ON r.event_id = e.event_id
LEFT JOIN User   u ON u.user_id  = r.user_id
ORDER BY e.event_id, r.review_id;

-- @id q3_right_join
-- RIGHT JOIN: every transaction alongside its booking. Functionally
-- equivalent to swapping table order with LEFT JOIN; included to
-- demonstrate the syntax for the rubric.
SELECT t.transaction_id,
       t.payment_method,
       t.amount,
       t.payment_status,
       b.booking_id,
       b.status   AS booking_status
FROM Booking b
RIGHT JOIN Transaction t ON t.booking_id = b.booking_id
ORDER BY t.transaction_id;

-- @id q4_full_outer_join
-- FULL OUTER JOIN (emulated via UNION of LEFT and RIGHT - MySQL does not
-- support FULL OUTER natively). Covers users who never booked AND
-- (hypothetically) bookings whose user row vanished. UNION (not UNION ALL)
-- de-duplicates the rows that match both sides.
SELECT u.user_id, u.name, b.booking_id, b.total_price
FROM User u
LEFT JOIN Booking b ON b.user_id = u.user_id
UNION
SELECT u.user_id, u.name, b.booking_id, b.total_price
FROM User u
RIGHT JOIN Booking b ON b.user_id = u.user_id
ORDER BY user_id, booking_id;

-- @id q5_self_join
-- SELF JOIN: pairs of users who live in the same city. The
-- a.user_id < b.user_id predicate avoids both (X, X) self-pairs and
-- (X, Y)+(Y, X) duplicates - a common SELF JOIN pitfall.
SELECT a.name AS user_a,
       b.name AS user_b,
       a.city
FROM User a
JOIN User b ON a.city = b.city AND a.user_id < b.user_id
ORDER BY a.city, a.name;

-- ============================================================================
-- GROUP BY / HAVING / ORDER BY
-- ============================================================================

-- @id q6_revenue_per_event
-- Revenue per event from confirmed bookings, filtered to events with
-- revenue > 2000. WHERE filters rows BEFORE grouping; HAVING filters
-- groups AFTER aggregation - that distinction is a frequent viva
-- question.
SELECT e.event_id,
       e.title,
       SUM(b.total_price) AS revenue,
       COUNT(*)           AS confirmed_bookings
FROM Event e
JOIN Booking b ON b.event_id = e.event_id
WHERE b.status = 'confirmed'
GROUP BY e.event_id, e.title
HAVING SUM(b.total_price) > 2000
ORDER BY revenue DESC;

-- @id q7_avg_rating
-- Average rating + review count per reviewed event. Single-pass
-- aggregation; compare with ablation #3 which contrasts this against
-- a per-row correlated subquery.
SELECT e.event_id,
       e.title,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       COUNT(r.review_id)      AS review_count
FROM Event e
JOIN Review r ON r.event_id = e.event_id
GROUP BY e.event_id, e.title
ORDER BY avg_rating DESC;

-- @id q8_payment_methods
-- Booking count and total collected by payment method.
SELECT t.payment_method,
       COUNT(*)        AS txn_count,
       SUM(t.amount)   AS total_collected
FROM Transaction t
GROUP BY t.payment_method
ORDER BY txn_count DESC;

-- @id q9_upcoming_by_price
-- Upcoming events sorted by price (descending), then date (ascending).
-- Demonstrates ORDER BY with two keys in different directions.
SELECT event_id, title, event_date, price
FROM Event
WHERE event_date >= CURRENT_DATE
ORDER BY price DESC, event_date ASC;

-- ============================================================================
-- SUBQUERIES
-- ============================================================================

-- @id q10_above_avg
-- Simple (non-correlated) scalar subquery: the inner SELECT is computed
-- once and treated as a constant by the outer WHERE. Cheap.
SELECT event_id, title, price
FROM Event
WHERE price > (SELECT AVG(price) FROM Event)
ORDER BY price DESC;

-- @id q11_multi_bookers
-- IN subquery: users who have confirmed bookings on more than one
-- distinct event. The outer query references nothing inside the inner -
-- the subquery is evaluated once and its result acts as a value list.
SELECT user_id, name, email
FROM User
WHERE user_id IN (
    SELECT user_id
    FROM Booking
    WHERE status = 'confirmed'
    GROUP BY user_id
    HAVING COUNT(DISTINCT event_id) > 1
);

-- @id q12_correlated
-- Correlated subquery: the inner SELECT depends on the outer row
-- (b.event_id flows in). Logically re-evaluated per outer row, though
-- the optimizer often rewrites it. Compare with ablation #4 where this
-- pattern is replaced with a JOIN+GROUP BY.
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
WHERE b.status = 'confirmed'
  AND b.total_price = (
      SELECT MAX(b2.total_price)
      FROM Booking b2
      WHERE b2.event_id = b.event_id
        AND b2.status   = 'confirmed'
  )
ORDER BY b.event_id;

-- ============================================================================
-- AGGREGATE + SCALAR FUNCTIONS
-- ============================================================================

-- @id q13_aggregates
-- Aggregates on Event - COUNT, MIN, MAX, AVG, SUM. The SUM(seats_available)
-- shows total capacity (seats_available is the immutable initial capacity;
-- live availability comes from fn_seats_remaining).
SELECT COUNT(*)             AS total_events,
       MIN(price)            AS cheapest,
       MAX(price)            AS priciest,
       ROUND(AVG(price), 2)  AS avg_price,
       SUM(seats_available)  AS total_capacity
FROM Event;

-- @id q14_scalar
-- Scalar string + date functions on User.
-- DATEDIFF / 365 is a rough age - good enough for a demo, not for
-- production (ignores leap years).
SELECT user_id,
       UPPER(name)                              AS name_upper,
       LENGTH(email)                            AS email_length,
       CONCAT(name, ' - ', city)                AS tag,
       FLOOR(DATEDIFF(CURRENT_DATE, dob) / 365) AS age_years,
       COALESCE(anniversary_date, 'n/a')        AS anniv
FROM User
ORDER BY user_id;
