-- ============================================================================
-- functions.sql - User-Defined Functions (UDFs)
-- ============================================================================
-- A function returns a single scalar value, can be used inside SELECT, WHERE,
-- ORDER BY, etc. (anywhere a scalar expression is legal). It is the right
-- tool when:
--   - the same value is computed in many places and we want one canonical
--     definition (DRY across the codebase, including from inside other
--     SQL objects like views and procedures);
--   - the value is read-only and side-effect-free (functions in MySQL are
--     restricted - cannot easily modify multiple tables or return result
--     sets, those are procedure territory).
--
-- Naming convention: fn_<purpose>. Parameters: p_<name>. Locals: v_<name>.
--
-- Statements are separated by an explicit marker so run_all.py can feed each
-- statement individually to cursor.execute() - required because CREATE
-- FUNCTION bodies contain their own semicolons.
-- ============================================================================

USE zomato_district
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- fn_seats_remaining - canonical "live seats left" for an event.
--
-- Concepts demonstrated:
--   - READS SQL DATA: declares the function reads from tables but does not
--     modify them. The optimizer can call it in SELECT/WHERE clauses.
--   - DECLARE ... INTO pattern for capturing scalar results.
--   - COALESCE for the "no bookings yet" case (SUM over zero rows is NULL,
--     not 0; without COALESCE the subtraction would also be NULL).
--
-- Why a function and not a stored column or a view?
--   - Stored counter (e.g. Event.seats_left mutated on every booking) opens
--     a race window between "check seats" and "decrement seats" - this is
--     exactly the bug ablation #1 demonstrates. Deriving from Booking
--     under FOR UPDATE on Event is correct by construction.
--   - A view could compute this for all events, but the function is
--     callable inline per-row (e.g. SELECT fn_seats_remaining(event_id)
--     FROM Event WHERE city = 'Delhi') without materialising a full view.
--
-- Where used:
--   - sp_book_event - the seat check before INSERT.
--   - /api/events list and detail (Flask app.py) - returned per row to
--     the frontend so cards show the live count.
--   - Playground / Queries panel (presets) - demo query side-by-side
--     with stored seats_available to show the gap.
-- ----------------------------------------------------------------------------
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

    -- Pending bookings are not counted - the seat is held only after the
    -- booking is confirmed (i.e. paid for). 'cancelled' obviously freed.
    SELECT COALESCE(SUM(number_of_people), 0) INTO v_booked
    FROM Booking
    WHERE event_id = p_event_id AND status = 'confirmed';

    RETURN v_initial - v_booked;
END
-- ===SQL_SPLIT===

-- ----------------------------------------------------------------------------
-- fn_apply_discount - applies an offer to an amount, returning the final.
--
-- Concepts demonstrated:
--   - Branching (IF) inside a function body.
--   - "Quiet pass-through" pattern: if the offer code does not exist or is
--     inactive, the function returns the original amount unchanged
--     (rather than SIGNALling). This is debatable - it makes typos
--     silent. Documented as a deliberate UX choice: typing a bad code
--     should not block a booking, just charge full price.
--   - Floor at 0 with the IF v_final < 0 guard - a flat discount larger
--     than the amount must not yield negative billing.
--
-- Determinism note (honest flag):
--   This function reads from Offer, which can change between calls. It is
--   NOT declared DETERMINISTIC for that reason - within a single query
--   the optimizer must be free to re-evaluate it per row. (An earlier
--   draft had it marked DETERMINISTIC; that was over-promising.)
--
-- Where used:
--   - sp_apply_offer_to_booking (procedures.sql) - called inside the
--     booking transaction to compute the final amount before updating
--     Booking and Transaction. THIS is the one place the discount math
--     is computed in the whole codebase.
--   - Playground demo - SELECT fn_apply_discount(1000, code) FROM Offer.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_apply_discount
-- ===SQL_SPLIT===
CREATE FUNCTION fn_apply_discount(p_amount DECIMAL(10,2), p_offer_code VARCHAR(20))
RETURNS DECIMAL(10,2)
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
