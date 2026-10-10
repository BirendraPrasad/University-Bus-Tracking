"use strict";
/* Driver Dashboard - University Bus Tracking
   All driver, bus, route, stop, trip and notification data comes from FastAPI.
   The JWT is read from localStorage ONLY to authenticate requests; it is never a data source. */

const API_BASE_URL = "http://127.0.0.1:8000";
const LOGIN_PAGE = "login.html";
// Must match the key(s) your existing login page writes the JWT to.
const TOKEN_KEYS = ["token", "access_token", "accessToken", "jwt"];
const GPS_SEND_INTERVAL_MS = 5000;

const ENDPOINTS = {
  profile: "/drivers/me",
  trip: "/drivers/me/trip",
  history: "/drivers/me/trips/history",
  notifications: "/drivers/me/notifications",
  start: (id) => `/drivers/me/trips/${id}/start`,
  end: (id) => `/drivers/me/trips/${id}/end`,
  location: (id) => `/drivers/me/trips/${id}/location`
};

const state = { profile: null, trip: null, tripError: null, history: null, historyError: null,
  notifs: null, notifError: null, gps: { status: "not_started", watchId: null, lastSent: 0, lat: null, lng: null, time: null },
  map: null, layer: null, driverMarker: null };

/* ---------- helpers ---------- */
const $ = (id) => document.getElementById(id);
const $$ = (s) => Array.from(document.querySelectorAll(s));
const setText = (id, v) => { const el = $(id); if (el) el.textContent = v; };
const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const dash = (v) => (v === null || v === undefined || v === "" ? "Not available" : v);
const fmtDT = (iso) => (iso ? new Date(iso).toLocaleString() : "—");
const fmtTime = (iso) => (iso ? new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "—");
const row = (l, v) => `<div class="info-row"><span>${esc(l)}</span><strong>${esc(dash(v))}</strong></div>`;
const emptyMsg = (t) => `<div class="empty">${esc(t)}</div>`;
const BUS_TYPES = { ROUTE_BUS: "Route Bus", SHUTTLE_BUS: "Shuttle Bus" };
const TRIP_BADGE = { SCHEDULED: ["info", "Scheduled"], ACTIVE: ["ok", "Active"], COMPLETED: ["", "Completed"], CANCELLED: ["bad", "Cancelled"] };
const GPS_LABEL = {
  not_started: ["", "Not Started", "GPS Not Started"], requesting: ["warn", "Requesting Permission", "Requesting Permission"],
  active: ["ok", "Active", "GPS Active"], denied: ["bad", "Permission Denied", "Permission Denied"],
  error: ["bad", "Error", "GPS Error"]
};
const badge = (map, key) => { const [cls, label] = map[key] || ["", key || "—"]; return `<span class="badge ${cls}">${esc(label)}</span>`; };

/* ---------- auth + API ---------- */
class ApiError extends Error { constructor(status, message, detail) { super(message); this.status = status; this.detail = detail; } }
const getToken = () => { for (const k of TOKEN_KEYS) { const v = localStorage.getItem(k); if (v) return v; } return null; };
const clearToken = () => TOKEN_KEYS.forEach((k) => localStorage.removeItem(k));
const redirectLogin = () => window.location.replace(LOGIN_PAGE);
function friendly(status, detail) {
  if (status === 403) return "Access denied. This area is for driver accounts only.";
  if (status === 404) return detail && detail !== "Not Found" ? detail : "This feature is not available yet.";
  if (status === 409) return detail || "That action is not allowed right now.";
  if (status === 422) return "The submitted data was not valid.";
  if (status >= 500) return "Server error. Please try again shortly.";
  return "Something went wrong. Please try again.";
}
async function api(path, options = {}) {
  const token = getToken();
  if (!token) { redirectLogin(); throw new ApiError(401, "Please log in again."); }
  let res;
  try {
    res = await fetch(API_BASE_URL + path, { ...options, headers: { Accept: "application/json", Authorization: `Bearer ${token}`, ...(options.body ? { "Content-Type": "application/json" } : {}) } });
  } catch (e) { throw new ApiError(0, "Cannot reach the server. Check your connection."); }
  if (res.status === 401) { clearToken(); redirectLogin(); throw new ApiError(401, "Your session has expired. Please log in again."); }
  if (!res.ok) {
    let detail = ""; try { const j = await res.json(); if (typeof j.detail === "string") detail = j.detail; } catch (e) { /* ignore */ }
    throw new ApiError(res.status, friendly(res.status, detail), detail);
  }
  return res.json();
}
function logout() { stopGps(true); clearToken(); redirectLogin(); }
function showBanner(text, isError = false) { const b = $("pageBanner"); b.textContent = text; b.className = `banner${isError ? " error" : ""}`; b.hidden = !text; }

/* ---------- data loading ---------- */
async function loadAll() {
  state.profile = await api(ENDPOINTS.profile); // throws 403 for non-drivers
  await refreshTripData();
  const n = await Promise.allSettled([api(ENDPOINTS.notifications)]);
  state.notifs = n[0].status === "fulfilled" ? n[0].value : null; state.notifError = n[0].status === "rejected" ? n[0].reason : null;
}
async function refreshTripData() {
  const [t, h] = await Promise.allSettled([api(ENDPOINTS.trip), api(ENDPOINTS.history)]);
  state.trip = t.status === "fulfilled" ? t.value : null; state.tripError = t.status === "rejected" ? t.reason : null;
  state.history = h.status === "fulfilled" ? h.value : null; state.historyError = h.status === "rejected" ? h.reason : null;
}

/* ---------- rendering ---------- */
function renderHeader() {
  const p = state.profile;
  setText("hdrName", p.name); setText("hdrRole", p.role); setText("hdrAvatar", (p.name || "?").charAt(0).toUpperCase());
}
function renderDashboard() {
  const p = state.profile, t = state.trip, bus = t ? t.bus : p.bus;
  setText("cBusNumber", bus ? bus.bus_number : "No bus assigned");
  setText("cBusMeta", bus ? `${BUS_TYPES[bus.bus_type] || bus.bus_type} · ${dash(bus.registration_number)}` : "Ask the transport office");
  setText("cRouteCode", t ? t.route.route_code : "—"); setText("cRouteName", t ? t.route.route_name : "No trip assigned");
  setText("cRoutePoints", t ? `${dash(t.route.start_point)} → ${dash(t.route.end_point)}` : "");
  setText("cTripStatus", t ? (TRIP_BADGE[t.status] || [0, t.status])[1] : "No trip");
  setText("cTripSub", t ? `Trip #${t.trip_id} · ${t.trip_date}` : "—");
  const g = GPS_LABEL[state.gps.status]; setText("cGpsStatus", g[2]);
  setText("cGpsSub", state.gps.time ? `Updated ${fmtTime(state.gps.time)}` : "Not sharing location");
  const stops = t ? t.stops : [];
  if (t && t.status === "SCHEDULED" && stops.length) { setText("cNextStop", stops[0].stop_name); setText("cNextSub", "First stop on the route"); }
  else { setText("cNextStop", "Not tracked yet"); setText("cNextSub", "Stop progress is not stored by the backend yet"); }
  setText("cProgress", t ? `${stops.length} stops` : "—");
  setText("cProgressSub", t ? "Total stops. Current and completed stops are not tracked yet." : "—");
}
function renderBus() {
  const p = state.profile, t = state.trip, bus = t ? t.bus : p.bus;
  $("busDetails").innerHTML = bus ? row("Bus number", bus.bus_number) + row("Bus type", BUS_TYPES[bus.bus_type] || bus.bus_type) +
    row("Registration number", bus.registration_number) + row("Capacity", bus.capacity ? `${bus.capacity} seats` : null) + row("Driver", p.name) +
    row("Current trip", t ? `#${t.trip_id} (${(TRIP_BADGE[t.status] || [0, t.status])[1]})` : "No trip") + row("Bus status", t ? (TRIP_BADGE[t.status] || [0, t.status])[1] : "No trip")
    : emptyMsg("No bus is assigned to you yet.");
}
function renderRoute() {
  const t = state.trip;
  $("routeInfo").innerHTML = t ? row("Route code", t.route.route_code) + row("Route name", t.route.route_name) + row("Start point", t.route.start_point) + row("End point", t.route.end_point)
    : emptyMsg(state.tripError ? state.tripError.message : "No route assigned yet.");
  $("stopsList").innerHTML = t && t.stops.length ? t.stops.map((s) => `<div class="stop-item"><span class="stop-no">${String(s.stop_order).padStart(2, "0")}</span>
    <strong>${esc(s.stop_name)}</strong><span class="stop-coords">${s.latitude.toFixed(5)}, ${s.longitude.toFixed(5)}</span></div>`).join("") : emptyMsg("No stops found for this route.");
  renderMap();
}
function renderTrip() {
  const t = state.trip;
  $("tripBadge").className = `badge ${t ? (TRIP_BADGE[t.status] || [""])[0] : ""}`;
  setText("tripBadge", t ? (TRIP_BADGE[t.status] || [0, t.status])[1] : "No trip");
  $("tripDetails").innerHTML = t ? row("Trip ID", t.trip_id) + row("Bus number", t.bus.bus_number) + row("Route code", t.route.route_code) + row("Route name", t.route.route_name) +
    row("Driver", state.profile.name) + row("Trip date", t.trip_date) + row("Start time", fmtDT(t.start_time)) + row("End time", fmtDT(t.end_time)) +
    row("Status", (TRIP_BADGE[t.status] || [0, t.status])[1]) : emptyMsg(state.tripError ? state.tripError.message : "No trip assigned.");
  $("startTripBtn").disabled = !(t && t.status === "SCHEDULED");
  $("endTripBtn").disabled = !(t && t.status === "ACTIVE");
}
function renderGps() {
  const g = state.gps, [cls, label] = GPS_LABEL[g.status];
  $("gpsBadge").className = `badge ${cls}`; setText("gpsBadge", label);
  setText("gpsLat", g.lat !== null ? g.lat.toFixed(6) : "—"); setText("gpsLng", g.lng !== null ? g.lng.toFixed(6) : "—");
  setText("gpsUpdated", g.time ? fmtDT(g.time) : "—");
  const active = g.status === "active" || g.status === "requesting";
  $("startGpsBtn").disabled = active; $("stopGpsBtn").disabled = !active;
  renderDashboard();
}
function renderHistory() {
  const body = $("historyBody"), empty = $("historyEmpty"), h = state.history;
  if (!h) { body.innerHTML = ""; empty.hidden = false; empty.textContent = state.historyError && state.historyError.status === 404 ? "Trip history API not available yet." : (state.historyError ? state.historyError.message : "No trip history."); return; }
  empty.hidden = h.length > 0; empty.textContent = "No trips recorded yet.";
  body.innerHTML = h.map((t) => `<tr><td>#${t.trip_id}</td><td>${esc(t.trip_date)}</td><td>${esc(t.bus.bus_number)}</td><td>${esc(t.route.route_code)}</td>
    <td>${fmtTime(t.start_time)}</td><td>${fmtTime(t.end_time)}</td><td>${badge(TRIP_BADGE, t.status)}</td></tr>`).join("");
}
function renderNotifications() {
  const n = state.notifs;
  $("notifDot").hidden = !(n && n.some((x) => !x.is_read));
  $("notifList").innerHTML = !n ? emptyMsg(state.notifError && state.notifError.status !== 404 ? state.notifError.message : "No notifications available yet.")
    : n.length ? n.map((x) => `<div class="notif-item ${x.is_read ? "" : "unread"}"><div><strong>${esc(x.title)}</strong><p>${esc(x.message)}</p>
      <small>${fmtDT(x.created_at)} · ${x.is_read ? "Read" : "Unread"}</small></div></div>`).join("") : emptyMsg("No notifications available yet.");
}
function renderProfile() {
  const p = state.profile, bus = p.bus;
  $("profileInfo").innerHTML = row("Full name", p.name) + row("Email", p.email) + row("Role", p.role) + row("Driver ID", p.driver_id) +
    row("License number", p.license_number) + row("Phone number", p.phone) + row("Assigned bus", bus ? bus.bus_number : null);
  $("setInfo").innerHTML = row("Name", p.name) + row("Email", p.email) + row("Role", p.role) + row("Account active", p.is_active ? "Yes" : "No");
}
function renderAll() { renderHeader(); renderDashboard(); renderBus(); renderRoute(); renderTrip(); renderGps(); renderHistory(); renderNotifications(); renderProfile(); }

/* ---------- map (Leaflet + OpenStreetMap) ---------- */
function ensureMap() {
  if (state.map || typeof L === "undefined") return;
  state.map = L.map("routeMap").setView([20.5937, 78.9629], 5);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "&copy; OpenStreetMap contributors" }).addTo(state.map);
  state.layer = L.layerGroup().addTo(state.map);
}
function renderMap() {
  if (!state.map) return;
  state.layer.clearLayers(); state.driverMarker = null;
  const t = state.trip, pts = [];
  if (t) {
    t.stops.forEach((s) => { const p = [s.latitude, s.longitude]; pts.push(p);
      L.marker(p, { icon: L.divIcon({ className: "", html: `<div class="num-pin">${s.stop_order}</div>`, iconSize: [26, 26] }) }).bindPopup(esc(s.stop_name)).addTo(state.layer); });
    if (pts.length > 1) L.polyline(pts, { color: "#1d4ed8", weight: 3, dashArray: "6 8" }).addTo(state.layer); // stop order, not the road path
    if (t.last_location) { const p = [t.last_location.latitude, t.last_location.longitude]; pts.push(p);
      L.circleMarker(p, { radius: 9, color: "#15803d", fillColor: "#22c55e", fillOpacity: 0.9 }).bindPopup(`Last stored bus position<br>${fmtDT(t.last_location.recorded_at)}`).addTo(state.layer); }
  }
  if (state.gps.lat !== null) setDriverMarker();
  if (pts.length) state.map.fitBounds(pts, { padding: [30, 30], maxZoom: 16 });
  const note = !t ? "No route to display." : t.last_location ? "Green marker: last bus position stored by the backend. Dashed line joins stops in order; it is not the road path."
    : state.gps.status === "active" ? "Your device position is shown on the map." : "GPS not started. No bus position available yet. Dashed line joins stops in order; it is not the road path.";
  setText("mapNote", note);
}
function setDriverMarker() {
  if (!state.map) return;
  const p = [state.gps.lat, state.gps.lng];
  if (!state.driverMarker) state.driverMarker = L.circleMarker(p, { radius: 8, color: "#b91c1c", fillColor: "#ef4444", fillOpacity: 0.9 }).bindPopup("Your device position").addTo(state.layer);
  else state.driverMarker.setLatLng(p);
}

/* ---------- trip actions (backend decides the status) ---------- */
async function tripAction(kind) {
  const t = state.trip; if (!t) return;
  const btns = [$("startTripBtn"), $("endTripBtn")]; btns.forEach((b) => (b.disabled = true));
  setText("tripMsg", kind === "start" ? "Starting trip…" : "Ending trip…");
  try {
    if (kind === "end") stopGps(false);
    await api(kind === "start" ? ENDPOINTS.start(t.trip_id) : ENDPOINTS.end(t.trip_id), { method: "POST" });
    await refreshTripData(); // re-read the real state from the database
    setText("tripMsg", kind === "start" ? "Trip started. You can now start GPS sharing." : "Trip ended.");
  } catch (e) { setText("tripMsg", e.message); await refreshTripData().catch(() => {}); }
  renderAll();
}

/* ---------- GPS (browser Geolocation API) ---------- */
function setGpsNote(t) { setText("gpsNote", t); }
function startGps() {
  const t = state.trip;
  if (!t || t.status !== "ACTIVE") { setGpsNote("Start your trip first. GPS sharing is only available during an active trip."); return; }
  if (!("geolocation" in navigator)) { state.gps.status = "error"; setGpsNote("This device or browser does not support GPS."); renderGps(); return; }
  if (!window.isSecureContext) setGpsNote("Phones only allow GPS on HTTPS pages (or localhost). Open the dashboard over HTTPS.");
  state.gps.status = "requesting"; renderGps();
  state.gps.watchId = navigator.geolocation.watchPosition(onGpsSuccess, onGpsError, { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 });
}
function stopGps(silent) {
  if (state.gps.watchId !== null) navigator.geolocation.clearWatch(state.gps.watchId);
  state.gps.watchId = null; state.gps.status = "not_started";
  if (!silent) { setGpsNote("GPS sharing stopped."); renderGps(); }
}
function onGpsSuccess(pos) {
  const g = state.gps; g.status = "active"; g.lat = pos.coords.latitude; g.lng = pos.coords.longitude; g.time = new Date(pos.timestamp).toISOString();
  setDriverMarker(); renderGps();
  if (Date.now() - g.lastSent >= GPS_SEND_INTERVAL_MS) { g.lastSent = Date.now(); sendLocation(pos.coords); }
}
function onGpsError(err) {
  state.gps.status = err.code === 1 ? "denied" : "error";
  setGpsNote(err.code === 1 ? "Location permission was denied. Allow location access in your browser settings and try again." : "Could not read your location. Check that GPS is turned on.");
  if (state.gps.watchId !== null) { navigator.geolocation.clearWatch(state.gps.watchId); state.gps.watchId = null; }
  renderGps();
}
async function sendLocation(c) {
  const t = state.trip; if (!t || t.status !== "ACTIVE") return;
  const speed = typeof c.speed === "number" && c.speed >= 0 ? c.speed : null; // m/s, null if unknown
  try {
    await api(ENDPOINTS.location(t.trip_id), { method: "POST", body: JSON.stringify({ latitude: c.latitude, longitude: c.longitude, speed }) });
    setGpsNote(`Location sent to server at ${new Date().toLocaleTimeString()}.`);
  } catch (e) { setGpsNote(e.status === 404 && e.detail === "Not Found" ? "GPS API integration pending." : e.message); }
}

/* ---------- navigation + events ---------- */
const TITLES = { dashboard: "Driver Dashboard", bus: "My Bus", route: "My Route", trip: "Current Trip", gps: "GPS Tracking", history: "Trip History", notifications: "Notifications", profile: "My Profile", settings: "Settings" };
function showSection(page) {
  if (!TITLES[page]) page = "dashboard";
  $$(".page-section").forEach((s) => s.classList.toggle("active", s.id === `${page}Section`));
  $$(".menu-item[data-page]").forEach((m) => m.classList.toggle("active", m.dataset.page === page));
  setText("pageTitle", TITLES[page]); closeDrawer(); window.scrollTo({ top: 0 });
  if (page === "route") { ensureMap(); renderMap(); setTimeout(() => state.map && state.map.invalidateSize(), 120); }
  if (page === "settings") showGpsPermission();
}
const closeDrawer = () => { $("sidebar").classList.remove("open"); $("sidebarOverlay").classList.remove("show"); $("mobileMenuBtn").setAttribute("aria-expanded", "false"); };
function toggleDrawer() { const open = $("sidebar").classList.toggle("open"); $("sidebarOverlay").classList.toggle("show", open); $("mobileMenuBtn").setAttribute("aria-expanded", String(open)); }
async function showGpsPermission() {
  let text = "Your browser will ask for location permission when you start GPS sharing.";
  try { if (navigator.permissions) { const p = await navigator.permissions.query({ name: "geolocation" }); text = `Location permission: ${p.state}. Change it in your browser's site settings.`; } } catch (e) { /* unsupported */ }
  setText("setGpsPerm", text);
}
function bindEvents() {
  $$(".menu-item[data-page]").forEach((m) => m.addEventListener("click", (e) => { e.preventDefault(); showSection(m.dataset.page); }));
  $("mobileMenuBtn").addEventListener("click", toggleDrawer); $("sidebarOverlay").addEventListener("click", closeDrawer);
  $("notifBtn").addEventListener("click", () => showSection("notifications")); $("profileBtn").addEventListener("click", () => showSection("profile"));
  [$("logoutTop"), $("logoutSide"), $("logoutSettings")].forEach((b) => b.addEventListener("click", logout));
  $("startTripBtn").addEventListener("click", () => tripAction("start"));
  $("endTripBtn").addEventListener("click", () => { if (confirm("End this trip? GPS sharing will stop.")) tripAction("end"); });
  $("startGpsBtn").addEventListener("click", startGps); $("stopGpsBtn").addEventListener("click", () => stopGps(false));
  window.addEventListener("resize", () => { if (window.innerWidth > 900) closeDrawer(); if (state.map) state.map.invalidateSize(); });
  window.addEventListener("beforeunload", () => stopGps(true));
}
async function init() {
  if (!getToken()) { redirectLogin(); return; }
  bindEvents();
  try { await loadAll(); }
  catch (e) {
    if (e.status === 403) { $("deniedPanel").hidden = false; return; } // backend refused: not a driver
    showBanner(e.message, true); return;
  }
  $("appContent").hidden = false; renderAll();
}
document.addEventListener("DOMContentLoaded", init);