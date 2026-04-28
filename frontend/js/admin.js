(function () {
  const editor      = document.getElementById("sqlEditor");
  const runBtn      = document.getElementById("runBtn");
  const clearBtn    = document.getElementById("clearBtn");
  const statusLine  = document.getElementById("statusLine");
  const errorBox    = document.getElementById("errorBox");
  const resultsRoot = document.getElementById("resultsRoot");

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
      const result = await API.post("/api/admin/query", { sql });
      renderResults(result);
      if (result.affected_rows !== null && result.affected_rows !== undefined) {
        statusLine.textContent = `${result.affected_rows} row${result.affected_rows === 1 ? "" : "s"} affected in ${result.elapsed_ms} ms`;
      } else {
        statusLine.textContent = `${result.row_count} row${result.row_count === 1 ? "" : "s"} in ${result.elapsed_ms} ms`;
      }
    } catch (err) {
      errorBox.textContent = err.message;
      errorBox.classList.remove("hidden");
      resultsRoot.innerHTML = `<div class="results-empty">Query failed.</div>`;
      statusLine.textContent = "";
    } finally {
      runBtn.disabled = false;
    }
  }

  function renderResults({ columns, rows, affected_rows }) {
    if (!columns || columns.length === 0) {
      const msg = affected_rows !== null && affected_rows !== undefined
        ? `OK - ${affected_rows} row${affected_rows === 1 ? "" : "s"} affected.`
        : "Statement executed. No result set.";
      resultsRoot.innerHTML = `<div class="results-empty">${escapeHtml(msg)}</div>`;
      return;
    }
    if (rows.length === 0) {
      resultsRoot.innerHTML = `<div class="results-empty">Query returned 0 rows.</div>`;
      return;
    }

    const thead = `<thead><tr>${columns.map(c => `<th>${escapeHtml(c)}</th>`).join("")}</tr></thead>`;
    const tbody = `<tbody>${
      rows.map(row =>
        `<tr>${columns.map(c => {
          const v = row[c];
          if (v === null || v === undefined) return `<td class="cell-null">NULL</td>`;
          return `<td>${escapeHtml(v)}</td>`;
        }).join("")}</tr>`
      ).join("")
    }</tbody>`;

    resultsRoot.innerHTML = `<div class="results-table-scroll"><table class="results-table">${thead}${tbody}</table></div>`;
  }
})();
