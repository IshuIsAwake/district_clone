-- ============================================================================
-- procedures.sql - Stored procedures
-- ============================================================================
-- A procedure is a named block of SQL invoked with CALL. Unlike a function
-- it can:
--   - run multi-table writes (INSERT/UPDATE/DELETE on different tables);
--   - return one or more result sets (via SELECTs without INTO);
--   - manage its own transaction with START TRANSACTION / COMMIT.
--
-- Each procedure below declares its TRANSACTION POLICY in the header:
--   - CALLER-MANAGED: the caller (Flask handler) opens and commits the
--     transaction; the procedure only acquires locks. Used when the
--     procedure is one step in a larger atomic flow.
--   - SELF-MANAGED: the procedure opens and commits its own transaction.
--     Used when the procedure is a complete unit of work, safe to call
--     from autocommit-on contexts (admin console, presets, run_all.py).
--   - NONE: read-only, no locks acquired, no transaction needed.
--
-- Lock concepts demonstrated across this file:
--   - Pessimistic / Exclusive (X) lock via SELECT ... FOR UPDATE
--   - Shared (S) lock via SELECT ... LOCK IN SHARE MODE (in ablations)
--   - Strict 2PL (S2PL): InnoDB's default - locks held until COMMIT
--   - Optimistic via Event.version (in ablation #1, optimistic tier)
-- ============================================================================

USE zomato_district
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- sp_book_event - the headline transactional procedure.
--
-- Concepts demonstrated:
--   - TCL: caller-managed transaction (see policy below).
--   - Pessimistic locking: SELECT ... FOR UPDATE acquires an EXCLUSIVE
--     (X) row lock on the Event row. Other transactions trying to book
--     the same event block until this one commits or rolls back.
--   - Strict 2PL (S2PL): InnoDB holds X-locks until COMMIT/ROLLBACK by
--     default - locks are NEVER released early. This is what makes the
--     "check seats then insert booking" sequence atomic.
--   - SIGNAL SQLSTATE '45000': how stored procedures raise errors that
--     surface to the caller as a SQL exception.
--   - Single canonical seat-count source: fn_seats_remaining is the only
--     place that derives "seats left" from the Booking table; sp_book_event
--     calls it instead of duplicating the SUM.
--
-- Transaction policy: CALLER-MANAGED.
--   This procedure does NOT issue START TRANSACTION or COMMIT. The caller
--   (Flask /api/bookings) opens a transaction, calls this procedure, may
--   issue further statements (apply offer, etc.), then commits. The
--   X-lock acquired by FOR UPDATE here is held until the CALLER commits,
--   so the entire booking flow - including the offer application that
--   happens after the call returns - is one atomic unit.
--
-- Why caller-managed and not self-contained?
--   If this procedure issued its own START TRANSACTION, calling it from
--   inside an outer transaction would IMPLICITLY COMMIT that outer
--   transaction (MySQL semantics). The post-procedure offer-application
--   code in the Flask handler would then run in a separate transaction,
--   breaking atomicity. Caller-managed avoids this footgun.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_book_event
-- ===SQL_SPLIT===
CREATE PROCEDURE sp_book_event(
    IN  p_user_id    INT,
    IN  p_event_id   INT,
    IN  p_num_people INT,
    IN  p_pay_method VARCHAR(30)
)
BEGIN
    DECLARE v_price      DECIMAL(10,2);
    DECLARE v_remaining  INT;
    DECLARE v_total      DECIMAL(10,2);
    DECLARE v_booking_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        RESIGNAL;
    END;

    SELECT price INTO v_price
    FROM Event
    WHERE event_id = p_event_id
    FOR UPDATE;

    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Event not found';
    END IF;

    SET v_remaining = fn_seats_remaining(p_event_id);

    IF v_remaining < p_num_people THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough seats available';
    END IF;

    SET v_total = v_price * p_num_people;

    INSERT INTO Booking (user_id, event_id, number_of_people, total_price, status)
    VALUES (p_user_id, p_event_id, p_num_people, v_total, 'confirmed');

    SET v_booking_id = LAST_INSERT_ID();

    INSERT INTO Transaction (booking_id, payment_method, amount, payment_status)
    VALUES (v_booking_id, p_pay_method, v_total, 'completed');

    -- Bump optimistic-locking version. Pessimistic callers don't depend on
    -- this; optimistic callers (ablation #1, optimistic tier) compare
    -- against it. Cheap to maintain on every booking.
    UPDATE Event SET version = version + 1 WHERE event_id = p_event_id;

    SELECT v_booking_id AS new_booking_id, v_total AS amount_charged;
END
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- sp_apply_offer_to_booking - applies an offer to an existing booking.
--
-- Concepts demonstrated:
--   - UDF reuse: the discount math is delegated to fn_apply_discount
--     instead of being duplicated. This is the procedure that fixed the
--     "Python re-implements SQL" issue (was inline in app.py).
--   - Caller-managed transaction: composes with sp_book_event under the
--     same outer transaction so booking + offer apply atomically.
--   - Multi-table write coordinated via the booking row's X-lock.
--
-- Transaction policy: CALLER-MANAGED.
--   Caller must hold an open transaction. We FOR UPDATE the booking row
--   so a concurrent application of a different offer cannot interleave.
--
-- Returns: a 1-row result set with final_amount and discount_amount.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_apply_offer_to_booking
-- ===SQL_SPLIT===
CREATE PROCEDURE sp_apply_offer_to_booking(
    IN p_booking_id INT,
    IN p_offer_code VARCHAR(20)
)
BEGIN
    DECLARE v_amount    DECIMAL(10,2);
    DECLARE v_final     DECIMAL(10,2);
    DECLARE v_discount  DECIMAL(10,2);
    DECLARE v_offer_id  INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        RESIGNAL;
    END;

    SELECT total_price INTO v_amount
    FROM Booking
    WHERE booking_id = p_booking_id
    FOR UPDATE;

    -- A missing booking is a real bug (caller passed a bogus id) - SIGNAL.
    IF v_amount IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking not found';
    END IF;

    -- A missing/inactive offer code is NOT a bug - users can fat-finger
    -- a coupon. We match fn_apply_discount's quiet pass-through: return
    -- the un-discounted amount and don't write anything.
    SELECT offer_id INTO v_offer_id
    FROM Offer
    WHERE code = p_offer_code AND is_active = TRUE
    LIMIT 1;

    IF v_offer_id IS NULL THEN
        SELECT v_amount      AS final_amount,
               0.00          AS discount_amount,
               NULL          AS offer_code;
    ELSE
        -- Single source of truth for discount math.
        SET v_final    = fn_apply_discount(v_amount, p_offer_code);
        SET v_discount = v_amount - v_final;

        UPDATE Booking     SET total_price = v_final WHERE booking_id = p_booking_id;
        UPDATE Transaction SET amount      = v_final WHERE booking_id = p_booking_id;

        INSERT INTO Booking_Offer (booking_id, offer_id, discount_applied)
        VALUES (p_booking_id, v_offer_id, v_discount);

        SELECT v_final       AS final_amount,
               v_discount    AS discount_amount,
               p_offer_code  AS offer_code;
    END IF;
END
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- sp_cancel_booking - flips Booking.status and Transaction.payment_status.
--
-- Concepts demonstrated:
--   - TCL: SELF-CONTAINED transaction (START TRANSACTION ... COMMIT
--     inside the procedure body). Safe to call standalone with
--     autocommit ON.
--   - Atomicity across two tables: without the transaction wrapper, a
--     crash between the two UPDATEs would leave the booking cancelled
--     but the payment still 'completed' (refund owed but not flagged).
--   - EXIT HANDLER FOR SQLEXCEPTION: rolls back automatically on any
--     error and re-raises (RESIGNAL) so the caller sees the failure.
--   - FOR UPDATE on the read: closes a race where two cancels could
--     both pass the "already cancelled?" check and double-refund.
--
-- Transaction policy: SELF-MANAGED.
--   Called from playground presets and ad-hoc admin sessions where the
--   caller is unlikely to wrap it in a transaction.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cancel_booking
-- ===SQL_SPLIT===
CREATE PROCEDURE sp_cancel_booking(IN p_booking_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_status
    FROM Booking
    WHERE booking_id = p_booking_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking not found';
    END IF;
    IF v_status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking already cancelled';
    END IF;

    UPDATE Booking     SET status         = 'cancelled' WHERE booking_id = p_booking_id;
    UPDATE Transaction SET payment_status = 'refunded'  WHERE booking_id = p_booking_id;

    COMMIT;
END
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- sp_search_events - parameterised filter for the Discover page.
--
-- Concepts demonstrated:
--   - Parameterised query with the (p_x IS NULL OR p_x = '' OR col = p_x)
--     idiom for optional filters. One procedure handles "no filter",
--     "city only", "category only" and "both".
--
-- Transaction policy: NONE (read-only).
-- ----------------------------------------------------------------------------
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
