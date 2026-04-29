// queries.js — Ablation studies (A/B/C comparisons).
//
// Each ablation is a problem with three increasingly-correct solutions:
//   - basic: the obvious / naive shape, what most students would write
//   - intermediate: a step up, but still has issues
//   - advanced: what we actually use in the codebase
//
// Tiers are either:
//   - kind: "query"   — runnable SQL, sent through POST /api/query (read-only,
//                       runs inside a READ ONLY transaction). Result + timing
//                       come back.
//   - kind: "explain" — a SELECT prefixed with EXPLAIN; same path, but the
//                       result IS the planner's plan (very useful for #2).
//   - kind: "stub"    — non-runnable (e.g. application-side pseudo-code).
//                       We render the code block + an explanation; no run.
//
// Ablation #1 (concurrent booking) is the headline live demo. Its tiers are
// explained as text + SQL excerpts; the parallel-fire ("storm") button needs
// dedicated backend routes that don't run inside the read-only guard. That
// wiring is in the next iteration — the storm button is rendered but flagged
// as such.

const ABLATIONS = [
  // ====================================================================
  {
    id: "concurrent-booking",
    number: "01",
    title: "Concurrent booking — race vs lock",
    rubric: "Transactions, ACID, Strict 2PL, Optimistic locking",
    problem:
      "Two users hit the booking endpoint at the same instant for an event with one seat left. " +
      "Which versions overbook? The headline demo.",
    storm: {
      enabled: false,                  // wired in the next pass
      label: "Fire 10 bookings in parallel",
      pendingNote:
        "Concurrency simulator wires up next — needs three /api/ablation/book endpoints " +
        "(one per tier) so the basic and intermediate paths actually skip the lock. " +
        "Until then, read each tier's SQL to see why the basic mode would lose money.",
    },
    tiers: [
      {
        name: "basic",
        label: "Basic — no transaction",
        kind: "stub",
        sql:
`-- Two requests, both run this on auto-commit. Each statement is its own
-- transaction. Both read the same "1 seat left" snapshot, both pass the
-- check, both insert.
SELECT seats_available - <booked_so_far> AS remaining
FROM Event WHERE event_id = ?;
-- ... if remaining >= requested, proceed to:
INSERT INTO Booking (...) VALUES (...);`,
        observation:
          "Race window between the seat check and the insert. Two concurrent requests can both " +
          "observe 1 seat available and both succeed. End state: overbooked.",
      },
      {
        name: "intermediate",
        label: "Intermediate — txn, no lock",
        kind: "stub",
        sql:
`START TRANSACTION;
SELECT seats_available - <booked_so_far> FROM Event WHERE event_id = ?;
-- ... validation in the application
INSERT INTO Booking (...) VALUES (...);
COMMIT;`,
        observation:
          "Atomic group, but no row lock. Under InnoDB's default REPEATABLE READ, " +
          "both transactions see a consistent snapshot — but neither sees the other's " +
          "in-flight insert until commit. The race window stays open.",
      },
      {
        name: "advanced",
        label: "Advanced — FOR UPDATE (S2PL)",
        kind: "stub",
        sql:
`-- This is sp_book_event in procedures.sql.
START TRANSACTION;
SELECT price FROM Event WHERE event_id = ? FOR UPDATE;  -- X-lock on Event row
SET v_remaining = fn_seats_remaining(?);
IF v_remaining < ? THEN SIGNAL ... ; END IF;
INSERT INTO Booking (...) VALUES (...);
INSERT INTO Transaction (...) VALUES (...);
UPDATE Event SET version = version + 1 WHERE event_id = ?;
COMMIT;`,
        observation:
          "FOR UPDATE acquires an EXCLUSIVE row lock. The second concurrent request blocks " +
          "on the SELECT until the first transaction commits, then sees the updated booking " +
          "list and fails the seat check. Strict 2PL: the X-lock is held until COMMIT.",
      },
    ],
  },

  // ====================================================================
  {
    id: "index-ablation",
    number: "02",
    title: "Index ablation — full scan vs B-tree range scan",
    rubric: "Indexing",
    problem:
      "Read each EXPLAIN plan. Compare 'type' and 'rows' between the indexed and unindexed paths. " +
      "Same dataset, very different access strategies.",
    tiers: [
      {
        name: "basic",
        label: "Basic — unindexed column (full scan)",
        kind: "explain",
        sql:
`-- description has no index. The planner has to read every Event row.
EXPLAIN
SELECT event_id, title
FROM Event
WHERE description LIKE '%electronic%';`,
        observation:
          "type = ALL, rows = total table size. Linear in N. Gets worse as the catalogue grows.",
      },
      {
        name: "intermediate",
        label: "Intermediate — single B-tree index",
        kind: "explain",
        sql:
`-- idx_event_date covers this filter. Range scan on the B-tree.
EXPLAIN
SELECT event_id, title, event_date
FROM Event
WHERE event_date >= '2026-01-01';`,
        observation:
          "type = range, possible_keys includes idx_event_date. The planner walks the B-tree " +
          "to the lower bound and scans forward.",
      },
      {
        name: "advanced",
        label: "Advanced — composite filter, two indexes",
        kind: "explain",
        sql:
`-- Both predicates are individually indexed (idx_event_date, idx_event_category).
-- The planner picks the more selective one and filters the rest in memory.
EXPLAIN
SELECT event_id, title
FROM Event
WHERE event_date >= '2026-01-01'
  AND category_id = 1;`,
        observation:
          "Same range-scan kernel, with the second predicate applied as a row filter. " +
          "On a real workload one would add a composite (event_date, category_id) index to " +
          "go straight to the matching rows — a candidate for the report's 'what next' section.",
      },
    ],
  },

  // ====================================================================
  {
    id: "n-plus-one",
    number: "03",
    title: "Avg rating per event — N+1 vs single GROUP BY",
    rubric: "Joins, GROUP BY, Views",
    problem:
      "The Discover page shows an avg-rating chip per event card. Three ways to compute it. " +
      "Time them, look at row counts.",
    tiers: [
      {
        name: "basic",
        label: "Basic — N+1 from the application",
        kind: "stub",
        sql:
`# Application pseudo-code — what a naive backend would do.
events = SELECT event_id, title FROM Event;        # 1 round-trip
for ev in events:
    ev.avg = SELECT AVG(rating) FROM Review        # N round-trips
            WHERE event_id = ?;
return events`,
        observation:
          "N+1 round-trips. Each one pays connection latency + parse + plan + execute. " +
          "Linear in events, dominates wall-clock on any non-trivial dataset.",
      },
      {
        name: "intermediate",
        label: "Intermediate — correlated subquery",
        kind: "query",
        sql:
`-- One round-trip, but the subquery is logically re-evaluated per outer row.
SELECT e.event_id,
       e.title,
       (SELECT ROUND(AVG(r.rating), 2)
          FROM Review r
         WHERE r.event_id = e.event_id) AS avg_rating
FROM Event e
ORDER BY e.event_id;`,
        observation:
          "One round-trip, much better than N+1. Modern optimizers often rewrite this as a " +
          "JOIN internally, but the SQL itself reads as 'do this little thing per row'.",
      },
      {
        name: "advanced",
        label: "Advanced — single GROUP BY (or the view)",
        kind: "query",
        sql:
`-- Single pass. LEFT JOIN keeps unreviewed events in the result.
-- This is the shape inside vw_event_dashboard.
SELECT e.event_id,
       e.title,
       COALESCE(ROUND(AVG(r.rating), 2), 0) AS avg_rating,
       COUNT(r.review_id)                   AS review_count
FROM Event e
LEFT JOIN Review r ON r.event_id = e.event_id
GROUP BY e.event_id, e.title
ORDER BY e.event_id;`,
        observation:
          "Hash/sort aggregation in a single scan. COALESCE handles 'no reviews' explicitly. " +
          "vw_event_dashboard is exactly this query, named — one definition for every consumer.",
      },
    ],
  },

  // ====================================================================
  {
    id: "top-booking",
    number: "04",
    title: "Top booking per event — correlated subquery vs JOIN",
    rubric: "Subqueries, Joins, GROUP BY",
    problem:
      "Find the highest-value confirmed booking for each event. " +
      "Three idioms — same answer, different shapes.",
    tiers: [
      {
        name: "basic",
        label: "Basic — correlated subquery (Q12)",
        kind: "query",
        sql:
`-- Q12 from queries.sql. Inner query references the outer row.
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
WHERE b.status = 'confirmed'
  AND b.total_price = (
      SELECT MAX(b2.total_price)
      FROM Booking b2
      WHERE b2.event_id = b.event_id
        AND b2.status   = 'confirmed'
  )
ORDER BY b.event_id;`,
        observation:
          "Reads naturally. Logically per-row evaluation; planner often rewrites it. " +
          "The shape we already have in queries.sql.",
      },
      {
        name: "intermediate",
        label: "Intermediate — IN with derived table",
        kind: "query",
        sql:
`-- Compute the max per event in a derived table, then match back.
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
WHERE b.status = 'confirmed'
  AND (b.event_id, b.total_price) IN (
      SELECT event_id, MAX(total_price)
      FROM Booking
      WHERE status = 'confirmed'
      GROUP BY event_id
  )
ORDER BY b.event_id;`,
        observation:
          "One aggregation pass plus a tuple-IN match. No correlation — easier for the planner " +
          "to reason about.",
      },
      {
        name: "advanced",
        label: "Advanced — JOIN against the per-event max",
        kind: "query",
        sql:
`-- Same idea, expressed as an INNER JOIN.
SELECT b.booking_id, b.event_id, b.user_id, b.total_price
FROM Booking b
JOIN (
    SELECT event_id, MAX(total_price) AS top
    FROM Booking
    WHERE status = 'confirmed'
    GROUP BY event_id
) m ON m.event_id = b.event_id AND m.top = b.total_price
WHERE b.status = 'confirmed'
ORDER BY b.event_id;`,
        observation:
          "Most JOIN-native form. On a typical optimizer, often the same plan as the IN-derived " +
          "version. The point of this ablation is that all three return the same answer — choose " +
          "the one that reads clearest.",
      },
    ],
  },

  // ====================================================================
  {
    id: "discount-math",
    number: "05",
    title: "Discount math — Python vs UDF",
    rubric: "User-Defined Functions, DRY, single source of truth",
    problem:
      "Apply an offer code to a booking amount. Where should this calculation live? " +
      "(This was a real duplication in our codebase before it got refactored.)",
    tiers: [
      {
        name: "basic",
        label: "Basic — inline Python in the API handler",
        kind: "stub",
        sql:
`# What backend/app.py /api/bookings used to do.
offer = SELECT offer_id, type, discount_value FROM Offer WHERE code=?
if offer.type == "percentage":
    discount = round(amount * offer.value / 100, 2)
else:
    discount = round(offer.value, 2)
final = max(0.0, round(amount - discount, 2))
UPDATE Booking SET total_price = final WHERE booking_id = ?
UPDATE Transaction SET amount = final WHERE booking_id = ?
INSERT INTO Booking_Offer ...`,
        observation:
          "Worked, but duplicated the discount math in Python. fn_apply_discount existed " +
          "in SQL the whole time, computed the same number, and was bypassed. Two places to " +
          "edit, two places to break. Classic 'function not used by backend' rubric flag.",
      },
      {
        name: "intermediate",
        label: "Intermediate — inline SQL CASE",
        kind: "query",
        sql:
`-- Compute the discount in pure SQL. No UDF, but at least it's in one place per call site.
SELECT
    code,
    1299.00 AS original,
    CASE type
        WHEN 'percentage' THEN GREATEST(0, ROUND(1299.00 - (1299.00 * discount_value / 100), 2))
        WHEN 'flat'       THEN GREATEST(0, ROUND(1299.00 - discount_value, 2))
    END AS final
FROM Offer
WHERE is_active = TRUE;`,
        observation:
          "Cleaner than Python — no client/server round-trip for the math. But still copy-pasted " +
          "between every query that needs it.",
      },
      {
        name: "advanced",
        label: "Advanced — fn_apply_discount UDF",
        kind: "query",
        sql:
`-- One canonical definition. Every caller goes through this.
SELECT code,
       1299.00                        AS original,
       fn_apply_discount(1299.00, code) AS final
FROM Offer
WHERE is_active = TRUE;`,
        observation:
          "sp_apply_offer_to_booking now calls this UDF; /api/bookings calls that procedure. " +
          "One implementation of 'apply discount X to amount Y', composable from any layer. " +
          "If the discount rules change tomorrow, edit one function.",
      },
    ],
  },
];

// =====================================================================
// Renderer
// =====================================================================
(function () {
  const root = document.getElementById("ablationRoot");
  if (!root) return;

  root.innerHTML = "";
  ABLATIONS.forEach(a => root.appendChild(renderAblation(a)));

  function renderAblation(a) {
    const card = document.createElement("section");
    card.className = "ablation-card";
    card.id = `ablation-${a.id}`;

    card.innerHTML = `
      <header class="ablation-head">
        <div class="ablation-num">${escapeHtml(a.number)}</div>
        <div class="ablation-titles">
          <h2>${escapeHtml(a.title)}</h2>
          <p class="ablation-problem">${escapeHtml(a.problem)}</p>
          <div class="ablation-rubric">${escapeHtml(a.rubric)}</div>
        </div>
      </header>
      <nav class="tier-tabs" role="tablist"></nav>
      <div class="tier-panels"></div>
      ${a.storm ? renderStormControl(a) : ""}
    `;

    const tabsEl = card.querySelector(".tier-tabs");
    const panelsEl = card.querySelector(".tier-panels");

    a.tiers.forEach((tier, idx) => {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.className = "tier-tab" + (idx === 0 ? " active" : "");
      tab.dataset.tier = tier.name;
      tab.role = "tab";
      tab.textContent = tier.label;
      tabsEl.appendChild(tab);

      const panel = document.createElement("div");
      panel.className = "tier-panel" + (idx === 0 ? " active" : "");
      panel.dataset.tier = tier.name;
      panel.appendChild(renderTierBody(a, tier));
      panelsEl.appendChild(panel);

      tab.addEventListener("click", () => switchTier(card, tier.name));
    });

    return card;
  }

  function renderTierBody(a, tier) {
    const wrap = document.createElement("div");
    wrap.className = "tier-body";

    const sql = document.createElement("pre");
    sql.className = "tier-sql";
    sql.textContent = tier.sql;
    wrap.appendChild(sql);

    const obs = document.createElement("p");
    obs.className = "tier-observation";
    obs.textContent = tier.observation;
    wrap.appendChild(obs);

    if (tier.kind === "query" || tier.kind === "explain") {
      const actions = document.createElement("div");
      actions.className = "tier-actions";

      const btn = document.createElement("button");
      btn.className = "btn btn-primary tier-run";
      btn.type = "button";
      btn.textContent = tier.kind === "explain" ? "Run EXPLAIN" : "Run query";
      actions.appendChild(btn);

      const status = document.createElement("span");
      status.className = "tier-status";
      actions.appendChild(status);

      wrap.appendChild(actions);

      const result = document.createElement("div");
      result.className = "tier-result";
      result.innerHTML = `<div class="results-empty">Click "Run" to execute against the live database.</div>`;
      wrap.appendChild(result);

      btn.addEventListener("click", () => runTier(tier, btn, status, result));
    } else {
      // stub: just label it as not-runnable
      const note = document.createElement("div");
      note.className = "tier-stub-note";
      note.textContent = "Application-side example — not runnable as SQL. The point is the contrast.";
      wrap.appendChild(note);
    }

    return wrap;
  }

  function renderStormControl(a) {
    const note = a.storm.pendingNote
      ? `<div class="storm-note">${escapeHtml(a.storm.pendingNote)}</div>`
      : "";
    return `
      <div class="storm-bar">
        <button class="btn btn-ghost storm-btn" disabled title="Concurrency simulator wires up next">
          ${escapeHtml(a.storm.label)}
        </button>
        ${note}
      </div>
    `;
  }

  function switchTier(card, tierName) {
    card.querySelectorAll(".tier-tab").forEach(t => {
      t.classList.toggle("active", t.dataset.tier === tierName);
    });
    card.querySelectorAll(".tier-panel").forEach(p => {
      p.classList.toggle("active", p.dataset.tier === tierName);
    });
  }

  async function runTier(tier, btn, statusEl, resultEl) {
    btn.disabled = true;
    statusEl.textContent = "Running...";
    try {
      const data = await API.post("/api/query", { sql: tier.sql });
      renderResults(resultEl, data);
      statusEl.textContent = `${data.row_count} row${data.row_count === 1 ? "" : "s"} in ${data.elapsed_ms} ms`;
    } catch (err) {
      resultEl.innerHTML = `<div class="results-empty">Query failed: ${escapeHtml(err.message)}</div>`;
      statusEl.textContent = "";
    } finally {
      btn.disabled = false;
    }
  }

  function renderResults(target, { columns, rows }) {
    if (!columns || columns.length === 0) {
      target.innerHTML = `<div class="results-empty">No columns returned.</div>`;
      return;
    }
    if (!rows || rows.length === 0) {
      target.innerHTML = `<div class="results-empty">0 rows.</div>`;
      return;
    }
    const thead = `<thead><tr>${columns.map(c => `<th>${escapeHtml(c)}</th>`).join("")}</tr></thead>`;
    const tbody = `<tbody>${rows.map(row =>
      `<tr>${columns.map(c => {
        const v = row[c];
        if (v === null || v === undefined) return `<td class="cell-null">NULL</td>`;
        return `<td>${escapeHtml(v)}</td>`;
      }).join("")}</tr>`
    ).join("")}</tbody>`;
    target.innerHTML = `<div class="results-table-scroll"><table class="results-table">${thead}${tbody}</table></div>`;
  }
})();
