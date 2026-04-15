(async function () {
  const grid    = document.getElementById("eventGrid");
  const empty   = document.getElementById("emptyState");
  const countEl = document.getElementById("eventCount");
  const search  = document.getElementById("searchBox");
  const catSel  = document.getElementById("categoryFilter");
  const citySel = document.getElementById("cityFilter");

  let allEvents = [];
  let debounceTimer = null;

  function card(ev) {
    const seatsLow = (ev.seats_remaining ?? ev.seats_available) < 100;
    const seatsLeft = ev.seats_remaining ?? ev.seats_available;

    const el = document.createElement("article");
    el.className = "event-card";
    el.addEventListener("click", () => {
      window.location.href = `event.html?id=${ev.event_id}`;
    });

    el.innerHTML = `
      <div class="cover">
        ${escapeHtml(ev.category_name)}
        <span class="cat-badge">${escapeHtml(ev.category_name)}</span>
        ${ev.age_limit > 0 ? `<span class="age-badge">${ev.age_limit}+</span>` : ""}
      </div>
      <div class="body">
        <h3>${escapeHtml(ev.title)}</h3>
        <div class="meta">
          <span>${formatDate(ev.event_date)}</span>
          <span class="dot">&middot;</span>
          <span>${formatTime(ev.start_time)}</span>
        </div>
        <div class="meta">
          <span>${escapeHtml(ev.venue_name)}, ${escapeHtml(ev.city)}</span>
        </div>
        <div class="foot">
          <div class="price">${formatRupees(ev.price)} <span class="from">onwards</span></div>
          <div class="seats ${seatsLow ? "low" : ""}">${seatsLeft} seats left</div>
        </div>
      </div>
    `;
    return el;
  }

  function render() {
    grid.innerHTML = "";
    empty.classList.toggle("hidden", allEvents.length > 0);
    countEl.textContent = allEvents.length ? `(${allEvents.length})` : "";
    allEvents.forEach(ev => grid.appendChild(card(ev)));
  }

  async function loadEvents() {
    const params = new URLSearchParams();
    if (catSel.value)  params.set("category", catSel.value);
    if (citySel.value) params.set("city", citySel.value);
    if (search.value.trim()) params.set("q", search.value.trim());
    try {
      allEvents = await API.get(`/api/events?${params.toString()}`);
      render();
    } catch (err) {
      grid.innerHTML = "";
      empty.classList.remove("hidden");
      empty.textContent = "Could not load events: " + err.message;
    }
  }

  async function loadFilters() {
    try {
      const [cats, cities] = await Promise.all([
        API.get("/api/categories"),
        API.get("/api/cities"),
      ]);
      cats.forEach(c => {
        const opt = document.createElement("option");
        opt.value = c.category_id;
        opt.textContent = c.category_name;
        catSel.appendChild(opt);
      });
      cities.forEach(city => {
        const opt = document.createElement("option");
        opt.value = city;
        opt.textContent = city;
        citySel.appendChild(opt);
      });
    } catch (err) {
      console.error("filter load failed", err);
    }
  }

  search.addEventListener("input", () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(loadEvents, 200);
  });
  catSel.addEventListener("change", loadEvents);
  citySel.addEventListener("change", loadEvents);

  await loadFilters();
  await loadEvents();
})();
