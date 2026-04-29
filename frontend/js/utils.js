// Small shared helpers + tiny API wrapper. Replaces the old data.js mirror.

const API = {
  async get(path) {
    const res = await fetch(path);
    if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error || res.statusText);
    return res.json();
  },
  async post(path, body) {
    const res = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body || {}),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || res.statusText);
    return data;
  },
};

function formatRupees(n) {
  return "Rs " + Number(n).toLocaleString("en-IN");
}

function formatDate(iso) {
  if (!iso) return "";
  const d = new Date(iso + "T00:00:00");
  return d.toLocaleDateString("en-IN", {
    weekday: "short",
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function formatTime(value) {
  if (!value) return "";
  const [h, m] = value.split(":").map(Number);
  const period = h >= 12 ? "PM" : "AM";
  const h12 = ((h + 11) % 12) + 1;
  return `${h12}:${String(m).padStart(2, "0")} ${period}`;
}

function isUpcoming(iso) {
  const today = new Date().toISOString().slice(0, 10);
  return iso >= today;
}

function stars(n) {
  return [1, 2, 3, 4, 5]
    .map(i => (i <= n ? `<span>&#9733;</span>` : `<span class="off">&#9733;</span>`))
    .join("");
}

function escapeHtml(str) {
  return String(str ?? "").replace(/[&<>"']/g, c => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

// Theme toggle logic
window.addEventListener('DOMContentLoaded', () => {
  const themeToggle = document.getElementById('theme-toggle');
  const darkIcon = document.getElementById('theme-toggle-dark-icon');
  const lightIcon = document.getElementById('theme-toggle-light-icon');
  const root = document.documentElement;

  const savedTheme = localStorage.getItem('theme');
  if (savedTheme === 'dark') {
    root.setAttribute('data-theme', 'dark');
    if (darkIcon) darkIcon.classList.add('hidden');
    if (lightIcon) lightIcon.classList.remove('hidden');
  } else {
    if (darkIcon) darkIcon.classList.remove('hidden');
    if (lightIcon) lightIcon.classList.add('hidden');
  }

  if (themeToggle) {
    themeToggle.addEventListener('click', () => {
      const isDark = root.getAttribute('data-theme') === 'dark';
      if (isDark) {
        root.removeAttribute('data-theme');
        localStorage.setItem('theme', 'light');
        if (darkIcon) darkIcon.classList.remove('hidden');
        if (lightIcon) lightIcon.classList.add('hidden');
      } else {
        root.setAttribute('data-theme', 'dark');
        localStorage.setItem('theme', 'dark');
        if (darkIcon) darkIcon.classList.add('hidden');
        if (lightIcon) lightIcon.classList.remove('hidden');
      }
    });
  }
});
