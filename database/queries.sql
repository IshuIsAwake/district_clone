-- Zomato District clone - DQL showcase
-- Each query block is labelled so run_all.py can execute them individually
-- and the report / viva has a one-to-one mapping to the rubric checklist.
USE zomato_district;

-- ============================================================
-- DML EXAMPLES (update + delete)
-- ============================================================

-- Q0a. UPDATE: cancel booking 8 (demonstration DML)
-- (already cancelled in seed — this statement is idempotent)
UPDATE Booking SET status = 'cancelled' WHERE booking_id = 8;

-- Q0b. DELETE: remove a saved item
DELETE FROM Saved_Item WHERE user_id = 1 AND event_id = 2;
-- restore it so the rest of the report stays consistent
INSERT IGNORE INTO Saved_Item (user_id, event_id, saved_date)
VALUES (1, 2, '2026-03-28');

-- ============================================================
-- JOINS
-- ============================================================

-- Q1. INNER JOIN: confirmed bookings with user name, event title and venue.
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

-- Q2. LEFT JOIN: all events with reviews (including events that have no reviews).
SELECT e.event_id,
       e.title,
       u.name     AS reviewer,
       r.rating,
       r.comment
FROM Event e
LEFT JOIN Review r ON r.event_id = e.event_id
LEFT JOIN User   u ON u.user_id  = r.user_id
ORDER BY e.event_id, r.review_id;

-- Q3. RIGHT JOIN: all transactions alongside their booking details.
SELECT t.transaction_id,
       t.payment_method,
       t.amount,
       t.payment_status,
       b.booking_id,
       b.status   AS booking_status
FROM Booking b
RIGHT JOIN Transaction t ON t.booking_id = b.booking_id
ORDER BY t.transaction_id;

-- Q4. FULL OUTER JOIN (emulated via UNION): every user and every booking,
-- including users who never booked and (hypothetically) bookings with no user.
SELECT u.user_id, u.name, b.booking_id, b.total_price
FROM User u
LEFT JOIN Booking b ON b.user_id = u.user_id
UNION
SELECT u.user_id, u.name, b.booking_id, b.total_price
FROM User u
RIGHT JOIN Booking b ON b.user_id = u.user_id
ORDER BY user_id, booking_id;

-- Q5. SELF JOIN: pairs of users who live in the same city.
SELECT a.name AS user_a,
       b.name AS user_b,
       a.city
FROM User a
JOIN User b ON a.city = b.city AND a.user_id < b.user_id
ORDER BY a.city, a.name;

-- ============================================================
-- GROUP BY / HAVING / ORDER BY
-- ============================================================

-- Q6. Revenue per event (only confirmed bookings) where revenue > 2000.
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

-- Q7. Average rating and review count per reviewed event.
SELECT e.event_id,
       e.title,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       COUNT(r.review_id)      AS review_count
FROM Event e
JOIN Review r ON r.event_id = e.event_id
GROUP BY e.event_id, e.title
ORDER BY avg_rating DESC;

-- Q8. Booking count by payment method.
SELECT t.payment_method,
       COUNT(*)        AS txn_count,
       SUM(t.amount)   AS total_collected
FROM Transaction t
GROUP BY t.payment_method
ORDER BY txn_count DESC;

-- Q9. Upcoming events sorted by price (ORDER BY demo).
SELECT event_id, title, event_date, price
FROM Event
WHERE event_date >= CURRENT_DATE
ORDER BY price DESC, event_date ASC;

-- ============================================================
-- SUBQUERIES
-- ============================================================

-- Q10. Simple subquery: events priced strictly above the average event price.
SELECT event_id, title, price
FROM Event
WHERE price > (SELECT AVG(price) FROM Event)
ORDER BY price DESC;

-- Q11. IN subquery: users who booked more than one distinct event.
SELECT user_id, name, email
FROM User
WHERE user_id IN (
    SELECT user_id
    FROM Booking
    WHERE status = 'confirmed'
    GROUP BY user_id
    HAVING COUNT(DISTINCT event_id) > 1
);

-- Q12. Correlated subquery: highest-value confirmed booking per event.
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

-- ============================================================
-- AGGREGATE + SCALAR FUNCTIONS
-- ============================================================

-- Q13. Aggregates on Event / Booking.
SELECT COUNT(*)       AS total_events,
       MIN(price)     AS cheapest,
       MAX(price)     AS priciest,
       ROUND(AVG(price), 2) AS avg_price,
       SUM(seats_available) AS total_seats_left
FROM Event;

-- Q14. Scalar string + date functions on User.
SELECT user_id,
       UPPER(name)                         AS name_upper,
       LENGTH(email)                       AS email_length,
       CONCAT(name, ' - ', city)           AS tag,
       FLOOR(DATEDIFF(CURRENT_DATE, dob) / 365) AS age_years,
       COALESCE(anniversary_date, 'n/a')   AS anniv
FROM User
ORDER BY user_id;
