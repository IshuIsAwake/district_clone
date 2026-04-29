(async function () {
  const presetList = document.getElementById("presetList");
  const editor = document.getElementById("sqlEditor");
  const runBtn = document.getElementById("runBtn");
  const clearBtn = document.getElementById("clearBtn");
  const statusLine = document.getElementById("statusLine");
  const errorBox = document.getElementById("errorBox");
  const resultsRoot = document.getElementById("resultsRoot");

  // ---------- presets ----------
  let presets = [];
  try {
    presets = await API.get("/api/presets");
  } catch (err) {
    presetList.innerHTML = `<div class="preset-loading">Could not load presets: ${escapeHtml(err.message)}</div>`;
  }

  const groups = {};
  presets.forEach(p => {
    (groups[p.group] ||= []).push(p);
  });

  presetList.innerHTML = "";
  Object.keys(groups).forEach(groupName => {
    const section = document.createElement("div");
    section.className = "preset-group";
    section.innerHTML = `<h3>${escapeHtml(groupName)}</h3>`;
    groups[groupName].forEach(p => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "preset-btn";
      btn.textContent = p.label;
      btn.addEventListener("click", () => {
        editor.value = p.sql;
        editor.focus();
        runQuery();
      });
      section.appendChild(btn);
    });
    presetList.appendChild(section);
  });

  // ---------- editor actions ----------
  clearBtn.addEventListener("click", () => {
    editor.value = "";
    resultsRoot.innerHTML = `<div class="results-empty">Run a query to see results here.</div>`;
    statusLine.textContent = "";
    errorBox.classList.add("hidden");
    editor.focus();
  });

  editor.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
      e.preventDefault();
      runQuery();
    }
  });

  runBtn.addEventListener("click", runQuery);

  async function runQuery() {
    const sql = editor.value.trim();
    if (!sql) {
      errorBox.textContent = "Nothing to run.";
      errorBox.classList.remove("hidden");
      return;
    }
    errorBox.classList.add("hidden");
    statusLine.textContent = "Running...";
    runBtn.disabled = true;

    try {
      const result = await API.post("/api/query", { sql });
      renderResults(result);
      statusLine.textContent = `${result.row_count} row${result.row_count === 1 ? "" : "s"} in ${result.elapsed_ms} ms`;
    } catch (err) {
      errorBox.textContent = err.message;
      errorBox.classList.remove("hidden");
      resultsRoot.innerHTML = `<div class="results-empty">Query failed.</div>`;
      statusLine.textContent = "";
    } finally {
      runBtn.disabled = false;
    }
  }

  function renderResults({ columns, rows }) {
    if (!columns || columns.length === 0) {
      resultsRoot.innerHTML = `<div class="results-empty">Query returned no columns.</div>`;
      return;
    }
    if (rows.length === 0) {
      resultsRoot.innerHTML = `<div class="results-empty">Query returned 0 rows.</div>`;
      return;
    }

    const thead = `<thead><tr>${columns.map(c => `<th>${escapeHtml(c)}</th>`).join("")}</tr></thead>`;
    const tbody = `<tbody>${rows.map(row =>
      `<tr>${columns.map(c => {
        const v = row[c];
        if (v === null || v === undefined) return `<td class="cell-null">NULL</td>`;
        return `<td>${escapeHtml(v)}</td>`;
      }).join("")}</tr>`
    ).join("")
      }</tbody>`;

    resultsRoot.innerHTML = `<div class="results-table-scroll"><table class="results-table">${thead}${tbody}</table></div>`;
  }

  // prefill with something harmless so the page doesn't feel empty
  editor.value = "SELECT * FROM vw_event_dashboard ORDER BY event_date LIMIT 10;";
})();
