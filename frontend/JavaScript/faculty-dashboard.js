"use strict";

const API_BASE_URL = window.API_BASE_URL || "http://127.0.0.1:8000";

const AUTH_KEYS = ["access_token", "token", "accessToken", "jwt"];
const USER_KEYS = ["user", "currentUser"];
const PAGE_TITLES = {
  overview: "Dashboard Overview",
  routes: "Bus Routes",
  buses: "Bus Details",
  timetable: "Timetable",
  stops: "Bus Stops",
  tracking: "Live Bus Tracking",
  trips: "Trip Information",
  notifications: "Notifications",
  profile: "My Profile",
  settings: "Settings"
};

const state = {
  profile: null,
  summary: null,
  routes: [],
  buses: [],
  timetable: [],
  stops: [],
  trips: [],
  liveBuses: [],
  notifications: [],
  map: null,
  busMarkers: [],
  settings: { compactTables: false, showRecentNotifications: true },
  notificationPreferences: {}
};

const $ = id => document.getElementById(id);
const esc = value => String(value ?? "").replace(/[&<>"']/g, ch => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
}[ch]));
const setText = (id, value) => { const el = $(id); if (el) el.textContent = value ?? "—"; };

function readAuth(keys) {
  for (const store of [sessionStorage, localStorage]) {
    for (const key of keys) {
      const value = store.getItem(key);
      if (value) return value;
    }
  }
  return null;
}
function token() { return AUTH_KEYS.map(k => readAuth([k])).find(Boolean); }
function logout() {
  [...AUTH_KEYS, ...USER_KEYS, "user_id", "user_name", "user_email", "user_role", "role", "token_type"]
    .forEach(key => { localStorage.removeItem(key); sessionStorage.removeItem(key); });
  window.location.replace("login.html");
}
function requireFaculty() {
  const accessToken = token();
  const role = readAuth(["user_role", "role"]);
  if (!accessToken) { window.location.replace("login.html"); return false; }
  if (role && role.toUpperCase() !== "FACULTY") {
    alert("Access denied. Faculty account required.");
    logout();
    return false;
  }
  return true;
}
async function api(path, options = {}) {
  const accessToken = token();
  if (!accessToken) throw new Error("Faculty session is missing. Please login again.");
  const response = await fetch(`${API_BASE_URL.replace(/\/$/, "")}${path}`, {
    ...options,
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${accessToken}`,
      ...(options.headers || {})
    }
  });
  if (response.status === 401) { logout(); throw new Error("Session expired. Please login again."); }
  if (response.status === 403) throw new Error("Faculty access is not permitted for this request.");
  if (!response.ok) {
    let detail = `Request failed (${response.status})`;
    try { const body = await response.json(); detail = body.detail || detail; } catch (_) {}
    throw new Error(detail);
  }
  if (response.status === 204) return null;
  return response.json();
}
function toast(message) {
  const el = $("toast");
  if (!el) return;
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => el.classList.remove("show"), 2800);
}
function fmtDate(value) {
  if (!value) return "—";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? esc(value) : d.toLocaleDateString("en-IN");
}
function fmtDateTime(value) {
  if (!value) return "—";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? esc(value) : d.toLocaleString("en-IN");
}
function statusClass(status) {
  const s = String(status || "").toUpperCase();
  if (s === "ACTIVE" || s === "COMPLETED" || s === "ONLINE") return "ok";
  if (s === "INACTIVE" || s === "CANCELLED" || s === "OFFLINE") return "warn";
  return "info";
}
function validCoordinates(item) {
  const lat = Number(item.latitude), lng = Number(item.longitude);
  return Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
    !(lat === 0 && lng === 0);
}

function renderProfile(p) {
  state.profile = p;
  const name = p.name || "Faculty";
  const initial = name.trim().charAt(0).toUpperCase() || "F";
  ["sidebarName", "headerName", "welcomeName", "overviewName", "profileName"].forEach(id => setText(id, name));
  ["sidebarAvatar", "headerAvatar", "profileAvatar"].forEach(id => setText(id, initial));
  setText("welcomeEmployeeId", p.employee_id || "—");
  setText("welcomeDepartment", p.department || "—");
  setText("overviewEmail", p.email || "—");
  setText("overviewEmployee", p.employee_id || "—");
  setText("overviewDepartment", p.department || "—");
  setText("overviewFacultyId", p.faculty_id ?? "—");
  setText("profileEmail", p.email || "—");
  setText("profileEmployeeId", p.employee_id || "—");
  setText("profileFacultyId", p.faculty_id ?? "—");
  setText("profileDepartment", p.department || "—");
  setText("profileDepartmentField", p.department || "—");
  setText("profileStatus", p.is_active ? "Active account" : "Inactive account");
  setText("profileAccountStatus", p.is_active ? "Active" : "Inactive");
  setText("overviewStatus", p.is_active ? "Account active" : "Account inactive");
  $("overviewStatus")?.classList.toggle("warn", !p.is_active);
  $("overviewStatusPill")?.classList.toggle("warn", !p.is_active);
}
function renderSummary(s) {
  state.summary = s;
  setText("routeStat", s.route_count ?? 0);
  setText("stopStat", s.stop_count ?? 0);
  setText("busStat", s.bus_count ?? 0);
  setText("notificationStat", s.unread_notifications ?? 0);
  setText("activeTripStat", s.active_trip_count ?? 0);
  setText("gpsOnlineStat", state.liveBuses.filter(b => b.gps_online && validCoordinates(b)).length);
}
function renderRoutes() {
  const tbody = $("routesTable");
  if (tbody) tbody.innerHTML = state.routes.length ? state.routes.map(r => `
    <tr><td><strong>${esc(r.route_name)}</strong><small>${esc(r.description || "")}</small></td>
    <td>${esc(r.route_code)}</td><td>${esc(r.start_point)}</td><td>${esc(r.end_point)}</td>
    <td>${Number(r.bus_count) || 0}</td><td>${Number(r.stop_count) || 0}</td>
    <td><span class="status-badge ${r.is_active ? "ok" : "warn"}">${r.is_active ? "Active" : "Inactive"}</span></td></tr>`).join("") :
    `<tr><td colspan="7">No routes available.</td></tr>`;
  const cards = $("overviewRoutes");
  if (cards) cards.innerHTML = state.routes.slice(0, 4).map(r => `
    <article class="large-route-card"><div class="large-route-content">
      <span class="status-badge ${r.is_active ? "ok" : "warn"}">${r.is_active ? "Active route" : "Inactive"}</span>
      <h3>${esc(r.route_name)}</h3><span class="route-code-big">${esc(r.route_code)}</span>
      <p>${esc(r.start_point)} → ${esc(r.end_point)}</p>
      <div class="route-meta"><span>${Number(r.bus_count)||0} buses</span><span>${Number(r.stop_count)||0} stops</span></div>
      <button class="text-btn" data-open-page="routes" type="button">View route details →</button>
    </div></article>`).join("") || `<div class="empty-state">No active routes found.</div>`;
}
function renderBuses() {
  const tbody = $("busesTable");
  if (!tbody) return;
  tbody.innerHTML = state.buses.length ? state.buses.map(b => `
    <tr><td><strong>${esc(b.bus_number)}</strong></td><td>${esc(String(b.bus_type || "").replaceAll("_", " "))}</td>
    <td>${esc(b.registration_number || "—")}</td><td>${esc(b.capacity ?? "—")}</td>
    <td>${esc(b.driver_name || "Unassigned")}</td><td>${esc(b.route_name || "Not on an active trip")}</td></tr>`).join("") :
    `<tr><td colspan="6">No registered buses found.</td></tr>`;
}
function renderTimetable() {
  const tbody = $("timetableTable");
  if (!tbody) return;
  const time = value => value ? String(value).slice(0, 5) : "—";
  tbody.innerHTML = state.timetable.length ? state.timetable.map(s => `
    <tr><td>${esc(s.day_of_week)}</td><td>${esc(time(s.departure_time))}</td>
    <td>${esc(time(s.arrival_time))}</td><td>${esc(s.bus_number || "Unassigned")}</td>
    <td>${esc(s.route_name)}</td><td>${esc(s.route_code)}</td></tr>`).join("") :
    `<tr><td colspan="6">No timetable entries are configured.</td></tr>`;
}
function renderStops() {
  const tbody = $("stopsTable");
  if (!tbody) return;
  tbody.innerHTML = state.stops.length ? state.stops.map(s => `
    <tr><td><strong>${esc(s.stop_name)}</strong></td><td>${esc(s.route_name)}</td>
    <td>${esc(s.stop_order)}</td><td>${s.latitude == null ? "—" : esc(s.latitude)}</td>
    <td>${s.longitude == null ? "—" : esc(s.longitude)}</td></tr>`).join("") :
    `<tr><td colspan="5">No bus stops available.</td></tr>`;
}
function renderTrips() {
  const active = state.trips.filter(t => String(t.status).toUpperCase() === "ACTIVE").length;
  const completed = state.trips.filter(t => String(t.status).toUpperCase() === "COMPLETED").length;
  setText("tripActiveCount", active);
  setText("tripCompletedCount", completed);
  setText("tripTotalCount", state.trips.length);
  const tbody = $("tripsTable");
  if (!tbody) return;
  tbody.innerHTML = state.trips.length ? state.trips.map(t => `
    <tr><td>#${esc(t.trip_id)}</td><td>${fmtDate(t.trip_date)}</td><td><strong>${esc(t.bus_number)}</strong></td>
    <td>${esc(t.route_name)}</td><td>${esc(t.driver_name || "Unassigned")}</td>
    <td><span class="status-badge ${statusClass(t.status)}">${esc(t.status)}</span></td>
    <td>${fmtDateTime(t.start_time)}</td><td>${fmtDateTime(t.end_time)}</td></tr>`).join("") :
    `<tr><td colspan="8">No trip records available.</td></tr>`;
}
function renderLiveBuses() {
  const online = state.liveBuses.filter(b => b.gps_online && validCoordinates(b));
  setText("gpsOnlineStat", online.length);
  setText("gpsStatus", online.length
    ? `${online.length} bus(es) reporting fresh GPS coordinates`
    : "No buses currently reporting fresh GPS coordinates");
  $("gpsLiveDot")?.classList.toggle("on", online.length > 0);
  const list = $("liveBusList");
  if (list) list.innerHTML = state.liveBuses.length ? state.liveBuses.map(b => `
    <div class="live-bus-item"><div class="live-bus-heading"><strong>${esc(b.bus_number)}</strong>
      <span class="status-badge ${b.gps_online && validCoordinates(b) ? "ok" : "warn"}">${b.gps_online && validCoordinates(b) ? "GPS Online" : "GPS Offline"}</span></div>
      <span>${esc(b.route_name)}</span><small>Driver: ${esc(b.driver_name || "Unassigned")}</small>
      <small>Last update: ${fmtDateTime(b.recorded_at)}</small></div>`).join("") :
    `<div class="empty-state">There are no active trips to track.</div>`;
  if (state.map) {
    state.busMarkers.forEach(marker => state.map.removeLayer(marker));
    state.busMarkers = [];
    online.forEach(b => {
      const marker = L.marker([Number(b.latitude), Number(b.longitude)]).addTo(state.map)
        .bindPopup(`<strong>${esc(b.bus_number)}</strong><br>${esc(b.route_name)}<br>Driver: ${esc(b.driver_name || "—")}<br>Updated: ${fmtDateTime(b.recorded_at)}`);
      state.busMarkers.push(marker);
    });
    if (online.length) state.map.fitBounds(L.featureGroup(state.busMarkers).getBounds().pad(0.2));
  }
}
function renderNotifications() {
  const unread = state.notifications.filter(n => !(n.is_read ?? n.read)).length;
  setText("notificationStat", unread);
  setText("notificationBadge", unread);
  setText("notifPageCount", `${unread} unread`);
  if ($("notificationBadge")) $("notificationBadge").hidden = unread === 0;
  if ($("topNotificationDot")) $("topNotificationDot").hidden = unread === 0;
  const recent = $("recentNotifications");
  if (recent) recent.innerHTML = state.notifications.slice(0, 4).map(n => `
    <div class="notification-item"><div class="notification-icon blue"><svg class="ic"><use href="#i-bell"/></svg></div>
      <div><strong>${esc(n.title || "Notification")}</strong><span>${esc(n.message || "")}</span><small>${fmtDateTime(n.created_at)}</small></div></div>`).join("") ||
      `<div class="empty-state">No notifications yet.</div>`;
  const list = $("notificationsList");
  if (list) list.innerHTML = state.notifications.map(n => {
    const read = Boolean(n.is_read ?? n.read);
    return `<article class="dashboard-card notification-large ${read ? "" : "unread"}">
      <div class="notification-icon blue"><svg class="ic"><use href="#i-bell"/></svg></div>
      <div class="notification-body"><div class="notification-title-row"><strong>${esc(n.title || "Notification")}</strong>
      <span class="status-badge ${read ? "muted" : "warn"}">${read ? "Read" : "Unread"}</span></div>
      <p>${esc(n.message || "")}</p><small>${fmtDateTime(n.created_at)}</small>
      ${read ? "" : `<button class="text-btn mark-read-btn" data-notification-id="${esc(n.notification_id)}" type="button">Mark as read</button>`}</div>
    </article>`;
  }).join("") || `<div class="empty-state">You have no transport notifications.</div>`;
}
function initMap() {
  if (state.map || typeof L === "undefined" || !$("facultyMap")) return;
  state.map = L.map("facultyMap").setView([13.219992, 77.753943], 11);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19, attribution: "&copy; OpenStreetMap contributors"
  }).addTo(state.map);
  renderLiveBuses();
}
function openPage(name) {
  if (!PAGE_TITLES[name]) return;
  document.querySelectorAll(".page-section").forEach(el => el.classList.toggle("active", el.id === `page-${name}`));
  document.querySelectorAll(".menu-item[data-page]").forEach(el => el.classList.toggle("active", el.dataset.page === name));
  setText("pageHeading", PAGE_TITLES[name]);
  closeSidebar();
  if (name === "tracking") {
    initMap();
    setTimeout(() => state.map?.invalidateSize(), 120);
  }
}
function closeSidebar() {
  $("sidebar")?.classList.remove("open");
  $("sidebarOverlay")?.classList.remove("visible");
}
function setupSearch() {
  const input = $("globalSearch"), results = $("searchResults");
  if (!input || !results) return;
  input.addEventListener("input", () => {
    const q = input.value.trim().toLowerCase();
    if (!q) { results.hidden = true; results.innerHTML = ""; return; }
    const matches = [];
    state.routes.forEach(r => {
      if (`${r.route_name} ${r.route_code} ${r.start_point} ${r.end_point}`.toLowerCase().includes(q))
        matches.push({ label: `${r.route_name} · ${r.route_code}`, page: "routes" });
    });
    state.stops.forEach(s => {
      if (`${s.stop_name} ${s.route_name}`.toLowerCase().includes(q))
        matches.push({ label: `${s.stop_name} · ${s.route_name}`, page: "stops" });
    });
    state.trips.forEach(t => {
      if (`${t.bus_number} ${t.driver_name} ${t.route_name}`.toLowerCase().includes(q))
        matches.push({ label: `Trip #${t.trip_id} · ${t.bus_number}`, page: "trips" });
    });
    results.innerHTML = matches.slice(0, 8).map((m,i) =>
      `<button class="search-result-item" type="button" data-result-page="${m.page}">${esc(m.label)}</button>`).join("") ||
      `<div class="search-no-results">No matching transport records</div>`;
    results.hidden = false;
  });
  results.addEventListener("click", e => {
    const button = e.target.closest("[data-result-page]");
    if (!button) return;
    openPage(button.dataset.resultPage);
    results.hidden = true;
    input.value = "";
  });
  document.addEventListener("keydown", e => {
    if (e.key === "/" && !["INPUT","TEXTAREA"].includes(document.activeElement.tagName)) {
      e.preventDefault(); input.focus();
    }
    if (e.key === "Escape") { results.hidden = true; closeSidebar(); }
  });
  document.addEventListener("click", e => {
    if (!e.target.closest(".search-box")) results.hidden = true;
  });
}
function setupTableSearch(inputId, tableId) {
  const input = $(inputId), table = $(tableId);
  if (!input || !table) return;
  input.addEventListener("input", () => {
    const q = input.value.toLowerCase().trim();
    table.querySelectorAll("tr").forEach(row => row.hidden = !row.textContent.toLowerCase().includes(q));
  });
}
function setupSettings() {
  try { state.settings = { ...state.settings, ...JSON.parse(localStorage.getItem("faculty_dashboard_settings") || "{}") }; } catch (_) {}
  document.querySelectorAll("[data-setting]").forEach(input => {
    input.checked = Boolean(state.settings[input.dataset.setting]);
    input.addEventListener("change", () => {
      state.settings[input.dataset.setting] = input.checked;
      localStorage.setItem("faculty_dashboard_settings", JSON.stringify(state.settings));
      document.body.classList.toggle("compact-tables", Boolean(state.settings.compactTables));
      toast("Preference saved on this device.");
    });
  });
  document.body.classList.toggle("compact-tables", Boolean(state.settings.compactTables));
}
async function setupNotificationSettings() {
  const keys = ["busArrival", "routeUpdates", "timetableReminders"];

  try {
    const result = await api("/notifications/preferences");
    state.notificationPreferences = result.preferences || {};

    document.querySelectorAll("[data-notification-setting]").forEach(input => {
      input.checked = Boolean(state.notificationPreferences[input.dataset.notificationSetting]);

      input.addEventListener("change", async () => {
        const key = input.dataset.notificationSetting;
        const previous = Boolean(state.notificationPreferences[key]);
        state.notificationPreferences[key] = input.checked;

        try {
          const saved = await api("/notifications/preferences", {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(state.notificationPreferences)
          });
          state.notificationPreferences = saved.preferences || state.notificationPreferences;
          toast("Notification preference saved.");
        } catch (error) {
          input.checked = previous;
          state.notificationPreferences[key] = previous;
          toast("Could not save preference: " + error.message);
        }
      });
    });
  } catch (error) {
    console.error("Could not load notification preferences:", error);
    toast("Could not load notification preferences.");
  }
}
async function loadProfile() {
  const p = await api("/faculty/me");
  if (p.role !== "FACULTY") throw new Error("Faculty profile validation failed.");
  renderProfile(p);
}
async function loadSummary() { renderSummary(await api("/faculty/summary")); }
async function loadRoutes() { state.routes = await api("/faculty/routes"); renderRoutes(); }
async function loadBuses() { state.buses = await api("/faculty/buses"); renderBuses(); }
async function loadTimetable() { state.timetable = await api("/faculty/timetable"); renderTimetable(); }
async function loadStops() { state.stops = await api("/faculty/stops"); renderStops(); }
async function loadTrips() { state.trips = await api("/faculty/trips"); renderTrips(); }
async function loadLiveBuses() { state.liveBuses = await api("/faculty/live-buses"); renderLiveBuses(); }
async function loadNotifications() {
  const result = await api("/notifications/");
  state.notifications = Array.isArray(result.notifications) ? result.notifications : [];
  renderNotifications();
}
async function markNotificationRead(id) {
  await api(`/notifications/${encodeURIComponent(id)}/read`, { method: "PATCH" });
  await loadNotifications();
  toast("Notification marked as read.");
}
async function markAllRead() {
  await api("/notifications/read-all", { method: "PATCH" });
  await loadNotifications();
  toast("All notifications marked as read.");
}
async function runLoad(label, fn) {
  try { await fn(); }
  catch (error) { console.error(`${label} failed:`, error); toast(`${label}: ${error.message}`); }
}
function setupEvents() {
  document.querySelectorAll(".menu-item[data-page]").forEach(a => a.addEventListener("click", e => {
    e.preventDefault(); openPage(a.dataset.page);
  }));
  document.querySelectorAll("[data-open-page]").forEach(b => b.addEventListener("click", () => openPage(b.dataset.openPage)));
  $("menuToggle")?.addEventListener("click", () => {
    $("sidebar")?.classList.add("open"); $("sidebarOverlay")?.classList.add("visible");
  });
  $("sidebarOverlay")?.addEventListener("click", closeSidebar);
  $("logoutBtn")?.addEventListener("click", logout);
  $("settingsLogout")?.addEventListener("click", logout);
  $("profileMini")?.addEventListener("click", () => openPage("profile"));
  $("profileMini")?.addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); openPage("profile"); } });
  $("notificationBtn")?.addEventListener("click", () => openPage("notifications"));
  $("refreshRoutes")?.addEventListener("click", () => runLoad("Routes refresh", loadRoutes));
  $("refreshBuses")?.addEventListener("click", () => runLoad("Bus directory refresh", loadBuses));
  $("refreshTimetable")?.addEventListener("click", () => runLoad("Timetable refresh", loadTimetable));
  $("refreshStops")?.addEventListener("click", () => runLoad("Stops refresh", loadStops));
  $("refreshTrips")?.addEventListener("click", () => runLoad("Trips refresh", loadTrips));
  $("refreshNotifications")?.addEventListener("click", () => runLoad("Notifications refresh", loadNotifications));
  $("refreshMap")?.addEventListener("click", () => runLoad("GPS refresh", loadLiveBuses));
  $("markAllRead")?.addEventListener("click", () => runLoad("Mark all as read", markAllRead));
  $("notificationsList")?.addEventListener("click", e => {
    const button = e.target.closest("[data-notification-id]");
    if (button) runLoad("Mark as read", () => markNotificationRead(button.dataset.notificationId));
  });
}
async function init() {
  if (!requireFaculty()) return;
  setText("currentDate", new Date().toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric" }));
  setText("footerYear", new Date().getFullYear());
  setupEvents(); setupSearch(); setupSettings(); await setupNotificationSettings();
  const tasks = [
    ["Profile", loadProfile], ["Summary", loadSummary], ["Routes", loadRoutes],
    ["Buses", loadBuses], ["Timetable", loadTimetable], ["Stops", loadStops], ["Trips", loadTrips], ["Live GPS", loadLiveBuses],
    ["Notifications", loadNotifications]
  ];
  await Promise.all(tasks.map(([name, fn]) => runLoad(name, fn)));
  renderSummary(state.summary || {});
  renderLiveBuses();
}
document.addEventListener("DOMContentLoaded", init);
