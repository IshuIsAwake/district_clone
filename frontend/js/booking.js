(async function () {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("id");
  const root = document.getElementById("bookingRoot");

  if (!id) {
    root.innerHTML = `<div class="empty-state">No event id. <a href="index.html">Back</a>.</div>`;
    return;
  }

  let ev, offers = [];
  try {
    [ev, offers] = await Promise.all([
      API.get(`/api/events/${encodeURIComponent(id)}`),
      API.get("/api/offers"),
    ]);
  } catch (err) {
    root.innerHTML = `<div class="empty-state">Event not found. <a href="index.html">Back</a>.</div>`;
    return;
  }

  const offerMap = Object.fromEntries(offers.map(o => [o.code.toUpperCase(), o]));
  const seatsLeft = ev.seats_remaining ?? ev.seats_available;

  root.innerHTML = `
    <div class="booking-wrap">
      <section class="panel">
        <h2>Your details</h2>

        ${ev.age_limit > 0 ? `
          <div class="notice warn">
            This event is restricted to attendees aged ${ev.age_limit}+. Valid ID is required at entry.
          </div>` : ""}

        <div class="form-row">
          <label>Number of people</label>
          <div class="counter">
            <button id="minusBtn" type="button">-</button>
            <div class="value" id="peopleCount">2</div>
            <button id="plusBtn" type="button">+</button>
          </div>
        </div>

        <div class="form-row">
          <label>Promo code</label>
          <div class="offer-box">
            <input id="offerInput" type="text" placeholder="e.g. EARLYBIRD" />
            <button id="applyBtn" type="button">Apply</button>
          </div>
          <div id="offerMsg" class="notice info" style="display:none; margin-top: 10px;"></div>
        </div>

        <div class="form-row">
          <label>Payment method</label>
          <select id="paymentSelect" class="select">
            <option value="UPI">UPI</option>
            <option value="credit_card">Credit card</option>
            <option value="debit_card">Debit card</option>
            <option value="net_banking">Net banking</option>
            <option value="wallet">Wallet</option>
          </select>
        </div>

        <button id="confirmBtn" class="btn btn-primary" style="width:100%; margin-top: 10px;">Confirm booking</button>

        <div id="successBanner" class="success-banner hidden">
          <h3>Booking confirmed</h3>
          <p>Reference: <span id="bookingId" class="code"></span></p>
          <p id="successAmount"></p>
          <p style="font-size:12px; color: var(--text-muted); margin-top: 8px;">
            Persisted to the <code>Booking</code> and <code>Transaction</code> tables via <code>sp_book_event</code>.
          </p>
        </div>

        <div id="errorBanner" class="notice warn hidden" style="margin-top: 14px;"></div>
      </section>

      <aside class="panel">
        <h2>Order summary</h2>
        <div style="margin-bottom: 18px;">
          <div style="font-size: 18px; font-weight: 600; letter-spacing: -0.01em;">${escapeHtml(ev.title)}</div>
          <div style="color: var(--text-muted); font-size: 13px; margin-top: 4px;">
            ${formatDate(ev.event_date)} - ${formatTime(ev.start_time)}
          </div>
          <div style="color: var(--text-muted); font-size: 13px; margin-top: 2px;">
            ${escapeHtml(ev.venue_name)}, ${escapeHtml(ev.city)}
          </div>
        </div>

        <div class="summary-row"><span>Price per ticket</span><span>${formatRupees(ev.price)}</span></div>
        <div class="summary-row"><span>Tickets</span><span id="sumTickets">2</span></div>
        <div class="summary-row"><span>Subtotal</span><span id="sumSub">-</span></div>
        <div class="summary-row discount hidden" id="discountRow"><span id="discountLabel">Discount</span><span id="sumDiscount">-</span></div>
        <div class="summary-total"><span>Total</span><span id="sumTotal">-</span></div>
      </aside>
    </div>
  `;

  const state = {
    people: Math.min(2, seatsLeft),
    offerCode: null,
    offer: null,
  };

  const peopleEl      = document.getElementById("peopleCount");
  const sumTickets    = document.getElementById("sumTickets");
  const sumSub        = document.getElementById("sumSub");
  const sumTotal      = document.getElementById("sumTotal");
  const discountRow   = document.getElementById("discountRow");
  const discountLabel = document.getElementById("discountLabel");
  const sumDiscount   = document.getElementById("sumDiscount");
  const offerMsg      = document.getElementById("offerMsg");
  const errorBanner   = document.getElementById("errorBanner");

  function computeDiscount(subtotal, offer) {
    if (!offer) return 0;
    if (offer.type === "percentage") return Math.round((subtotal * Number(offer.discount_value)) / 100 * 100) / 100;
    return Number(offer.discount_value);
  }

  function refresh() {
    const subtotal = Number(ev.price) * state.people;
    peopleEl.textContent = state.people;
    sumTickets.textContent = state.people;
    sumSub.textContent = formatRupees(subtotal);

    if (state.offer) {
      const discount = Math.min(subtotal, computeDiscount(subtotal, state.offer));
      discountRow.classList.remove("hidden");
      discountLabel.textContent = `Discount (${state.offer.code})`;
      sumDiscount.textContent = "-" + formatRupees(discount);
      sumTotal.textContent = formatRupees(Math.max(0, subtotal - discount));
    } else {
      discountRow.classList.add("hidden");
      sumTotal.textContent = formatRupees(subtotal);
    }
  }

  document.getElementById("plusBtn").addEventListener("click", () => {
    if (state.people < Math.min(10, seatsLeft)) state.people++;
    refresh();
  });
  document.getElementById("minusBtn").addEventListener("click", () => {
    if (state.people > 1) state.people--;
    refresh();
  });

  document.getElementById("applyBtn").addEventListener("click", () => {
    const code = document.getElementById("offerInput").value.trim().toUpperCase();
    offerMsg.style.display = "block";
    if (!code) return;
    const offer = offerMap[code];
    if (offer) {
      state.offerCode = code;
      state.offer = offer;
      offerMsg.className = "notice ok";
      const subtotal = Number(ev.price) * state.people;
      const discount = computeDiscount(subtotal, offer);
      offerMsg.textContent = `${offer.code} applied - you save ${formatRupees(Math.min(subtotal, discount))}`;
    } else {
      state.offerCode = null;
      state.offer = null;
      offerMsg.className = "notice warn";
      offerMsg.textContent = "That code isn't valid or is expired.";
    }
    refresh();
  });

  document.getElementById("confirmBtn").addEventListener("click", async () => {
    const btn = document.getElementById("confirmBtn");
    btn.disabled = true;
    btn.textContent = "Booking...";
    errorBanner.classList.add("hidden");
    try {
      const result = await API.post("/api/bookings", {
        event_id: Number(id),
        num_people: state.people,
        payment_method: document.getElementById("paymentSelect").value,
        offer_code: state.offerCode,
      });
      document.getElementById("bookingId").textContent = "ZD" + String(result.booking_id).padStart(4, "0");
      document.getElementById("successAmount").textContent =
        `Charged ${formatRupees(result.amount_charged)} via ${result.payment_method}` +
        (result.discount > 0 ? ` (saved ${formatRupees(result.discount)})` : "");
      document.getElementById("successBanner").classList.remove("hidden");
      btn.textContent = "Booking confirmed";
      btn.style.opacity = "0.6";
    } catch (err) {
      errorBanner.textContent = "Booking failed: " + err.message;
      errorBanner.classList.remove("hidden");
      btn.disabled = false;
      btn.textContent = "Confirm booking";
    }
  });

  refresh();
})();
