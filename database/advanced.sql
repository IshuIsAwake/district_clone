-- Zomato District clone - advanced SQL
-- Views, stored procedures, user-defined functions, TCL and DCL.
-- Statements are separated by an explicit marker so that run_all.py can
-- feed each statement individually to cursor.execute() - required because
-- CREATE PROCEDURE / FUNCTION bodies contain their own semicolons.

USE zomato_district;
-- ===SQL_SPLIT===

-- ============================================================
-- VIEWS
-- ============================================================

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
JOIN User        u  ON u.user_id     = b.user_id
JOIN Event       e  ON e.event_id    = b.event_id
LEFT JOIN Transaction   t  ON t.booking_id = b.booking_id
LEFT JOIN Booking_Offer bo ON bo.booking_id = b.booking_id
LEFT JOIN Offer         o  ON o.offer_id    = bo.offer_id
-- ===SQL_SPLIT===

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

-- ============================================================
-- USER-DEFINED FUNCTIONS
-- ============================================================

DROP FUNCTION IF EXISTS fn_seats_remaining
-- ===SQL_SPLIT===
CREATE FUNCTION fn_seats_remaining(p_event_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_initial INT;
    DECLARE v_booked  INT;
    SELECT seats_available INTO v_initial
    FROM Event WHERE event_id = p_event_id;
    SELECT COALESCE(SUM(number_of_people), 0) INTO v_booked
    FROM Booking
    WHERE event_id = p_event_id AND status = 'confirmed';
    RETURN v_initial - v_booked;
END
-- ===SQL_SPLIT===

DROP FUNCTION IF EXISTS fn_apply_discount
-- ===SQL_SPLIT===
CREATE FUNCTION fn_apply_discount(p_amount DECIMAL(10,2), p_offer_code VARCHAR(20))
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_type   VARCHAR(20);
    DECLARE v_value  DECIMAL(10,2);
    DECLARE v_final  DECIMAL(10,2);
    SELECT type, discount_value INTO v_type, v_value
    FROM Offer
    WHERE code = p_offer_code AND is_active = TRUE
    LIMIT 1;
    IF v_type IS NULL THEN
        RETURN p_amount;
    END IF;
    IF v_type = 'percentage' THEN
        SET v_final = p_amount - (p_amount * v_value / 100);
    ELSE
        SET v_final = p_amount - v_value;
    END IF;
    IF v_final < 0 THEN SET v_final = 0; END IF;
    RETURN v_final;
END
-- ===SQL_SPLIT===

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

DROP PROCEDURE IF EXISTS sp_book_event
-- ===SQL_SPLIT===
CREATE PROCEDURE sp_book_event(
    IN  p_user_id    INT,
    IN  p_event_id   INT,
    IN  p_num_people INT,
    IN  p_pay_method VARCHAR(30)
)
BEGIN
    DECLARE v_seats INT;
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_booking_id INT;

    SELECT seats_available, price
      INTO v_seats, v_price
    FROM Event WHERE event_id = p_event_id;

    IF v_seats IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Event not found';
    END IF;
    IF v_seats < p_num_people THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Not enough seats available';
    END IF;

    SET v_total = v_price * p_num_people;

    INSERT INTO Booking (user_id, event_id, number_of_people, total_price, status)
    VALUES (p_user_id, p_event_id, p_num_people, v_total, 'confirmed');

    SET v_booking_id = LAST_INSERT_ID();

    INSERT INTO Transaction (booking_id, payment_method, amount, payment_status)
    VALUES (v_booking_id, p_pay_method, v_total, 'completed');

    UPDATE Event
       SET seats_available = seats_available - p_num_people
     WHERE event_id = p_event_id;

    SELECT v_booking_id AS new_booking_id, v_total AS amount_charged;
END
-- ===SQL_SPLIT===

DROP PROCEDURE IF EXISTS sp_cancel_booking
-- ===SQL_SPLIT===
CREATE PROCEDURE sp_cancel_booking(IN p_booking_id INT)
BEGIN
    DECLARE v_event_id INT;
    DECLARE v_people   INT;
    DECLARE v_status   VARCHAR(20);

    SELECT event_id, number_of_people, status
      INTO v_event_id, v_people, v_status
    FROM Booking WHERE booking_id = p_booking_id;

    IF v_event_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found';
    END IF;
    IF v_status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking already cancelled';
    END IF;

    UPDATE Booking     SET status = 'cancelled' WHERE booking_id = p_booking_id;
    UPDATE Transaction SET payment_status = 'refunded' WHERE booking_id = p_booking_id;
    UPDATE Event
       SET seats_available = seats_available + v_people
     WHERE event_id = v_event_id;
END
-- ===SQL_SPLIT===

DROP PROCEDURE IF EXISTS sp_search_events
-- ===SQL_SPLIT===
CREATE PROCEDURE sp_search_events(
    IN p_city     VARCHAR(50),
    IN p_category VARCHAR(50)
)
BEGIN
    SELECT e.event_id,
           e.title,
           e.event_date,
           e.price,
           e.seats_available,
           l.venue_name,
           l.city,
           c.category_name
    FROM Event e
    JOIN Location       l ON l.location_id = e.location_id
    JOIN Event_Category c ON c.category_id = e.category_id
    WHERE (p_city     IS NULL OR p_city     = '' OR l.city          = p_city)
      AND (p_category IS NULL OR p_category = '' OR c.category_name = p_category)
      AND e.event_date >= CURRENT_DATE
    ORDER BY e.event_date;
END
-- ===SQL_SPLIT===
