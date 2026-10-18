"use strict";
/* Driver Dashboard - University Bus Tracking
   All driver, bus, route, stop, trip and notification data comes from FastAPI.
   The JWT is read from localStorage ONLY to authenticate requests; it is never a data source.
   The selected trip id is kept in memory only. */

const API_BASE_URL = "http://127.0.0.1:8000";
const LOGIN_PAGE = "login.html";
// Must match the key(s) your login page writes the JWT to.
const TOKEN_KEYS = ["token", "access_token", "accessToken", "jwt"];
const GPS_SEND_INTERVAL_MS = 5000;

const ENDPOINTS = {
  profile: "/drivers/me",
  trip: "/drivers/me/trip",
  available: "/drivers/me/trips/available",
  history: "/drivers/me/trips/history",
  notifications: "/drivers/me/notifications",
  start: (id) => `/drivers/me/trips/${encodeURIComponent(id)}/start`,
  end: (id) => `/drivers/me/trips/${encodeURIComponent(id)}/end`,
  location: (id) => `/drivers/me/trips/${encodeURIComponent(id)}/location`
};

const state = {
  profile: null,
  available: null, availableError: null, loadingTrips: true,
  serverTrip: null, serverTripError: null,
  selectedId: null,
  history: null, historyError: null,
  notifs: null, notifError: null,
  busy: false,
  gps: { status: "not_started", watchId: null, tripId: null, lastSent: 0, sending: false, lat: null, lng: null, time: null },
  maps: {}
};

/* ---------- helpers ---------- */
const $ = (id) => document.getElementById(id);
const $$ = (s) => Array.from(document.querySelectorAll(s));
const setText = (id, v) => { const el = $(id); if (el) el.textContent = v; };
const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const dash = (v) => (v === null || v === undefined || v === "" ? "Not available" : v);
const toDate = (iso) => { const d = new Date(iso); return isNaN(d) ? null : d; };
const fmtDT = (iso) => { const d = iso ? toDate(iso) : null; return d ? d.toLocaleString() : "—"; };
const fmtTime = (iso) => { const d = iso ? toDate(iso) : null; return d ? d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "—"; };
const row = (l, v) => `<div class="info-row"><span>${esc(l)}</span><strong>${esc(dash(v))}</strong></div>`;
const emptyMsg = (t) => `<div class="empty">${esc(t)}</div>`;
const pick = (o, ...keys) => { for (const k of keys) if (o && o[k] !== undefined && o[k] !== null) return o[k]; return null; };
const BUS_TYPES = { ROUTE_BUS: "Route Bus", SHUTTLE_BUS: "Shuttle Bus" };
const busType = (t) => (t ? BUS_TYPES[t] || t : null);
const TRIP_BADGE = { SCHEDULED: ["info", "Scheduled"], ACTIVE: ["ok", "Active"], COMPLETED: ["", "Completed"], CANCELLED: ["bad", "Cancelled"] };
const statusLabel = (s) => (s ? (TRIP_BADGE[s] || ["", s])[1] : "No trip");
const statusBadge = (s) => `<span class="badge ${esc((TRIP_BADGE[s] || [""])[0])}">${esc(statusLabel(s))}</span>`;
const GPS_LABEL = {
  not_started: ["", "Not Started", "GPS Not Started"], requesting: ["warn", "Requesting Permission", "Requesting Permission"],
  active: ["ok", "Active", "GPS Active"], denied: ["bad", "Permission Denied", "Permission Denied"], error: ["bad", "Error", "GPS Error"]
};
function setMsg(id, text, kind) { const el = $(id); if (!el) return; el.textContent = text || ""; el.className = `msg${kind ? " " + kind : ""}`; }

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
function showBanner(text, isError) { const b = $("pageBanner"); b.textContent = text; b.className = `banner${isError ? " error" : ""}`; b.hidden = !text; }

/* ---------- trip normalising (tolerates nested or flat API shapes) ---------- */
function normalizeTrip(r) {
  if (!r || typeof r !== "object") return null;
  const bus = r.bus || {}, route = r.route || {};
  const status = pick(r, "status", "trip_status");
  return {
    trip_id: pick(r, "trip_id", "id"), trip_date: pick(r, "trip_date", "date"),
    start_time: pick(r, "start_time"), end_time: pick(r, "end_time"), status: status ? String(status).toUpperCase() : null,
    bus: { bus_number: pick(bus, "bus_number") ?? pick(r, "bus_number"), bus_type: pick(bus, "bus_type") ?? pick(r, "bus_type"),
      capacity: pick(bus, "capacity") ?? pick(r, "capacity"), registration_number: pick(bus, "registration_number") ?? pick(r, "registration_number") },
    route: { route_code: pick(route, "route_code") ?? pick(r, "route_code"), route_name: pick(route, "route_name") ?? pick(r, "route_name"),
      start_point: pick(route, "start_point") ?? pick(r, "start_point"), end_point: pick(route, "end_point") ?? pick(r, "end_point") },
    stops: Array.isArray(r.stops) ? r.stops : null, last_location: r.last_location || null
  };
}
const sameId = (a, b) => a !== null && b !== null && String(a) === String(b);
function selectedAvailable() { return state.available ? state.available.find((t) => sameId(t.trip_id, state.selectedId)) || null : null; }
/* The trip the dashboard works with: the selected trip (enriched with backend detail when
   GET /drivers/me/trip returned that same trip), otherwise the backend's own current trip. */
function currentTrip() {
  const srv = state.serverTrip;
  if (state.selectedId === null) return srv;
  const sel = selectedAvailable();
  if (sel) return srv && sameId(srv.trip_id, sel.trip_id) ? { ...sel, ...Object.fromEntries(Object.entries(srv).filter(([, v]) => v !== null)) } : sel;
  return srv && sameId(srv.trip_id, state.selectedId) ? srv : null;
}
const tripBus = () => { const t = currentTrip(); return (t && t.bus && t.bus.bus_number ? t.bus : null) || (state.profile && state.profile.bus) || null; };

/* ---------- data loading ---------- */
async function fetchServerTrip() {
  const q = state.selectedId !== null ? `?trip_id=${encodeURIComponent(state.selectedId)}` : "";
  try { state.serverTrip = normalizeTrip(await api(ENDPOINTS.trip + q)); state.serverTripError = null; }
  catch (e) { state.serverTrip = null; state.serverTripError = e; }
}
async function fetchAvailable() {
  try {
    const d = await api(ENDPOINTS.available);
    const list = Array.isArray(d) ? d : (d && Array.isArray(d.trips) ? d.trips : []);
    state.available = list.map(normalizeTrip).filter((t) => t && t.trip_id !== null); state.availableError = null;
  } catch (e) { state.available = null; state.availableError = e; }
}
async function fetchHistory() {
  try {
    const d = await api(ENDPOINTS.history);
    state.history = (Array.isArray(d) ? d : (d && Array.isArray(d.trips) ? d.trips : [])).map(normalizeTrip).filter(Boolean); state.historyError = null;
  } catch (e) { state.history = null; state.historyError = e; }
}
async function fetchNotifs() {
  try { const d = await api(ENDPOINTS.notifications); state.notifs = Array.isArray(d) ? d : []; state.notifError = null; }
  catch (e) { state.notifs = null; state.notifError = e; }
}
async function loadTripData() {
  state.loadingTrips = true; renderTrips();
  await Promise.all([fetchAvailable(), fetchServerTrip(), fetchHistory()]);
  state.loadingTrips = false;
}
async function initialLoad() {
  await Promise.all([loadTripData(), fetchNotifs()]);
  // Default selection: backend's current trip if it is available, otherwise an active available trip.
  if (state.selectedId === null && state.available && state.available.length) {
    const srv = state.serverTrip;
    const pickTrip = (srv && state.available.find((t) => sameId(t.trip_id, srv.trip_id))) || state.available.find((t) => t.status === "ACTIVE");
    if (pickTrip) { state.selectedId = pickTrip.trip_id; if (!srv || !sameId(srv.trip_id, pickTrip.trip_id)) await fetchServerTrip(); }
  }
}

/* ---------- rendering ---------- */
function renderHeader() {
  const p = state.profile;
  setText("hdrName", p.name || "Driver"); setText("hdrRole", p.role || "DRIVER");
  setText("hdrAvatar", (p.name || "D").charAt(0).toUpperCase()); setText("welcomeMsg", `Welcome back, ${p.name || "Driver"}`);
}
function renderDashboard() {
  const t = currentTrip(), bus = tripBus(), stops = t && t.stops;
  setText("cBusNumber", bus ? dash(bus.bus_number) : "No bus assigned");
  setText("cBusMeta", bus ? `${dash(busType(bus.bus_type))} · ${dash(bus.registration_number)}` : "Ask the transport office");
  setText("cRouteCode", t ? dash(t.route.route_code) : "—"); setText("cRouteName", t ? dash(t.route.route_name) : "No trip selected");
  setText("cRoutePoints", t ? `${dash(t.route.start_point)} → ${dash(t.route.end_point)}` : "");
  setText("cTripStatus", t ? statusLabel(t.status) : "No trip"); setText("cTripSub", t ? `Trip #${t.trip_id} · ${dash(t.trip_date)}` : "Select a trip to begin");
  const g = GPS_LABEL[state.gps.status];
  setText("cGpsStatus", g[2]); setText("cGpsSub", state.gps.time ? `Updated ${fmtTime(state.gps.time)}` : "Not sharing location");
  setText("cNextStop", "Not available"); setText("cNextSub", "Stop progress is not tracked yet");
  setText("cProgress", stops ? `${stops.length} stops` : "—");
  setText("cProgressSub", stops ? "Total stops. Current and completed stops are not tracked yet." : (t ? "Stop list not available for this trip" : "—"));
  $("dashBus").innerHTML = bus ? row("Bus number", bus.bus_number) + row("Bus type", busType(bus.bus_type)) + row("Registration number", bus.registration_number) +
    row("Capacity", bus.capacity ? `${bus.capacity} seats` : null) + row("Assignment", t ? `Trip #${t.trip_id} · ${statusLabel(t.status)}` : "No trip selected") : emptyMsg("No bus is assigned to you yet.");
}
function renderBus() {
  const bus = tripBus(), t = currentTrip();
  $("busDetails").innerHTML = bus ? row("Bus number", bus.bus_number) + row("Bus type", busType(bus.bus_type)) + row("Registration number", bus.registration_number) +
    row("Capacity", bus.capacity ? `${bus.capacity} seats` : null) + row("Driver", state.profile.name) +
    row("Current trip", t ? `#${t.trip_id}` : "No trip selected") + row("Bus status", t ? statusLabel(t.status) : "No trip selected") : emptyMsg("No bus is assigned to you yet.");
}
function stopsMissingText(t) { return t ? "Stops for this trip are not available. If you selected a trip other than the server's current one, the backend needs the optional trip_id support on GET /drivers/me/trip." : "Select a trip to see its route."; }
function renderRoute() {
  const t = currentTrip();
  $("routeInfo").innerHTML = t ? row("Route code", t.route.route_code) + row("Route name", t.route.route_name) + row("Start point", t.route.start_point) + row("End point", t.route.end_point)
    : emptyMsg(state.serverTripError && state.selectedId === null ? state.serverTripError.message : "No trip selected.");
  $("stopsList").innerHTML = t && t.stops && t.stops.length ? t.stops.map((s) => {
    const lat = Number(s.latitude), lng = Number(s.longitude);
    return `<div class="stop-item"><span class="stop-no">${esc(String(s.stop_order ?? "").padStart(2, "0"))}</span><strong>${esc(s.stop_name)}</strong>
      <span class="stop-coords">${isFinite(lat) && isFinite(lng) ? `${lat.toFixed(5)}, ${lng.toFixed(5)}` : "—"}</span></div>`;
  }).join("") : emptyMsg(t && t.stops ? "No stops found for this route." : stopsMissingText(t));
  renderMaps();
}
function renderTrips() {
  const box = $("tripsList"), list = state.available;
  $("refreshTripsBtn").disabled = state.loadingTrips; $("refreshTripsBtn").classList.toggle("busy", state.loadingTrips);
  if (state.loadingTrips && !list) { box.innerHTML = `<div class="skeleton" style="height:170px"></div><div class="skeleton" style="height:170px"></div>`; return; }
  if (!list) { box.innerHTML = ""; setMsg("tripsMsg", state.availableError ? state.availableError.message : "Could not load trips.", "error"); return; }
  setMsg("tripsMsg", "", "");
  if (!list.length) { box.innerHTML = `<div class="empty" style="grid-column:1/-1">No trips are assigned to you right now.</div>`; return; }
  box.innerHTML = list.map((t) => {
    const sel = sameId(t.trip_id, state.selectedId);
    return `<article class="trip-card${sel ? " selected" : ""}">
      <div class="trip-card-top"><strong>Trip #${esc(t.trip_id)}</strong>${statusBadge(t.status)}</div>
      <div class="trip-meta">
        <div><span>Bus</span><b>${esc(dash(t.bus.bus_number))}</b></div><div><span>Date</span><b>${esc(dash(t.trip_date))}</b></div>
        <div class="full"><span>Route</span><b>${esc(dash(t.route.route_code))} · ${esc(dash(t.route.route_name))}</b></div>
        <div class="full"><span>From → To</span><b>${esc(dash(t.route.start_point))} → ${esc(dash(t.route.end_point))}</b></div>
        <div><span>Start time</span><b>${esc(t.start_time ? fmtTime(t.start_time) : "Not started")}</b></div>
      </div>
      <button class="btn ${sel ? "outline" : "primary"}" type="button" data-select-trip="${esc(t.trip_id)}" aria-pressed="${sel}" ${state.busy ? "disabled" : ""}>${sel ? "Selected" : "Select Trip"}</button></article>`;
  }).join("");
}
function renderTrip() {
  const t = currentTrip();
  $("tripBadge").className = `badge ${t ? (TRIP_BADGE[t.status] || [""])[0] : ""}`; setText("tripBadge", t ? statusLabel(t.status) : "No trip");
  $("tripDetails").innerHTML = t ? row("Trip ID", t.trip_id) + row("Bus number", t.bus.bus_number) + row("Route code", t.route.route_code) + row("Route name", t.route.route_name) +
    row("Driver", state.profile.name) + row("Trip date", t.trip_date) + row("Start time", fmtDT(t.start_time)) + row("End time", fmtDT(t.end_time)) + row("Status", statusLabel(t.status))
    : emptyMsg(state.selectedId === null && state.serverTripError ? state.serverTripError.message : "No trip selected. Choose one under Available Trips.");
  $("startTripBtn").disabled = state.busy || !(t && t.status === "SCHEDULED");
  $("endTripBtn").disabled = state.busy || !(t && t.status === "ACTIVE");
}
function renderGps() {
  const g = state.gps, [cls, label] = GPS_LABEL[g.status], t = currentTrip();
  $("gpsBadge").className = `badge ${cls}`; setText("gpsBadge", label);
  setText("gpsLat", g.lat !== null ? g.lat.toFixed(6) : "—"); setText("gpsLng", g.lng !== null ? g.lng.toFixed(6) : "—"); setText("gpsUpdated", g.time ? fmtDT(g.time) : "—");
  const running = g.status === "active" || g.status === "requesting";
  $("startGpsBtn").disabled = running || !(t && t.status === "ACTIVE"); $("stopGpsBtn").disabled = !running;
  renderDashboard();
}
function renderHistory() {
  const body = $("historyBody"), empty = $("historyEmpty"), h = state.history;
  if (state.loadingTrips && !h) { body.innerHTML = ""; empty.hidden = false; empty.textContent = "Loading trip history…"; return; }
  if (!h) { body.innerHTML = ""; empty.hidden = false; empty.textContent = state.historyError && state.historyError.status === 404 ? "Trip history API not available yet." : (state.historyError ? state.historyError.message : "No trip history."); return; }
  empty.hidden = h.length > 0; empty.textContent = "No trips recorded yet.";
  body.innerHTML = h.map((t) => `<tr><td>#${esc(t.trip_id)}</td><td>${esc(dash(t.trip_date))}</td><td>${esc(dash(t.bus.bus_number))}</td><td>${esc(dash(t.route.route_code))}</td>
    <td>${esc(fmtTime(t.start_time))}</td><td>${esc(fmtTime(t.end_time))}</td><td>${statusBadge(t.status)}</td></tr>`).join("");
}
function renderNotifications() {
  const n = state.notifs;
  $("notifDot").hidden = !(n && n.some((x) => !x.is_read));
  $("notifList").innerHTML = !n ? emptyMsg(state.notifError && state.notifError.status !== 404 ? state.notifError.message : "No notifications available yet.")
    : n.length ? n.map((x) => `<div class="notif-item ${x.is_read ? "" : "unread"}"><div><strong>${esc(x.title)}</strong><p>${esc(x.message)}</p>
      <small>${esc(fmtDT(x.created_at))} · ${x.is_read ? "Read" : "Unread"}</small></div></div>`).join("") : emptyMsg("No notifications available yet.");
}
function renderProfile() {
  const p = state.profile, bus = p.bus;
  $("profileInfo").innerHTML = row("Full name", p.name) + row("Email", p.email) + row("Role", p.role) + row("Driver ID", p.driver_id) +
    row("License number", p.license_number) + row("Phone number", p.phone) + row("Assigned bus", bus ? bus.bus_number : null);
  $("setInfo").innerHTML = row("Name", p.name) + row("Email", p.email) + row("Role", p.role) + row("Account active", p.is_active === undefined ? null : (p.is_active ? "Yes" : "No"));
}
function renderAll() { renderHeader(); renderDashboard(); renderBus(); renderRoute(); renderTrips(); renderTrip(); renderGps(); renderHistory(); renderNotifications(); renderProfile(); }

/* ---------- maps (Leaflet + OpenStreetMap) ---------- */
const MAP_TARGETS = { dash: ["dashMap", "dashMapNote", "dashMapLabel"], route: ["routeMap", "routeMapNote", null] };
function ensureMap(key) {
  if (state.maps[key] || typeof L === "undefined") return state.maps[key] || null;
  const el = $(MAP_TARGETS[key][0]); if (!el) return null;
  const map = L.map(el, { zoomControl: true }).setView([20.5937, 78.9629], 5);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "&copy; OpenStreetMap contributors" }).addTo(map);
  state.maps[key] = { map, layer: L.layerGroup().addTo(map), me: null };
  return state.maps[key];
}
function renderMaps() { Object.keys(MAP_TARGETS).forEach(renderMap); }
function renderMap(key) {
  const m = ensureMap(key); if (!m) return;
  m.layer.clearLayers(); m.me = null;
  const t = currentTrip(), pts = [], stops = (t && t.stops) || [];
  stops.forEach((s) => {
    const lat = Number(s.latitude), lng = Number(s.longitude); if (!isFinite(lat) || !isFinite(lng)) return;
    pts.push([lat, lng]);
    L.marker([lat, lng], { icon: L.divIcon({ className: "", html: `<div class="num-pin">${esc(s.stop_order)}</div>`, iconSize: [26, 26] }) }).bindPopup(esc(s.stop_name)).addTo(m.layer);
  });
  if (pts.length > 1) L.polyline(pts, { color: "#1d4ed8", weight: 3, dashArray: "6 8" }).addTo(m.layer); // joins stops in order; NOT the road path
  const ll = t && t.last_location;
  if (ll && isFinite(Number(ll.latitude)) && isFinite(Number(ll.longitude))) {
    const p = [Number(ll.latitude), Number(ll.longitude)]; pts.push(p);
    L.circleMarker(p, { radius: 9, color: "#15803d", fillColor: "#22c55e", fillOpacity: 0.9 }).bindPopup(`Last stored bus position<br>${esc(fmtDT(ll.recorded_at))}`).addTo(m.layer);
  }
  if (state.gps.lat !== null) { pts.push([state.gps.lat, state.gps.lng]); placeDeviceMarker(m); }
  if (pts.length) m.map.fitBounds(pts, { padding: [30, 30], maxZoom: 16 });
  const [, noteId, labelId] = MAP_TARGETS[key];
  if (labelId) setText(labelId, t ? `${dash(t.route.route_code)} · ${dash(t.route.start_point)} → ${dash(t.route.end_point)}` : "");
  setText(noteId, !t ? "No trip selected, so there is no route to show."
    : !stops.length ? "Stops for this trip are not available."
    : state.gps.status === "active" ? "Your device position is shown in red. The dashed line joins stops in order; it is not the road path."
    : ll ? "Green marker: last bus position stored by the backend. The dashed line joins stops in order; it is not the road path."
    : "GPS not started. No bus position available yet. The dashed line joins stops in order; it is not the road path.");
}
function placeDeviceMarker(m) {
  const p = [state.gps.lat, state.gps.lng];
  if (!m.me) m.me = L.circleMarker(p, { radius: 8, color: "#b91c1c", fillColor: "#ef4444", fillOpacity: 0.9 }).bindPopup("Your device position").addTo(m.layer);
  else m.me.setLatLng(p);
}
function updateDeviceMarkers() { Object.values(state.maps).forEach(placeDeviceMarker); }

/* ---------- trip selection + actions (backend decides every status) ---------- */
async function selectTrip(id) {
  if (state.busy) return;
  const trip = state.available && state.available.find((t) => sameId(t.trip_id, id)); if (!trip) return;
  if (sameId(state.selectedId, id)) return;
  if (state.gps.watchId !== null) { stopGps(false); setMsg("gpsNote", "GPS sharing stopped because you selected a different trip.", ""); }
  state.selectedId = trip.trip_id; state.busy = true; renderAll();
  await fetchServerTrip();
  state.busy = false; renderAll();
  setMsg("tripsMsg", `Trip #${trip.trip_id} selected.`, "ok");
}
async function refreshTrips() {
  if (state.busy || state.loadingTrips) return;
  const before = state.selectedId; await loadTripData();
  if (before !== null && !selectedAvailable() && !(state.serverTrip && sameId(state.serverTrip.trip_id, before))) state.selectedId = null;
  renderAll();
}
async function tripAction(kind) {
  const t = currentTrip(); if (!t || state.busy) return;
  state.busy = true; const btn = $(kind === "start" ? "startTripBtn" : "endTripBtn");
  renderAll(); btn.classList.add("busy"); setMsg("tripMsg", kind === "start" ? "Starting trip…" : "Ending trip…", "");
  try {
    await api(kind === "start" ? ENDPOINTS.start(t.trip_id) : ENDPOINTS.end(t.trip_id), { method: "POST" });
    if (kind === "end") stopGps(false);
    state.selectedId = t.trip_id;
    await loadTripData();   // re-read the real state from the database
    setMsg("tripMsg", kind === "start" ? "Trip started. You can now start GPS sharing." : "Trip ended. GPS sharing has stopped.", "ok");
  } catch (e) { setMsg("tripMsg", e.message, "error"); await loadTripData().catch(() => {}); }
  state.busy = false; btn.classList.remove("busy"); renderAll();
}

/* ---------- GPS (browser Geolocation API -> FastAPI -> Kafka -> PostgreSQL) ---------- */
function startGps() {
  const t = currentTrip();
  if (!t || t.status !== "ACTIVE") { setMsg("gpsNote", "Start your trip first. GPS sharing is only available during an active trip.", "error"); return; }
  if (!("geolocation" in navigator)) { state.gps.status = "error"; setMsg("gpsNote", "This device or browser does not support GPS.", "error"); renderGps(); return; }
  if (state.gps.watchId !== null) return;
  if (!window.isSecureContext) setMsg("gpsNote", "Phones only allow GPS on HTTPS pages (or localhost). Open the dashboard over HTTPS.", "error");
  else setMsg("gpsNote", "Waiting for location permission…", "");
  state.gps.status = "requesting"; state.gps.tripId = t.trip_id; renderGps();
  state.gps.watchId = navigator.geolocation.watchPosition(onGpsSuccess, onGpsError, { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 });
}
function stopGps(silent) {
  if (state.gps.watchId !== null && "geolocation" in navigator) navigator.geolocation.clearWatch(state.gps.watchId);
  state.gps.watchId = null; state.gps.tripId = null; state.gps.status = "not_started";
  if (!silent) { setMsg("gpsNote", "GPS sharing stopped.", ""); renderGps(); }
}
function onGpsSuccess(pos) {
  const g = state.gps; g.status = "active"; g.lat = pos.coords.latitude; g.lng = pos.coords.longitude; g.time = new Date(pos.timestamp).toISOString();
  updateDeviceMarkers(); renderGps();
  if (Date.now() - g.lastSent >= GPS_SEND_INTERVAL_MS) { g.lastSent = Date.now(); sendLocation(pos.coords); }
}
function onGpsError(err) {
  state.gps.status = err.code === 1 ? "denied" : "error";
  setMsg("gpsNote", err.code === 1 ? "Location permission was denied. Allow location access in your browser settings and try again." : "Could not read your location. Check that GPS is turned on.", "error");
  if (state.gps.watchId !== null) { navigator.geolocation.clearWatch(state.gps.watchId); state.gps.watchId = null; }
  renderGps();
}
async function sendLocation(c) {
  const g = state.gps, t = currentTrip();
  if (g.sending || g.tripId === null || !t || t.status !== "ACTIVE" || !sameId(t.trip_id, g.tripId)) return; // never send for scheduled/completed/other trips
  g.sending = true;
  const speed = typeof c.speed === "number" && c.speed >= 0 ? c.speed : null; // m/s, null when unknown
  try {
    await api(ENDPOINTS.location(g.tripId), { method: "POST", body: JSON.stringify({ latitude: c.latitude, longitude: c.longitude, speed }) });
    setMsg("gpsNote", `Location sent to server at ${new Date().toLocaleTimeString()}.`, "ok");
  } catch (e) {
    if (e.status === 409) { stopGps(false); setMsg("gpsNote", e.message, "error"); await loadTripData(); renderAll(); }
    else setMsg("gpsNote", e.status === 404 && e.detail === "Not Found" ? "GPS API integration pending." : e.message, "error");
  } finally { g.sending = false; }
}

/* ---------- navigation + events (bound once) ---------- */
const TITLES = { dashboard: "Driver Dashboard", available: "Available Trips", bus: "My Bus", route: "My Route", trip: "Current Trip", gps: "GPS Tracking", history: "Trip History", notifications: "Notifications", profile: "My Profile", settings: "Settings" };
function closeDrawer() { $("sidebar").classList.remove("open"); $("sidebarOverlay").classList.remove("show"); $("mobileMenuBtn").setAttribute("aria-expanded", "false"); }
function toggleDrawer() { const open = $("sidebar").classList.toggle("open"); $("sidebarOverlay").classList.toggle("show", open); $("mobileMenuBtn").setAttribute("aria-expanded", String(open)); }
function showSection(page) {
  if (!TITLES[page]) page = "dashboard";
  $$(".page-section").forEach((s) => s.classList.toggle("active", s.id === `${page}Section`));
  $$(".menu-item[data-page]").forEach((m) => m.classList.toggle("active", m.dataset.page === page));
  setText("pageTitle", TITLES[page]); closeDrawer(); window.scrollTo({ top: 0 });
  if (page === "dashboard" || page === "route") { renderMaps(); setTimeout(() => Object.values(state.maps).forEach((m) => m.map.invalidateSize()), 120); }
  if (page === "settings") showGpsPermission();
}
async function showGpsPermission() {
  let text = "Your browser will ask for location permission when you start GPS sharing.";
  try { if (navigator.permissions) { const p = await navigator.permissions.query({ name: "geolocation" }); text = `Location permission: ${p.state}. Change it in your browser's site settings.`; } } catch (e) { /* unsupported */ }
  setText("setGpsPerm", text);
}
function bindEvents() {
  $$(".menu-item[data-page]").forEach((m) => m.addEventListener("click", (e) => { e.preventDefault(); showSection(m.dataset.page); }));
  document.addEventListener("click", (e) => {
    const open = e.target.closest("[data-open-page]"); if (open) showSection(open.dataset.openPage);
    const sel = e.target.closest("[data-select-trip]"); if (sel) selectTrip(sel.dataset.selectTrip);
  });
  $("mobileMenuBtn").addEventListener("click", toggleDrawer); $("sidebarOverlay").addEventListener("click", closeDrawer);
  $("notifBtn").addEventListener("click", () => showSection("notifications")); $("profileBtn").addEventListener("click", () => showSection("profile"));
  [$("logoutTop"), $("logoutSide"), $("logoutSettings")].forEach((b) => b.addEventListener("click", logout));
  $("refreshTripsBtn").addEventListener("click", refreshTrips);
  $("startTripBtn").addEventListener("click", () => tripAction("start"));
  $("endTripBtn").addEventListener("click", () => { if (confirm("End this trip? GPS sharing will stop.")) tripAction("end"); });
  $("startGpsBtn").addEventListener("click", startGps); $("stopGpsBtn").addEventListener("click", () => stopGps(false));
  window.addEventListener("resize", () => { if (window.innerWidth > 900) closeDrawer(); Object.values(state.maps).forEach((m) => m.map.invalidateSize()); });
  window.addEventListener("pagehide", () => stopGps(true));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeDrawer(); });
  document.addEventListener("error", (e) => { // missing bus photo -> show text fallback instead of a broken image
    const img = e.target;
    if (img && img.tagName === "IMG" && img.hasAttribute("data-fallback")) { img.hidden = true; const f = img.parentElement.querySelector(".photo-fallback"); if (f) f.hidden = false; }
  }, true);
}

async function init() {
  if (!getToken()) { redirectLogin(); return; }
  bindEvents();
  try { state.profile = await api(ENDPOINTS.profile); }  // the backend confirms the DRIVER role (403 otherwise)
  catch (e) {
    $("bootSkeleton").hidden = true;
    if (e.status === 403) { $("deniedPanel").hidden = false; return; }
    showBanner(e.message, true); return;
  }
  $("bootSkeleton").hidden = true; $("appContent").hidden = false;
  renderHeader(); renderProfile(); renderTrips(); renderTrip(); renderDashboard(); renderMaps();
  await initialLoad();
  renderAll();
}
document.addEventListener("DOMContentLoaded", init);