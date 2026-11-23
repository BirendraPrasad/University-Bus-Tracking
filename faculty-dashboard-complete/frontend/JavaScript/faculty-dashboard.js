"use strict";

const API_BASE_URL = window.API_BASE_URL;
const PAGE_TITLES = {
  overview: "Dashboard Overview", routes: "Bus Routes", stops: "Bus Stops",
  tracking: "Live Bus Tracking", trips: "Trip Information",
  notifications: "Notifications", profile: "My Profile", settings: "Settings"
};

let facultyProfile = null;
let facultyMap = null;
let mapInitialized = false;
let busMarkers = new Map();
let facultyNotifications = [];
let refreshTimer = null;

function authValue(key) { return sessionStorage.getItem(key) || localStorage.getItem(key); }
function getAccessToken() {
  return authValue("access_token") || authValue("token") || authValue("accessToken") || authValue("jwt");
}
function redirectToLogin() { window.location.replace("login.html"); }
function logout() {
  ["access_token", "token", "accessToken", "jwt", "token_type", "user_id", "user_name", "user_email", "user_role", "role", "user", "currentUser", "student"].forEach(k => {
    localStorage.removeItem(k); sessionStorage.removeItem(k);
  });
  redirectToLogin();
}
function checkAuthentication() {
  if (!getAccessToken()) { redirectToLogin(); return false; }
  const role = authValue("user_role") || authValue("role");
  if (role && role.toUpperCase() !== "FACULTY") { alert("Faculty account required."); redirectToLogin(); return false; }
  return true;
}

async function apiRequest(endpoint, options = {}) {
  if (!API_BASE_URL) throw new Error("API URL not configured. Open through the frontend server.");
  const token = getAccessToken();
  if (!token) { redirectToLogin(); throw new Error("Login required."); }
  const headers = { Accept: "application/json", Authorization: `Bearer ${token}`, ...(options.headers || {}) };
  const response = await fetch(`${API_BASE_URL}${endpoint}`, { ...options, headers });
  if (response.status === 401) { logout(); throw new Error("Session expired. Please login again."); }
  let body = null;
  const raw = await response.text();
  try { body = raw ? JSON.parse(raw) : null; } catch { body = raw; }
  if (!response.ok) {
    const detail = body && typeof body === "object" ? (body.detail || body.message) : body;
    throw new Error(detail || `Request failed (${response.status})`);
  }
  return body;
}

function el(id) { return document.getElementById(id); }
function setText(id, value) { const node = el(id); if (node) node.textContent = value === null || value === undefined || value === "" ? "—" : String(value); }
function showToast(message) {
  const node = el("toast"); if (!node) return;
  node.textContent = message; node.classList.add("show");
  clearTimeout(showToast.timer); showToast.timer = setTimeout(() => node.classList.remove("show"), 2800);
}
function safeDate(value) { if (!value) return "—"; const d = new Date(value); return Number.isNaN(d.getTime()) ? String(value) : d.toLocaleString("en-IN"); }
function makeCell(value) { const td = document.createElement("td"); td.textContent = value === null || value === undefined || value === "" ? "—" : String(value); return td; }
function renderTableBody(id, rows, emptyMessage, columnCount) {
  const body = el(id); if (!body) return;
  body.replaceChildren();
  if (!rows.length) { const tr = document.createElement("tr"); const td = makeCell(emptyMessage); td.colSpan = columnCount; td.className = "empty-cell"; tr.appendChild(td); body.appendChild(tr); return; }
  rows.forEach(row => body.appendChild(row));
}

async function loadFacultyProfile() {
  try {
    const p = await apiRequest("/faculty/me");
    if (!p || p.role !== "FACULTY") throw new Error("Faculty profile validation failed.");
    facultyProfile = p; renderFacultyProfile(p);
  } catch (e) { console.error("Profile:", e); setText("profileName", "Profile unavailable"); setText("welcomeName", "Faculty"); setText("sidebarName", "Faculty"); setText("headerName", "Faculty"); showToast(`Profile: ${e.message}`); }
}
function renderFacultyProfile(p) {
  const name = p.name || "Faculty"; const initial = name.trim().charAt(0).toUpperCase() || "F";
  ["sidebarName", "headerName", "welcomeName", "overviewName", "profileName"].forEach(id => setText(id, name));
  setText("welcomeEmployeeId", p.employee_id); setText("welcomeDepartment", p.department);
  setText("overviewEmail", p.email); setText("overviewEmployee", p.employee_id);
  setText("overviewDepartment", p.department); setText("overviewFacultyId", p.faculty_id);
  setText("profileEmail", p.email); setText("profileEmployeeId", p.employee_id);
  setText("profileFacultyId", p.faculty_id); setText("profileDepartment", p.department);
  setText("profileDepartmentField", p.department); setText("profileStatus", p.is_active ? "Active" : "Inactive");
  setText("overviewStatus", p.is_active ? "Active" : "Inactive");
  ["sidebarAvatar", "headerAvatar", "profileAvatar"].forEach(id => setText(id, initial));
  el("overviewStatus")?.classList.toggle("inactive", !p.is_active);
}

async function loadSummary() {
  try {
    const s = await apiRequest("/faculty/summary");
    setText("routeStat", s.route_count); setText("stopStat", s.stop_count);
    setText("busStat", s.bus_count); updateNotificationCount(s.unread_notifications);
  } catch (e) { console.error("Summary:", e); showToast(`Dashboard summary: ${e.message}`); }
}
async function loadRoutes() {
  const body = el("routesTable"); if (body) body.innerHTML = '<tr><td colspan="5" class="empty-cell">Loading routes…</td></tr>';
  try {
    const rows = await apiRequest("/faculty/routes");
    renderTableBody("routesTable", rows.map(r => {
      const tr = document.createElement("tr");
      [r.route_name, r.route_code, r.start_point, r.end_point, `${r.bus_count} buses · ${r.stop_count} stops`].forEach(v => tr.appendChild(makeCell(v)));
      return tr;
    }), "No active routes found.", 5);
    applySearch("routeSearch", "routesTable");
  } catch (e) { renderTableBody("routesTable", [], `Unable to load routes: ${e.message}`, 5); }
}
async function loadStops() {
  const body = el("stopsTable"); if (body) body.innerHTML = '<tr><td colspan="5" class="empty-cell">Loading stops…</td></tr>';
  try {
    const rows = await apiRequest("/faculty/stops");
    renderTableBody("stopsTable", rows.map(r => {
      const tr = document.createElement("tr");
      [r.stop_name, r.route_name, r.stop_order, r.latitude, r.longitude].forEach(v => tr.appendChild(makeCell(v)));
      return tr;
    }), "No stops found.", 5);
    applySearch("stopSearch", "stopsTable");
  } catch (e) { renderTableBody("stopsTable", [], `Unable to load stops: ${e.message}`, 5); }
}
async function loadTrips() {
  const body = el("tripsTable"); if (body) body.innerHTML = '<tr><td colspan="6" class="empty-cell">Loading trips…</td></tr>';
  try {
    const rows = await apiRequest("/faculty/trips");
    renderTableBody("tripsTable", rows.map(r => {
      const tr = document.createElement("tr");
      [r.trip_id, r.bus_number, r.route_name, r.driver_name, r.status, safeDate(r.start_time)].forEach(v => tr.appendChild(makeCell(v)));
      return tr;
    }), "No trip records found.", 6);
  } catch (e) { renderTableBody("tripsTable", [], `Unable to load trips: ${e.message}`, 6); }
}

function updateNotificationCount(count) {
  const n = Math.max(0, Number(count) || 0); setText("notificationStat", n); setText("notificationBadge", n);
  el("topNotificationDot")?.classList.toggle("visible", n > 0);
}
async function loadFacultyNotifications() {
  const list = el("notificationsList"); if (list) list.textContent = "Loading notifications…";
  try {
    const result = await apiRequest("/notifications/");
    facultyNotifications = Array.isArray(result?.notifications) ? result.notifications : [];
    updateNotificationCount(result?.unread_count); renderFacultyNotifications();
  } catch (e) { if (list) list.textContent = `Unable to load notifications: ${e.message}`; console.error(e); }
}
function renderFacultyNotifications() {
  const list = el("notificationsList"); if (!list) return; list.replaceChildren();
  const toolbar = document.createElement("div"); toolbar.className = "notification-toolbar";
  const count = document.createElement("p"); count.textContent = `${facultyNotifications.filter(n => !n.is_read).length} unread notification(s)`;
  const allButton = document.createElement("button"); allButton.type = "button"; allButton.className = "outline-button"; allButton.textContent = "Mark all as read";
  allButton.disabled = !facultyNotifications.some(n => !n.is_read);
  allButton.addEventListener("click", async () => { allButton.disabled = true; try { await apiRequest("/notifications/read-all", { method: "PATCH" }); await loadFacultyNotifications(); } catch (e) { showToast(e.message); allButton.disabled = false; } });
  toolbar.append(count, allButton); list.appendChild(toolbar);
  if (!facultyNotifications.length) { const p = document.createElement("p"); p.className = "empty-state"; p.textContent = "No notifications yet."; list.appendChild(p); return; }
  facultyNotifications.forEach(n => {
    const card = document.createElement("article"); card.className = "panel"; card.style.marginBottom = "12px";
    const h = document.createElement("h3"); h.textContent = n.title || "Notification";
    const msg = document.createElement("p"); msg.textContent = n.message || "";
    const meta = document.createElement("small"); meta.textContent = `${n.is_read ? "Read" : "Unread"} · ${safeDate(n.created_at)}`;
    card.append(h, msg, meta);
    if (!n.is_read) { const b = document.createElement("button"); b.type = "button"; b.className = "outline-button"; b.textContent = "Mark as read"; b.addEventListener("click", async () => { b.disabled = true; try { await apiRequest(`/notifications/${n.notification_id}/read`, { method: "PATCH" }); await loadFacultyNotifications(); } catch (e) { b.disabled = false; showToast(e.message); } }); card.appendChild(b); }
    list.appendChild(card);
  });
}

function initializeFacultyMap() {
  if (!el("facultyMap")) return;
  if (typeof L === "undefined") { setText("gpsStatus", "Map library unavailable. Check internet connection."); return; }
  if (!mapInitialized) {
    facultyMap = L.map("facultyMap").setView([20.5937, 78.9629], 5);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: "© OpenStreetMap contributors", maxZoom: 19 }).addTo(facultyMap);
    mapInitialized = true;
  }
  setTimeout(() => facultyMap?.invalidateSize(), 120);
  loadLiveBuses();
}
async function loadLiveBuses() {
  try {
    const buses = await apiRequest("/faculty/live-buses");
    if (!facultyMap) return;
    const activeIds = new Set(); let plotted = 0;
    buses.forEach(bus => {
      if (bus.latitude === null || bus.longitude === null) return;
      activeIds.add(String(bus.bus_id)); plotted++;
      const popup = `<b>${escapeHtml(bus.bus_number)}</b><br>${escapeHtml(bus.route_name || "Route unavailable")}<br>Driver: ${escapeHtml(bus.driver_name || "—")}<br>GPS: ${bus.gps_online ? safeDate(bus.recorded_at) : "Pending"}`;
      const key = String(bus.bus_id);
      if (busMarkers.has(key)) busMarkers.get(key).setLatLng([bus.latitude, bus.longitude]).setPopupContent(popup);
      else busMarkers.set(key, L.marker([bus.latitude, bus.longitude]).addTo(facultyMap).bindPopup(popup));
    });
    for (const [key, marker] of busMarkers.entries()) { if (!activeIds.has(key)) { facultyMap.removeLayer(marker); busMarkers.delete(key); } }
    setText("gpsStatus", plotted ? `${plotted} active bus location(s) received. Last refresh: ${new Date().toLocaleTimeString("en-IN")}` : "No active bus GPS coordinates are currently available.");
    if (plotted && !facultyMap._facultyFitted) { const group = L.featureGroup([...busMarkers.values()]); facultyMap.fitBounds(group.getBounds().pad(0.2), { maxZoom: 14 }); facultyMap._facultyFitted = true; }
  } catch (e) { setText("gpsStatus", `Live tracking unavailable: ${e.message}`); console.error(e); }
}
function escapeHtml(value) { return String(value ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }

function applySearch(inputId, tableId) {
  const input = el(inputId), table = el(tableId); if (!input || !table) return;
  const q = input.value.toLowerCase().trim();
  table.querySelectorAll("tr").forEach(row => { row.style.display = row.textContent.toLowerCase().includes(q) ? "" : "none"; });
}
function setupSearch() {
  [["routeSearch", "routesTable"], ["stopSearch", "stopsTable"]].forEach(([inputId, tableId]) => el(inputId)?.addEventListener("input", () => applySearch(inputId, tableId)));
}
function openPage(name) {
  if (!PAGE_TITLES[name]) return;
  document.querySelectorAll(".page-section").forEach(s => s.classList.remove("active"));
  document.querySelectorAll(".nav-link").forEach(a => a.classList.remove("active"));
  el(`page-${name}`)?.classList.add("active");
  document.querySelector(`.nav-link[data-page="${name}"]`)?.classList.add("active");
  setText("pageHeading", PAGE_TITLES[name]); closeSidebar();
  if (name === "tracking") initializeFacultyMap();
  if (name === "routes") loadRoutes(); if (name === "stops") loadStops();
  if (name === "trips") loadTrips(); if (name === "notifications") loadFacultyNotifications();
}
function openSidebar() { el("sidebar")?.classList.add("open"); el("sidebarOverlay")?.classList.add("visible"); }
function closeSidebar() { el("sidebar")?.classList.remove("open"); el("sidebarOverlay")?.classList.remove("visible"); }
function setupNavigation() {
  document.querySelectorAll(".nav-link").forEach(b => b.addEventListener("click", () => openPage(b.dataset.page)));
  document.querySelectorAll("[data-open-page]").forEach(b => b.addEventListener("click", () => openPage(b.dataset.openPage)));
  el("menuToggle")?.addEventListener("click", openSidebar); el("sidebarClose")?.addEventListener("click", closeSidebar);
  el("sidebarOverlay")?.addEventListener("click", closeSidebar); el("logoutBtn")?.addEventListener("click", logout); el("settingsLogout")?.addEventListener("click", logout);
}
function setCurrentDate() {
  const d = new Date(); setText("currentDate", d.toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric" })); setText("footerYear", d.getFullYear());
}
function setupRefreshButtons() {
  el("refreshRoutes")?.addEventListener("click", loadRoutes); el("refreshStops")?.addEventListener("click", loadStops);
  el("refreshTrips")?.addEventListener("click", loadTrips); el("refreshNotifications")?.addEventListener("click", loadFacultyNotifications);
  el("refreshMap")?.addEventListener("click", () => { initializeFacultyMap(); loadLiveBuses(); });
}

document.addEventListener("DOMContentLoaded", async () => {
  if (!checkAuthentication()) return;
  setCurrentDate(); setupNavigation(); setupRefreshButtons(); setupSearch();
  await Promise.all([loadFacultyProfile(), loadSummary(), loadRoutes(), loadStops(), loadTrips(), loadFacultyNotifications()]);
  refreshTimer = setInterval(() => { if (document.visibilityState === "visible" && document.getElementById("page-tracking")?.classList.contains("active")) loadLiveBuses(); }, 15000);
});
window.addEventListener("beforeunload", () => clearInterval(refreshTimer));
