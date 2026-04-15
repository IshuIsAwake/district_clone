(function () {
  const grid     = document.getElementById("eventGrid");
  const empty    = document.getElementById("emptyState");
  const countEl  = document.getElementById("eventCount");
  const search   = document.getElementById("searchBox");
  const catSel   = document.getElementById("categoryFilter");
  const citySel  = document.getElementById("cityFilter");

  CATEGORIES.forEach(c => {
    const opt = document.createElement("option");
    opt.value = c.id;
    opt.textContent = c.name;
    catSel.appendChild(opt);
  });

  const cities = [...new Set(LOCATIONS.map(l => l.city))].sort();
  cities.forEach(city => {
    const opt = document.createElement("option");
    opt.value = city;
    opt.textContent = city;
    citySel.appendChild(opt);
  });

  function matchesFilters(ev) {
    if (catSel.value && String(ev.category_id) !== catSel.value) return false;
    const loc = findLocation(ev.location_id);
    if (citySel.value && loc.city !== citySel.value) return false;
    const q = search.value.trim().toLowerCase();
    if (q) {
      const hay = [
        ev.title,
        ev.description,
        loc.venue,
        loc.city,
        ...ev.performer_ids.map(id => findPerformer(id)?.name || "")
      ].join(" ").toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  }

  function render() {
    const upcoming = EVENTS.filter(e => isUpcoming(e.date)).filter(matchesFilters);
    grid.innerHTML = "";
    empty.classList.toggle("hidden", upcoming.length > 0);
    countEl.textContent = upcoming.length ? `(${upcoming.length})` : "";

    upcoming
      .sort((a, b) => a.date.localeCompare(b.date))
      .forEach(ev => grid.appendChild(card(ev)));
  }

  function card(ev) {
    const cat = findCategory(ev.category_id);
    const loc = findLocation(ev.location_id);
    const seatsLow = ev.seats_available < 100;

    const el = document.createElement("article");
    el.className = "event-card";
    el.addEventListener("click", () => { window.location.href = `event.html?id=${ev.id}`; });

    el.innerHTML = `
      <div class="cover">
        ${cat.name}
        <span class="cat-badge">${cat.name}</span>
        ${ev.age_limit > 0 ? `<span class="age-badge">${ev.age_limit}+</span>` : ""}
      </div>
      <div class="body">
        <h3>${ev.title}</h3>
        <div class="meta">
          <span>${formatDate(ev.date)}</span>
          <span class="dot">&middot;</span>
          <span>${formatTime(ev.start_time)}</span>
        </div>
        <div class="meta">
          <span>${loc.venue}, ${loc.city}</span>
        </div>
        <div class="foot">
          <div class="price">${formatRupees(ev.price)} <span class="from">onwards</span></div>
          <div class="seats ${seatsLow ? "low" : ""}">${ev.seats_available} seats left</div>
        </div>
      </div>
    `;
    return el;
  }

  search.addEventListener("input", render);
  catSel.addEventListener("change", render);
  citySel.addEventListener("change", render);

  render();
})();
