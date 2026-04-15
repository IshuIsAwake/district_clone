(function () {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("id");
  const ev = findEvent(id);
  const root = document.getElementById("bookingRoot");

  if (!ev) {
    root.innerHTML = `<div class="empty-state">Event not found. <a href="index.html">Back</a>.</div>`;
    return;
  }

  const loc = findLocation(ev.location_id);

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
          <p>A confirmation has been sent to your registered email.</p>
        </div>
      </section>

      <aside class="panel">
        <h2>Order summary</h2>
        <div style="margin-bottom: 18px;">
          <div style="font-size: 18px; font-weight: 600; letter-spacing: -0.01em;">${ev.title}</div>
          <div style="color: var(--text-muted); font-size: 13px; margin-top: 4px;">
            ${formatDate(ev.date)} - ${formatTime(ev.start_time)}
          </div>
          <div style="color: var(--text-muted); font-size: 13px; margin-top: 2px;">
            ${loc.venue}, ${loc.city}
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
    people: 2,
    offerCode: null,
    offerResult: null
  };

  const peopleEl = document.getElementById("peopleCount");
  const sumTickets = document.getElementById("sumTickets");
  const sumSub = document.getElementById("sumSub");
  const sumTotal = document.getElementById("sumTotal");
  const discountRow = document.getElementById("discountRow");
  const discountLabel = document.getElementById("discountLabel");
  const sumDiscount = document.getElementById("sumDiscount");
  const offerMsg = document.getElementById("offerMsg");

  function refresh() {
    const subtotal = ev.price * state.people;
    peopleEl.textContent = state.people;
    sumTickets.textContent = state.people;
    sumSub.textContent = formatRupees(subtotal);

    let total = subtotal;
    if (state.offerResult && state.offerResult.valid) {
      discountRow.classList.remove("hidden");
      const res = applyOffer(subtotal, state.offerCode);
      state.offerResult = res;
      discountLabel.textContent = `Discount (${res.offer.code})`;
      sumDiscount.textContent = "-" + formatRupees(res.discount);
      total = res.final;
    } else {
      discountRow.classList.add("hidden");
    }
    sumTotal.textContent = formatRupees(total);
  }

  document.getElementById("plusBtn").addEventListener("click", () => {
    if (state.people < Math.min(10, ev.seats_available)) state.people++;
    refresh();
  });
  document.getElementById("minusBtn").addEventListener("click", () => {
    if (state.people > 1) state.people--;
    refresh();
  });

  document.getElementById("applyBtn").addEventListener("click", () => {
    const code = document.getElementById("offerInput").value.trim();
    if (!code) return;
    const subtotal = ev.price * state.people;
    const res = applyOffer(subtotal, code);
    offerMsg.style.display = "block";
    if (res.valid) {
      state.offerCode = code;
      state.offerResult = res;
      offerMsg.className = "notice ok";
      offerMsg.textContent = `${res.offer.code} applied - you save ${formatRupees(res.discount)}`;
    } else {
      state.offerCode = null;
      state.offerResult = null;
      offerMsg.className = "notice warn";
      offerMsg.textContent = "That code isn't valid or is expired.";
    }
    refresh();
  });

  document.getElementById("confirmBtn").addEventListener("click", () => {
    const fakeId = "ZD" + String(Math.floor(Math.random() * 9000 + 1000));
    document.getElementById("bookingId").textContent = fakeId;
    document.getElementById("successBanner").classList.remove("hidden");
    document.getElementById("confirmBtn").disabled = true;
    document.getElementById("confirmBtn").textContent = "Booking confirmed";
    document.getElementById("confirmBtn").style.opacity = "0.6";
  });

  refresh();
})();
