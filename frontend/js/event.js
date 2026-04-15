(async function () {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("id");
  const root = document.getElementById("detailRoot");

  if (!id) {
    root.innerHTML = `<div class="empty-state">No event id. <a href="index.html">Back to discover</a>.</div>`;
    return;
  }

  let ev;
  try {
    ev = await API.get(`/api/events/${encodeURIComponent(id)}`);
  } catch (err) {
    root.innerHTML = `<div class="empty-state">Event not found. <a href="index.html">Back to discover</a>.</div>`;
    return;
  }

  const savedKey = "zd_saved";
  const saved = new Set(JSON.parse(localStorage.getItem(savedKey) || "[]"));

  const chipsHtml = [
    `<span class="chip">${escapeHtml(ev.category_name)}</span>`,
    ev.age_limit > 0 ? `<span class="chip red">${ev.age_limit}+ only</span>` : "",
    `<span class="chip">${ev.duration} min</span>`,
    ev.avg_rating
      ? `<span class="chip red">&#9733; ${ev.avg_rating} (${ev.review_count})</span>`
      : "",
  ].filter(Boolean).join("");

  const performers = ev.performers || [];
  const lineupHtml = performers.length
    ? performers.map(p => `
        <div class="lineup-item">
          <div class="name">${escapeHtml(p.name)}</div>
          <div class="type">${escapeHtml(p.performer_type)}</div>
        </div>`).join("")
    : `<p style="color:var(--text-dim); font-size: 13px;">No performer lineup for this event.</p>`;

  const reviews = ev.reviews || [];
  const reviewsHtml = reviews.length
    ? reviews.map(r => `
        <div class="review-item">
          <div class="head">
            <span class="reviewer">${escapeHtml(r.reviewer)}</span>
            <span class="date">${formatDate(r.review_date)}</span>
          </div>
          <div class="stars">${stars(r.rating)}</div>
          <p>${escapeHtml(r.comment)}</p>
        </div>`).join("")
    : `<p style="color:var(--text-dim); font-size: 13px;">No reviews yet - be the first after the show.</p>`;

  root.innerHTML = `
    <div class="event-detail">
      <div class="detail-main">
        <h1>${escapeHtml(ev.title)}</h1>
        <div class="chips">${chipsHtml}</div>

        <div class="about">
          <h2>About this event</h2>
          <p>${escapeHtml(ev.description)}</p>
          <div class="info-grid">
            <div><span class="label">Date</span><span class="value">${formatDate(ev.event_date)}</span></div>
            <div><span class="label">Start time</span><span class="value">${formatTime(ev.start_time)}</span></div>
            <div><span class="label">Duration</span><span class="value">${ev.duration} minutes</span></div>
            <div><span class="label">Host</span><span class="value">${escapeHtml(ev.host_name)}</span></div>
          </div>
        </div>

        <div class="about">
          <h2>Venue</h2>
          <p><strong>${escapeHtml(ev.venue_name)}</strong></p>
          <p style="color:var(--text-muted); font-size: 13px; margin-top: 4px;">
            ${escapeHtml(ev.locality)}, ${escapeHtml(ev.city)}, ${escapeHtml(ev.state)} - ${escapeHtml(ev.pin_code)}
          </p>
        </div>

        <div class="about">
          <h2>Lineup</h2>
          <div class="lineup-list">${lineupHtml}</div>
        </div>

        <div class="about">
          <h2>Reviews</h2>
          <div class="reviews-list">${reviewsHtml}</div>
        </div>
      </div>

      <aside class="detail-side">
        <div class="price-block">
          <div class="price-big">${formatRupees(ev.price)}<span class="unit">/ person</span></div>
        </div>
        <div class="side-row"><span>Seats left</span><span class="v">${ev.seats_remaining ?? ev.seats_available}</span></div>
        <div class="side-row"><span>Category</span><span class="v">${escapeHtml(ev.category_name)}</span></div>
        <div class="side-row"><span>City</span><span class="v">${escapeHtml(ev.city)}</span></div>
        ${ev.age_limit > 0 ? `<div class="side-row"><span>Age limit</span><span class="v">${ev.age_limit}+</span></div>` : ""}
        <div class="btn-row">
          <a class="btn btn-primary" href="booking.html?id=${ev.event_id}">Book now</a>
          <button id="saveBtn" class="btn btn-ghost ${saved.has(ev.event_id) ? "active" : ""}">
            ${saved.has(ev.event_id) ? "Saved" : "Save"}
          </button>
        </div>
      </aside>
    </div>
  `;

  document.getElementById("saveBtn").addEventListener("click", () => {
    if (saved.has(ev.event_id)) saved.delete(ev.event_id);
    else saved.add(ev.event_id);
    localStorage.setItem(savedKey, JSON.stringify([...saved]));
    const btn = document.getElementById("saveBtn");
    btn.classList.toggle("active", saved.has(ev.event_id));
    btn.textContent = saved.has(ev.event_id) ? "Saved" : "Save";
  });
})();
