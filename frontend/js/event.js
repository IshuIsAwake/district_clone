(function () {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("id");
  const ev = findEvent(id);
  const root = document.getElementById("detailRoot");

  if (!ev) {
    root.innerHTML = `<div class="empty-state">Event not found. <a href="index.html">Back to discover</a>.</div>`;
    return;
  }

  const cat  = findCategory(ev.category_id);
  const loc  = findLocation(ev.location_id);
  const host = findHost(ev.host_id);
  const performers = ev.performer_ids.map(pid => findPerformer(pid));
  const reviews    = reviewsFor(ev.id);

  const savedKey = "zd_saved";
  const saved    = new Set(JSON.parse(localStorage.getItem(savedKey) || "[]"));

  function stars(n) {
    return [1, 2, 3, 4, 5]
      .map(i => i <= n ? `<span>&#9733;</span>` : `<span class="off">&#9733;</span>`)
      .join("");
  }

  const avgRating = reviews.length
    ? (reviews.reduce((s, r) => s + r.rating, 0) / reviews.length).toFixed(1)
    : null;

  const chipsHtml = [
    `<span class="chip">${cat.name}</span>`,
    ev.age_limit > 0 ? `<span class="chip red">${ev.age_limit}+ only</span>` : "",
    `<span class="chip">${ev.duration} min</span>`,
    avgRating ? `<span class="chip red">&#9733; ${avgRating} (${reviews.length})</span>` : ""
  ].filter(Boolean).join("");

  const lineupHtml = performers.length
    ? performers.map(p => `
        <div class="lineup-item">
          <div class="name">${p.name}</div>
          <div class="type">${p.type}</div>
        </div>`).join("")
    : `<p style="color:var(--text-dim); font-size: 13px;">No performer lineup for this event.</p>`;

  const reviewsHtml = reviews.length
    ? reviews.map(r => `
        <div class="review-item">
          <div class="head">
            <span class="reviewer">${r.reviewer}</span>
            <span class="date">${formatDate(r.date)}</span>
          </div>
          <div class="stars">${stars(r.rating)}</div>
          <p>${r.comment}</p>
        </div>`).join("")
    : `<p style="color:var(--text-dim); font-size: 13px;">No reviews yet - be the first after the show.</p>`;

  root.innerHTML = `
    <div class="event-detail">
      <div class="detail-main">
        <h1>${ev.title}</h1>
        <div class="chips">${chipsHtml}</div>

        <div class="about">
          <h2>About this event</h2>
          <p>${ev.description}</p>
          <div class="info-grid">
            <div><span class="label">Date</span><span class="value">${formatDate(ev.date)}</span></div>
            <div><span class="label">Start time</span><span class="value">${formatTime(ev.start_time)}</span></div>
            <div><span class="label">Duration</span><span class="value">${ev.duration} minutes</span></div>
            <div><span class="label">Host</span><span class="value">${host.name}</span></div>
          </div>
        </div>

        <div class="about">
          <h2>Venue</h2>
          <p><strong>${loc.venue}</strong></p>
          <p style="color:var(--text-muted); font-size: 13px; margin-top: 4px;">
            ${loc.locality}, ${loc.city}, ${loc.state} - ${loc.pin}
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
        <div class="side-row"><span>Seats left</span><span class="v">${ev.seats_available}</span></div>
        <div class="side-row"><span>Category</span><span class="v">${cat.name}</span></div>
        <div class="side-row"><span>City</span><span class="v">${loc.city}</span></div>
        ${ev.age_limit > 0 ? `<div class="side-row"><span>Age limit</span><span class="v">${ev.age_limit}+</span></div>` : ""}
        <div class="btn-row">
          <a class="btn btn-primary" href="booking.html?id=${ev.id}">Book now</a>
          <button id="saveBtn" class="btn btn-ghost ${saved.has(ev.id) ? "active" : ""}">
            ${saved.has(ev.id) ? "Saved" : "Save"}
          </button>
        </div>
      </aside>
    </div>
  `;

  document.getElementById("saveBtn").addEventListener("click", () => {
    if (saved.has(ev.id)) { saved.delete(ev.id); }
    else                  { saved.add(ev.id); }
    localStorage.setItem(savedKey, JSON.stringify([...saved]));
    const btn = document.getElementById("saveBtn");
    btn.classList.toggle("active", saved.has(ev.id));
    btn.textContent = saved.has(ev.id) ? "Saved" : "Save";
  });
})();
