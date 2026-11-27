"use strict";

/* ==========================================================
   Chanakya University Transport - Student Dashboard

   Backend-connected version

   Sections:
   1 Config
   2 Demo data
   3 Application state
   4 Auth
   5 API layer
   6 Helpers
   7 Maps
   8 Live bus updates
   9 Renderers
   10 Navigation & search
   11 Settings
   12 Data loading
   13 Init
   ========================================================== */


/* ==========================================================
   1. CONFIG
   ========================================================== */

const API_BASE_URL = window.API_BASE_URL;

const CONFIG = {
  LOGIN_PAGE: "login.html",

  TOKEN_KEYS: [
    "token",
    "access_token",
    "accessToken",
    "jwt"
  ],

  USER_KEYS: [
    "user",
    "currentUser",
    "student"
  ],

  SETTINGS_KEY: "cu_transport_settings",

  /*
   * GPS polling is intentionally disabled for now.
   * We will enable it after the Driver GPS API is created.
   */
  LIVE_POLL_MS: 10000,

  ENDPOINTS: {
    login: "/auth/login",

    profile: "/students/me",

    buses: "/students/buses",

    routes: "/students/routes",

    routeStops: (routeId) =>
      `/students/routes/${encodeURIComponent(routeId)}/stops`,

    routeBus: (routeId) =>
      `/students/routes/${encodeURIComponent(routeId)}/bus`,

   routeLocation: (routeId) =>
  `/students/me/routes/${encodeURIComponent(routeId)}/bus/location`,

    timetable: "/students/me/timetable",

    notifications: "/notifications/"

    /*
     * Do NOT use:
     *
     * /buses/{busNumber}
     * /buses/{busNumber}/location
     *
     * Those endpoints do not exist in the current backend.
     */
  }
};


/* ==========================================================
   2. DEMO DATA
   Used only if the main route API is unavailable.
   No fake GPS position is used.
   ========================================================== */

const DEMO_DATA = {

  routes: [
    {
      id: 5,
      type: "route",
      code: "R002",
      name: "University Main Route",
      bus_number: "BUS-001",
      direction: "City Center → University Campus",

      stops: [
        "Main Gate",
        "City Mall",
        "University Gate"
      ],

      current_stop: null,
      next_stop: null,
      eta_minutes: null,
      status: "scheduled"
    }
  ],

  buses: {
    "BUS-001": {
      bus_number: "BUS-001",
      bus_type: "ROUTE_BUS",
      registration_number: "JH01AB1234",
      capacity: 50,
      route_code: "R002",
      driver_name: null,
      status: "scheduled"
    }
  },

  timetable: [],

  notifications: []
};


/* ==========================================================
   3. APPLICATION STATE
   ========================================================== */

const state = {

  user: null,

  routes: [],

  allBuses: [],
  facultyStops: [],
  liveBuses: [],
  facultyMarkers: {},

  timetable: [],

  notifications: [],

  activeRoute: null,

  usingDemo: false,

  maps: {},

  markers: {},

  stopMarkers: {},

  routeLines: {},

  pollTimer: null,

  searchIndex: []
};


/* ==========================================================
   4. AUTH
   ========================================================== */

function readStorage(keys) {

  for (const store of [localStorage, sessionStorage]) {

    for (const key of keys) {

      const value = store.getItem(key);

      if (value) {
        return value;
      }
    }
  }

  return null;
}

function getToken() {

  return readStorage(CONFIG.TOKEN_KEYS);
}


function getStoredUser() {
  for (const store of [localStorage, sessionStorage]) {
    const token = store.getItem("access_token") ||
                  store.getItem("token") ||
                  store.getItem("accessToken") ||
                  store.getItem("jwt");

    if (!token) continue;

    const raw = CONFIG.USER_KEYS
      .map(key => store.getItem(key))
      .find(Boolean);

    let user = {};
    if (raw) {
      try {
        user = JSON.parse(raw) || {};
      } catch {
        user = { name: raw };
      }
    }

    return {
      ...user,
      id: user.id || store.getItem("user_id"),
      name: user.name || store.getItem("user_name"),
      email: user.email || store.getItem("user_email"),
      role: (
        user.role ||
        user.user_role ||
        store.getItem("user_role") ||
        ""
      ).toUpperCase()
    };
  }

  return null;
}


function requireAuth() {

  if (!getToken() && !getStoredUser()) {

    window.location.replace(CONFIG.LOGIN_PAGE);

    return false;
  }

  return true;
}


function logout() {

  [
    ...CONFIG.TOKEN_KEYS,
    ...CONFIG.USER_KEYS
  ].forEach((key) => {

    localStorage.removeItem(key);

  });

  window.location.replace(CONFIG.LOGIN_PAGE);
}


/* ==========================================================
   5. API LAYER
   ========================================================== */

async function apiFetch(path, options = {}) {

  const headers = {
    Accept: "application/json",
    ...(options.headers || {})
  };

  const token = getToken();

  if (token) {

    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(
    API_BASE_URL + path,
    {
      ...options,
      headers
    }
  );

  if (response.status === 401) {

    logout();

    throw new Error("Session expired");
  }

  if (!response.ok) {

    let message = `Request failed (${response.status})`;

    try {

      const errorData = await response.json();

      if (errorData?.detail) {
        message = errorData.detail;
      }

    } catch (error) {
      // Ignore JSON parsing errors.
    }

    throw new Error(message);
  }

  return response.json();
}


/* Login is handled by login.html */

async function apiLogin(email, password) {

  return apiFetch(
    CONFIG.ENDPOINTS.login,
    {
      method: "POST",

      headers: {
        "Content-Type": "application/json"
      },

      body: JSON.stringify({
        email,
        password
      })
    }
  );
}


/* ---------- Backend API functions ---------- */

const getStudentProfile = () =>
  apiFetch(CONFIG.ENDPOINTS.profile);


const getAllUniversityBuses = () =>
  apiFetch(CONFIG.ENDPOINTS.buses);


const getSubscribedRoutes = () =>
  apiFetch(CONFIG.ENDPOINTS.routes);


const getRouteStops = (routeId) =>
  apiFetch(CONFIG.ENDPOINTS.routeStops(routeId));

const getRouteLocation = (routeId) =>
  apiFetch(CONFIG.ENDPOINTS.routeLocation(routeId));

const getRouteBus = (routeId) =>
  apiFetch(CONFIG.ENDPOINTS.routeBus(routeId));


const getTimetable = () =>
  apiFetch(CONFIG.ENDPOINTS.timetable);


const getNotifications = () =>
  apiFetch(CONFIG.ENDPOINTS.notifications);


/*
 * Generic fallback helper.
 */

async function withFallback(request, fallbackValue) {

  try {

    const data = await request();

    return {
      data,
      demo: false
    };

  } catch (error) {

    console.warn(
      "API request failed:",
      error.message
    );

    return {
      data: fallbackValue,
      demo: true
    };
  }
}


/* ==========================================================
   6. HELPERS
   ========================================================== */

const $ = (id) =>
  document.getElementById(id);


const $$ = (
  selector,
  root = document
) =>
  Array.from(
    root.querySelectorAll(selector)
  );


const setText = (
  id,
  value
) => {

  const element = $(id);

  if (element) {
    element.textContent = value;
  }
};


const esc = (value) =>

  String(value ?? "").replace(
    /[&<>"']/g,
    (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    }[character])
  );


const icon = (name) =>
  `<svg class="ic"><use href="#i-${name}"/></svg>`;


const fmtEta = (minutes) => {

  if (
    minutes === null ||
    minutes === undefined ||
    Number.isNaN(Number(minutes))
  ) {
    return "—";
  }

  const value = Number(minutes);

  if (value >= 60) {

    return `${Math.floor(value / 60)} h ${value % 60} min`;
  }

  return `${value} min`;
};


const STATUS = {

  on_time: {
    label: "On time",
    cls: "ok"
  },

  delayed: {
    label: "Delayed",
    cls: "warn"
  },

  scheduled: {
    label: "Scheduled",
    cls: "info"
  },

  inactive: {
    label: "Not running",
    cls: "muted"
  },

  active: {
    label: "Running",
    cls: "ok"
  },

  gps_offline: {
    label: "GPS Offline",
    cls: "warn"
  },

  gps_live: {
    label: "GPS Live",
    cls: "ok"
  },

  completed: {
    label: "Completed",
    cls: "ok"
  },

  upcoming: {
    label: "Upcoming",
    cls: "info"
  }
};


const routeDisplayStatus = (route) => {
  if (route?.gpsOnline === false) {
    return statusOf("gps_offline");
  }
  if (route?.gpsOnline === true) {
    return statusOf("gps_live");
  }
  return statusOf(route?.status);
};


function setRouteGpsStatus(route, isOnline) {
  if (!route) return;

  route.gpsOnline = isOnline;

  const matchingRoute = state.routes.find(
    item => String(item.id) === String(route.id)
  );

  if (matchingRoute) {
    matchingRoute.gpsOnline = isOnline;
  }

  const status = routeDisplayStatus(route);

  document.querySelectorAll("[data-route-status-id]").forEach(element => {
    if (element.dataset.routeStatusId === String(route.id)) {
      element.className = `status-badge ${status.cls}`;
      element.textContent = status.label;
    }
  });

  ["nextBusStatus", "trkBadge"].forEach(id => {
    const element = $(id);
    if (element) {
      element.className = `status-badge ${status.cls}`;
      element.textContent = status.label;
    }
  });
}


const statusOf = (status) => {

  return STATUS[status] || {
    label: status
      ? String(status)
      : "Unknown",

    cls: "muted"
  };
};


const isRunning = (status) => {

  return (
    status === "on_time" ||
    status === "delayed" ||
    status === "active"
  );
};


function timeAgo(notification) {

  const minutes =
    notification.minutes_ago ??
    (
      notification.created_at
        ? Math.max(
            0,
            Math.round(
              (
                Date.now() -
                new Date(
                  notification.created_at
                )
              ) / 60000
            )
          )
        : null
    );

  if (minutes === null) {
    return "";
  }

  if (minutes < 1) {
    return "Just now";
  }

  if (minutes < 60) {
    return `${minutes} min ago`;
  }

  if (minutes < 1440) {
    return `${Math.floor(minutes / 60)} h ago`;
  }

  return `${Math.floor(minutes / 1440)} d ago`;
}


const NOTIF_STYLE = {

  bus: [
    "blue",
    "bus"
  ],

  timetable: [
    "orange",
    "clock"
  ],

  route: [
    "green",
    "check"
  ]
};


const notifStyle = (type) =>

  NOTIF_STYLE[type] || [
    "blue",
    "bell"
  ];


const emptyState = (text) =>
  `<div class="empty-state">${esc(text)}</div>`;


document.addEventListener(
  "error",
  (event) => {

    if (
      event.target &&
      event.target.tagName === "IMG"
    ) {

      event.target.classList.add(
        "img-missing"
      );
    }

  },
  true
);


/* ==========================================================
   7. MAPS
   ========================================================== */

function createMap(
  elementId,
  key
) {

  const element = $(elementId);

  if (
    !element ||
    typeof L === "undefined"
  ) {
    return;
  }

  /*
   * Use first real stop when available.
   * Otherwise use approximate university area.
   */
  const defaultStart = [
    13.219992,
    77.753943
  ];

  const map = L
    .map(element)
    .setView(
      defaultStart,
      15
    );

  L.tileLayer(
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    {
      maxZoom: 19,
      attribution:
        "&copy; OpenStreetMap contributors"
    }
  ).addTo(map);

  state.maps[key] = map;
}


function initMaps() {

  createMap(
    "dashboardMap",
    "dashboard"
  );

  createMap(
    "trackingMap",
    "tracking"
  );
}


function refreshMaps() {

  setTimeout(
    () => {

      Object
        .values(state.maps)
        .forEach(
          (map) => map.invalidateSize()
        );

    },
    120
  );
}

//  My Profile section
// Header profile click -> My Profile page

document.addEventListener("DOMContentLoaded", () => {
    const profileMini = document.getElementById("profileMini");

    if (profileMini) {
        profileMini.addEventListener("click", () => {
            const profileMenu = document.querySelector('.menu-item[data-page="profile"]');

            if (profileMenu) {
                profileMenu.click();
            }
        });

        // Keyboard accessibility
        profileMini.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();

                const profileMenu = document.querySelector('.menu-item[data-page="profile"]');

                if (profileMenu) {
                    profileMenu.click();
                }
            }
        });
    }
});
/* ---------- Route stop markers ---------- */

function renderRouteStopsOnMap(
  route
) {

  if (
    !route ||
    !route.stopsData ||
    !route.stopsData.length
  ) {
    return;
  }

  // Ignore stops without GPS coordinates (0,0 placeholders).
  const validStops = route.stopsData.filter(
    (stop) =>
      Number.isFinite(stop.latitude) &&
      Number.isFinite(stop.longitude) &&
      stop.latitude >= -90 &&
      stop.latitude <= 90 &&
      stop.longitude >= -180 &&
      stop.longitude <= 180 &&
      !(stop.latitude === 0 && stop.longitude === 0)
  );

  const coordinates = validStops.map(
    (stop) => [
      stop.latitude,
      stop.longitude
    ]
  );

  if (!coordinates.length) {
    return;
  }


  Object.entries(
    state.maps
  ).forEach(
    ([key, map]) => {

      /*
       * Remove old stop markers.
       */

      if (state.stopMarkers[key]) {

        state.stopMarkers[key].forEach(
          (marker) => map.removeLayer(marker)
        );
      }

      state.stopMarkers[key] = [];


      /*
       * Remove old route line.
       */

      if (state.routeLines[key]) {

        map.removeLayer(
          state.routeLines[key]
        );
      }


      /*
       * Create stop markers.
       */

      validStops.forEach(
        (stop) => {

          const marker =
            L.marker([
              stop.latitude,
              stop.longitude
            ])
            .addTo(map)
            .bindPopup(
              `<strong>${esc(stop.stop_name)}</strong><br>
               Stop ${esc(stop.stop_order)}`
            );

          state.stopMarkers[key].push(
            marker
          );
        }
      );


      /*
       * Add Devanahalli common reference marker.
       * This marker is separate from actual bus stops and route line.
       */

      const devanahalliIcon = L.divIcon({
        className: "devanahalli-marker-icon",
        html: `
          <div style="
            width: 34px;
            height: 34px;
            background: linear-gradient(135deg, #38bdf8, #2563eb);
            border: 3px solid #ffffff;
            border-radius: 50% 50% 50% 0;
            transform: rotate(-45deg);
            box-shadow: 0 3px 12px rgba(37, 99, 235, 0.55);
            display: flex;
            align-items: center;
            justify-content: center;
          ">
            <div style="
              width: 10px;
              height: 10px;
              background: #ffffff;
              border-radius: 50%;
            "></div>
          </div>
        `,
        iconSize: [40, 40],
        iconAnchor: [17, 38],
        popupAnchor: [0, -38]
      });

      const devanahalliMarker = L.marker(
        [13.244561, 77.713652],
        { icon: devanahalliIcon, title: "Devanahalli" }
      )
        .addTo(map)
        .bindPopup(`
          <div style="min-width: 180px;">
            <strong style="font-size: 15px; color: #2563eb;">
              Devanahalli
            </strong>
            <div style="margin-top: 5px;">
              Common Reference Point
            </div>
            <small style="color: #64748b;">
              13.244561, 77.713652
            </small>
          </div>
        `);

      state.stopMarkers[key].push(devanahalliMarker);


      /*
       * Draw route line.
       */

      state.routeLines[key] =
        L.polyline(
          coordinates,
          {
            weight: 5,
            opacity: 0.8
          }
        ).addTo(map);


      /*
       * Fit map to route.
       */

      if (coordinates.length > 1) {

        map.fitBounds(
          L.latLngBounds(
            coordinates.concat([
              [13.244561, 77.713652]
            ])
          ),
          {
            padding: [
              30,
              30
            ]
          }
        );

      } else {

        map.setView(
          coordinates[0],
          16
        );
      }

    }
  );
}


/* ==========================================================
   8. LIVE BUS UPDATES
   ========================================================== */


/*
 * IMPORTANT:
 *
 * Real GPS API is not available yet.
 *
 * Therefore this function does NOT create fake
 * moving bus positions.
 *
 * It will be connected later when:
 *
 * Driver Phone GPS
 *       ↓
 * FastAPI GPS API
 *       ↓
 * bus_locations
 *       ↓
 * Student Dashboard
 */


function updateBusLocation(
  latitude,
  longitude,
  isPlaceholder = false
) {

  if (
    typeof latitude !== "number" ||
    typeof longitude !== "number"
  ) {
    return;
  }

  Object.entries(
    state.maps
  ).forEach(
    ([key, map]) => {

      const label =
        isPlaceholder
          ? "Demo position"
          : "Bus location";


      if (!state.markers[key]) {

        state.markers[key] =
          L.marker([
            latitude,
            longitude
          ]).addTo(map);
      }


      state.markers[key]
        .setLatLng([
          latitude,
          longitude
        ])
        .bindPopup(label);


      map.panTo([
        latitude,
        longitude
      ]);

    }
  );


  setText(
    "mapUpdated",
    isPlaceholder
      ? "Demo position"
      : `Updated ${new Date().toLocaleTimeString()}`
  );


  setText(
    "trkMessage",
    isPlaceholder
      ? "Showing demo position"
      : "GPS location received"
  );


  const liveDot =
    $("liveDot");

  if (liveDot) {

    liveDot.classList.toggle(
      "on",
      !isPlaceholder
    );
  }


  const trackingMessage =
    $("trkMessage");

  if (trackingMessage) {

    trackingMessage.classList.toggle(
      "on",
      !isPlaceholder
    );
  }
}


function updateETA(
  eta
) {

  const text =
    fmtEta(eta);

  setText(
    "nextBusEta",
    text
  );

  setText(
    "trkEta",
    text
  );

  setText(
    "statNext",
    text
  );
}


function updateCurrentStop(
  stop
) {

  const text =
    stop || "—";

  setText(
    "nextBusStop",
    text
  );

  setText(
    "trkCurrent",
    text
  );

  setText(
    "statNextStop",
    stop
      ? `At ${stop}`
      : "GPS pending"
  );
}


function updateNextStop(
  stop
) {

  setText(
    "trkNext",
    stop || "—"
  );
}


function setBusPhotos(route) {
  if (!route) return;

  const bus = route.busData || {};
  const photoPath =
    route.front_photo ||
    bus.front_photo ||
    route.side_photo ||
    bus.side_photo ||
    null;

  const fallback = "../photo/bus.jpg";

  [
    "dashboardBusPhoto",
    "trackingBusPhoto",
    "detailsBusPhoto"
  ].forEach((id) => {
    const img = $(id);
    if (!img) return;

    img.onerror = () => {
      img.onerror = null;
      img.src = fallback;
    };

    img.src = photoPath
      ? API_BASE_URL + photoPath
      : fallback;
  });
}


function updateBusInfo(
  busData
) {

  if (!busData) {
    return;
  }

  const s =
    statusOf(
      busData.status
    );


  setText(
    "nextBusNumber",
    busData.bus_number || "—"
  );

  setText(
    "trkBus",
    busData.bus_number || "—"
  );

  setText(
    "mapBusLabel",
    busData.bus_number || "—"
  );


  const routeText =
    busData.route_code
      ? `Route ${busData.route_code}`
      : "—";


  setText(
    "nextBusRoute",
    routeText
  );

  setText(
    "trkRoute",
    routeText
  );


  [
    [
      "nextBusStatus",
      "status-badge"
    ],
    [
      "trkBadge",
      "status-badge"
    ]
  ].forEach(
    ([id, base]) => {

      const element = $(id);

      if (!element) {
        return;
      }

      element.className =
        `${base} ${s.cls}`;

      element.textContent =
        s.label;
    }
  );


  if (
    "current_stop" in busData
  ) {

    updateCurrentStop(
      busData.current_stop
    );
  }


  if (
    "next_stop" in busData
  ) {

    updateNextStop(
      busData.next_stop
    );
  }


  if (
    "eta_minutes" in busData
  ) {

    updateETA(
      busData.eta_minutes
    );
  }
}




function facultyGpsAge(value) {
  if (!value) return "No GPS update";
  let raw = String(value);
  if (!/[zZ]|[+-]\d{2}:?\d{2}$/.test(raw)) raw += "Z";
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return "Time unavailable";
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  return `${Math.floor(seconds / 3600)}h ago`;
}

function facultySpeed(speed) {
  const value = Number(speed);
  return Number.isFinite(value) && value >= 0
    ? `${(value * 3.6).toFixed(1)} km/h` : "—";
}

function facultyDistance(distance) {
  const value = Number(distance);
  if (!Number.isFinite(value) || value < 0) return "—";
  return value >= 1000
    ? `${(value / 1000).toFixed(2)} km`
    : `${Math.round(value)} m`;
}

function facultyEta(minutes) {
  const value = Number(minutes);
  return Number.isFinite(value) && value >= 0
    ? `${Math.max(1, Math.round(value))} min` : "—";
}

function renderFacultyFleet() {
  const buses = state.liveBuses || [];
  const online = buses.filter(bus => {
    const lat = Number(bus.latitude), lng = Number(bus.longitude);
    return bus.gps_online === true &&
      Number.isFinite(lat) && Number.isFinite(lng) &&
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
      !(lat === 0 && lng === 0);
  });

  const panel = $("facultyFleetPanel");
  if (panel) panel.hidden = false;

  setText("facultyFleetCount", `${buses.length} buses`);
  setText("facultyFleetStatus",
    `${online.length} online · ${buses.length - online.length} offline or stale`);

  const list = $("facultyFleetList");
  if (list) {
    list.innerHTML = buses.length ? buses.map(bus => {
      const lat = Number(bus.latitude), lng = Number(bus.longitude);
      const valid = Number.isFinite(lat) && Number.isFinite(lng) &&
        lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
        !(lat === 0 && lng === 0);
      const fresh = bus.gps_online === true && valid;
      const status = fresh ? "GPS Online" : valid ? "GPS Stale" : "GPS Offline";

      return `<article class="faculty-fleet-card">
        <div class="faculty-fleet-card-head">
          <strong>${esc(bus.bus_number || "University Bus")}</strong>
          <span class="status-badge ${fresh ? "ok" : "warn"}">${status}</span>
        </div>
        <p>${esc(bus.route_name || "Route unavailable")}</p>
        <small>Driver: ${esc(bus.driver_name || "Unassigned")}</small>
        <div class="faculty-fleet-metrics">
          <div><span>Speed</span><strong>${facultySpeed(bus.speed)}</strong></div>
          <div><span>Current stop</span><strong>${esc(bus.current_stop || "—")}</strong></div>
          <div><span>Next stop</span><strong>${esc(bus.next_stop || "—")}</strong></div>
          <div><span>Distance to next</span><strong>${facultyDistance(bus.distance_to_next_stop_m)}</strong></div>
          <div><span>Approx. ETA</span><strong>${facultyEta(bus.eta_minutes)}</strong></div>
          <div><span>GPS updated</span><strong>${facultyGpsAge(bus.recorded_at)}</strong></div>
        </div>
        <small>Last update: ${esc(bus.recorded_at || "Not available")}</small>
      </article>`;
    }).join("") : `<div class="empty-state">No active buses are available right now.</div>`;
  }

  // Use the existing tracking map, but maintain a separate marker per bus.
  const map = state.maps.tracking;
  if (!map || typeof L === "undefined") return;

  const previousKeys = Object.keys(state.facultyMarkers);
  const hadMarkers = previousKeys.length > 0;
  const activeKeys = new Set();

  online.forEach(bus => {
    const key = String(bus.trip_id ?? bus.bus_id ?? bus.bus_number);
    activeKeys.add(key);
    const lat = Number(bus.latitude), lng = Number(bus.longitude);

    const popup = `
      <div class="faculty-fleet-popup">
        <strong>${esc(bus.bus_number || "Bus")}</strong>
        <div>${esc(bus.route_name || "Route unavailable")}</div>
        <div>Driver: ${esc(bus.driver_name || "Unassigned")}</div>
        <div>Speed: ${facultySpeed(bus.speed)}</div>
        <div>Current stop: ${esc(bus.current_stop || "—")}</div>
        <div>Next stop: ${esc(bus.next_stop || "—")}</div>
        <div>Distance: ${facultyDistance(bus.distance_to_next_stop_m)}</div>
        <div>Approx. ETA: ${facultyEta(bus.eta_minutes)}</div>
        <div>Updated: ${facultyGpsAge(bus.recorded_at)}</div>
      </div>`;

    if (!state.facultyMarkers[key]) {
      state.facultyMarkers[key] = L.marker([lat, lng]).addTo(map);
    } else {
      state.facultyMarkers[key].setLatLng([lat, lng]);
    }
    state.facultyMarkers[key].bindPopup(popup);
  });

  Object.entries(state.facultyMarkers).forEach(([key, marker]) => {
    if (!activeKeys.has(key)) {
      map.removeLayer(marker);
      delete state.facultyMarkers[key];
    }
  });

  if (!hadMarkers && online.length) {
    const points = online.map(bus => [
      Number(bus.latitude), Number(bus.longitude)
    ]);
    if (points.length === 1) map.setView(points[0], 15);
    else map.fitBounds(L.latLngBounds(points), { padding: [30, 30] });
  }
}

async function pollLiveLocation() {
  const role = String(state.user?.role || "").toUpperCase();

  if (role === "FACULTY") {
    if (state.facultyPollInFlight) return;
    state.facultyPollInFlight = true;
    try {
      const response = await apiFetch("/faculty/live-buses");
      state.liveBuses = facultyList(response, ["live_buses", "buses"]);

      // Sync every faculty dashboard route card with fresh fleet GPS data.
      if (Array.isArray(state.routes)) {
        state.routes.forEach(route => {
          const busNumber = route.bus_number || route.busData?.bus_number;
          if (!busNumber) return;

          const liveBus = state.liveBuses.find(bus =>
            String(bus.bus_number) === String(busNumber)
          );

          if (liveBus) {
            route.gpsOnline = liveBus.gps_online === true;
          }
        });

        renderDashRoutes();
      }

      // Sync the selected faculty route with its live fleet GPS data.
      const activeRoute = state.activeRoute;
      if (activeRoute) {
        const liveBus = state.liveBuses.find(bus =>
          String(bus.bus_number) === String(
            activeRoute.bus_number || activeRoute.busData?.bus_number
          )
        );

        if (liveBus) {
          activeRoute.liveLocation = {
            latitude: liveBus.latitude,
            longitude: liveBus.longitude,
            speed: liveBus.speed,
            recorded_at: liveBus.recorded_at
          };
          activeRoute.gpsOnline = liveBus.gps_online === true;
          activeRoute.current_stop = liveBus.current_stop;
          activeRoute.next_stop = liveBus.next_stop;
          activeRoute.distance_to_next_stop_m = liveBus.distance_to_next_stop_m;
          activeRoute.eta_minutes = liveBus.eta_minutes;

          // Render the selected faculty route and its live bus position.
          const liveLatitude = Number(liveBus.latitude);
          const liveLongitude = Number(liveBus.longitude);

          if (
            Number.isFinite(liveLatitude) &&
            Number.isFinite(liveLongitude) &&
            liveLatitude >= -90 && liveLatitude <= 90 &&
            liveLongitude >= -180 && liveLongitude <= 180 &&
            !(liveLatitude === 0 && liveLongitude === 0)
          ) {
            const facultyMapRouteKey = `FACULTY:${activeRoute.id}`;

            if (
              Array.isArray(activeRoute.stopsData) &&
              activeRoute.stopsData.length &&
              state.activeMapRouteId !== facultyMapRouteKey
            ) {
              renderRouteStopsOnMap(activeRoute);
              state.activeMapRouteId = facultyMapRouteKey;
              refreshMaps();
            }

            updateBusLocation(liveLatitude, liveLongitude, false);
          }
        }
      }

      renderFacultyFleet();
      renderActiveJourneyTimelines();

      // Faculty: show the nearest upcoming bus arrival.
      const upcoming = state.liveBuses
        .filter(bus =>
          bus.next_stop &&
          bus.eta_minutes !== null &&
          bus.eta_minutes !== undefined &&
          Number.isFinite(Number(bus.eta_minutes)) &&
          Number(bus.eta_minutes) >= 0
        )
        .sort((a, b) => Number(a.eta_minutes) - Number(b.eta_minutes));

      if (upcoming.length) {
        const nearest = upcoming[0];
        setText("statNext", fmtEta(Number(nearest.eta_minutes)));
        setText(
          "statNextStop",
          `${nearest.next_stop} · ${nearest.bus_number || "University Bus"}`
        );
      } else {
        setText("statNext", "—");
        setText("statNextStop", "GPS pending");
      }
    } catch (error) {
      console.warn("Faculty fleet GPS polling failed:", error.message);
      setText("facultyFleetStatus", "Unable to refresh live bus locations");
    } finally {
      state.facultyPollInFlight = false;
    }
    return;
  }

  // Student: refresh the complete university GPS fleet independently
  // of the currently selected/subscribed route.
  try {
    const fleetResponse = await apiFetch("/students/live-buses");
    state.liveBuses = facultyList(fleetResponse, ["live_buses", "buses"]);
    setText(
      "statActive",
      state.liveBuses.filter(bus => bus.gps_online === true).length
    );
  } catch (fleetError) {
    console.warn("Student fleet GPS refresh failed:", fleetError.message);
  }

  const route = state.activeRoute;
  if (!route || !route.id) return;

  try {
    const data = await getRouteLocation(route.id);
    const location = data?.last_location;

    if (!location ||
        typeof location.latitude !== "number" ||
        typeof location.longitude !== "number") {
      setRouteGpsStatus(route, false);
      const dot = $("liveDot");
      const message = $("trkMessage");
      if (dot) dot.classList.remove("on");
      if (message) message.classList.remove("on");
      setText("mapUpdated", "Waiting for GPS location");
      setText("trkMessage", "GPS Offline - location not available");
      return;
    }

    // Render this student's selected/subscribed route on the map.
    if (
      state.maps?.tracking &&
      Array.isArray(route.stopsData) &&
      route.stopsData.length &&
      state.activeMapRouteId !== String(route.id)
    ) {
      renderRouteStopsOnMap(route);
      state.activeMapRouteId = String(route.id);
      refreshMaps();
    }

    // Sync live API journey details with the student dashboard.
    route.current_stop = data.current_stop ?? null;
    route.next_stop = data.next_stop ?? null;
    route.distance_to_next_stop_m = data.distance_to_next_stop_m ?? null;
    route.eta_minutes = data.eta_minutes ?? null;
    route.liveLocation = location;

    updateBusLocation(location.latitude, location.longitude, false);
    const recordedAt = new Date(location.recorded_at);
    const age = (Date.now() - recordedAt.getTime()) / 1000;
    const fresh = Number.isFinite(age) && age >= 0 && age <= 60;

    setRouteGpsStatus(route, fresh);
    route.liveLocation = location;
    renderStudentLiveBusCard();
    renderActiveJourneyTimelines();

    const dot = $("liveDot");
    const message = $("trkMessage");
    if (dot) dot.classList.toggle("on", fresh);
    if (message) message.classList.toggle("on", fresh);

    setText("trkMessage", fresh
      ? "Live GPS received" : "Showing last known GPS location");
    setText("mapUpdated", fresh
      ? "GPS updated recently" : "GPS data is not recent");
  } catch (error) {
    console.warn("GPS polling failed:", error.message);
    setRouteGpsStatus(route, false);
    const dot = $("liveDot");
    const message = $("trkMessage");
    if (dot) dot.classList.remove("on");
    if (message) message.classList.remove("on");
    setText("trkMessage", "GPS Offline - unable to fetch location");
    setText("mapUpdated", "GPS status unavailable");
  }
}

function startLivePolling() {
  clearInterval(state.pollTimer);
  state.pollTimer = null;

  const role = String(state.user?.role || "").toUpperCase();
  if (
    role !== "FACULTY" &&
    role !== "STUDENT" &&
    (!state.activeRoute || !state.activeRoute.id)
  ) {
    return;
  }

  pollLiveLocation();
  state.pollTimer = setInterval(pollLiveLocation, CONFIG.LIVE_POLL_MS);
}

/* ==========================================================
   9. RENDERERS
   ========================================================== */

function renderHeader() {

  const user =
    state.user || {};

  const portalLabel = document.querySelector(".portal-label");
  if (portalLabel) {
    portalLabel.textContent =
      String(user.role || "").toUpperCase() === "FACULTY"
        ? "FACULTY PORTAL"
        : "STUDENT PORTAL";
  }


  const name =
    user.full_name ||
    user.name ||
    user.username ||
    (
      user.email
        ? user.email.split("@")[0]
        : "Student"
    );


  const role =
    user.role
      ? String(user.role)
          .replace(
            /^./,
            (character) =>
              character.toUpperCase()
          )
      : "Student";


  const initial =
    name
      .charAt(0)
      .toUpperCase();


  const hour =
    new Date().getHours();


  setText(
    "headerUserName",
    name
  );

  setText(
    "headerUserRole",
    role
  );

  setText(
    "headerAvatar",
    initial
  );

  setText(
    "welcomeName",
    name
  );

  setText(
    "profileName",
    name
  );

  setText(
    "profileRole",
    role
  );

  setText(
    "profileAvatar",
    initial
  );


  setText(
    "welcomeGreeting",

    hour < 12
      ? "Good morning"
      : hour < 17
        ? "Good afternoon"
        : "Good evening"
  );


  setText(
    "todayDate",

    new Date().toLocaleDateString(
      undefined,
      {
        weekday: "long",
        day: "numeric",
        month: "long",
        year: "numeric"
      }
    )
  );
}


/* ---------- Stats ---------- */

function renderStats() {
  const role = String(state.user?.role || "").toUpperCase();

  if (role === "FACULTY") {
    const buses = state.liveBuses || [];

    setText("statRoutes", state.routes.length);
    setText(
      "statActive",
      buses.filter(bus => bus.gps_online === true).length
    );
    setText("statTrips", state.timetable.length);

    const upcoming = buses
      .filter(bus =>
        bus.next_stop &&
        bus.eta_minutes !== null &&
        bus.eta_minutes !== undefined &&
        Number.isFinite(Number(bus.eta_minutes)) &&
        Number(bus.eta_minutes) >= 0
      )
      .sort((a, b) => Number(a.eta_minutes) - Number(b.eta_minutes));

    if (upcoming.length) {
      const nearest = upcoming[0];
      setText("statNext", fmtEta(Number(nearest.eta_minutes)));
      setText(
        "statNextStop",
        `${nearest.next_stop} · ${nearest.bus_number || "University Bus"}`
      );
    } else {
      setText("statNext", "—");
      setText("statNextStop", "GPS pending");
    }
    return;
  }

  const running = state.routes.filter(route => isRunning(route.status));

  const etas = state.routes
    .map(route => route.eta_minutes)
    .filter(minutes => typeof minutes === "number");

  const next = state.routes
    .filter(route => typeof route.eta_minutes === "number")
    .sort((a, b) => a.eta_minutes - b.eta_minutes)[0];

  setText("statRoutes", state.routes.length);
  const onlineBuses = (state.liveBuses || [])
    .filter(bus => bus.gps_online === true);
  setText("statActive", onlineBuses.length);
  setText("statTrips", state.timetable.length);
  setText("statNext", etas.length ? fmtEta(Math.min(...etas)) : "—");
  setText(
    "statNextStop",
    next && next.current_stop ? `At ${next.current_stop}` : "GPS pending"
  );
}

/* ---------- Dashboard route list ---------- */

function renderDashRoutes() {

  const container =
    $("dashRouteList");

  if (!container) {
    return;
  }


  container.innerHTML =
    state.routes.length

      ? state.routes
          .map(
            (route) => {

              const status =
                routeDisplayStatus(route);


              return `
                <div class="route-item" data-route-id="${esc(route.id)}" role="button" tabindex="0">

                  <div class="route-bus-image">
                    <img
                      src="${esc((route.front_photo || route.side_photo) ? API_BASE_URL + (route.front_photo || route.side_photo) : "../images/university-bus.jpg")}"
                      alt=""
                    >
                  </div>

                  <div class="route-info">

                    <div class="route-top">

                      <strong>
                        ${esc(route.name)}
                      </strong>

                      <span
                        class="status-badge ${status.cls}" data-route-status-id="${esc(route.id)}"
                      >
                        ${esc(status.label)}
                      </span>

                    </div>

                    <span class="route-code">
                      ${esc(route.code)}
                      ·
                      ${esc(route.bus_number || "Bus pending")}
                    </span>

                    <p>
                      ${esc(route.direction)}
                    </p>

                  </div>

                  <div class="route-action">

                    <strong>
                      ${esc(
                        fmtEta(
                          route.eta_minutes
                        )
                      )}
                    </strong>

                    <span>
                      ETA
                    </span>

                  </div>

                </div>
              `;
            }
          )
          .join("")

      : emptyState(
          "No routes subscribed yet."
        );
}


/* ---------- Route card ---------- */

function routeCardHTML(route) {

  const status =
    routeDisplayStatus(route);


  const directionParts =
    String(
      route.direction || ""
    )
      .split("→")
      .map(
        (value) =>
          value.trim()
      );


  const from =
    directionParts[0];


  const to =
    directionParts[1];


  const isShuttle =
    route.type === "shuttle";


  return `
    <article class="large-route-card">

      <div class="large-bus-photo">

        <img
          src="${esc((route.front_photo || route.side_photo) ? API_BASE_URL + (route.front_photo || route.side_photo) : "../images/university-bus.jpg")}"
          alt="${esc(route.name)}"
        >

        <span
          class="status-badge photo-status ${status.cls}"
        >
          ${esc(status.label)}
        </span>

      </div>


      <div class="large-route-content">

        <div class="route-card-heading">

          <div>

            <span class="small-label">
              ${isShuttle
                ? "Shuttle bus"
                : "Route bus"}
            </span>

            <h3>
              ${esc(route.name)}
            </h3>

            <span class="route-code-big">
              ${esc(route.code)}
              ·
              ${esc(
                route.bus_number ||
                "Bus pending"
              )}
            </span>

          </div>


          <span
            class="status-badge ${status.cls}" data-route-status-id="${esc(route.id)}"
          >
            ${esc(status.label)}
          </span>

        </div>


        <div class="route-path">

          <div>

            <span>
              From
            </span>

            <strong>
              ${esc(from || "—")}
            </strong>

          </div>


          <div class="path-arrow">
            ${icon("arrow")}
          </div>


          <div>

            <span>
              To
            </span>

            <strong>
              ${esc(to || "—")}
            </strong>

          </div>

        </div>


        <div class="route-details">

          <div>

            <span>
              Current stop
            </span>

            <strong>
              ${esc(
                route.current_stop ||
                "GPS pending"
              )}
            </strong>

          </div>


          <div>

            <span>
              Next stop
            </span>

            <strong>
              ${esc(
                route.next_stop ||
                "GPS pending"
              )}
            </strong>

          </div>


          <div>

            <span>
              ETA
            </span>

            <strong class="blue-text">
              ${esc(
                fmtEta(
                  route.eta_minutes
                )
              )}
            </strong>

          </div>

        </div>


        ${
          isShuttle

            ? `
              <button
                class="outline-wide-btn"
                data-open-page="timetable"
                type="button"
              >
                View timetable
              </button>
            `

            : `
              <button
                class="primary-btn route-track-btn"
                data-open-page="tracking"
                data-route-id="${esc(route.id)}"
                type="button"
              >
                Track live bus
                ${icon("arrow")}
              </button>
            `
        }

      </div>

    </article>
  `;
}


/* ---------- Routes page ---------- */

function renderRoutesPage(
  filter = ""
) {

  const query =
    filter
      .trim()
      .toLowerCase();


  const list =
    state.routes.filter(
      (route) => {

        const searchable = [

          route.name,

          route.code,

          route.bus_number,

          route.direction,

          ...(route.stops || [])

        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();


        return (
          !query ||
          searchable.includes(query)
        );
      }
    );


  $("routesGrid").innerHTML =

    list.length

      ? list
          .map(routeCardHTML)
          .join("")

      : emptyState(
          query
            ? "No routes match your filter."
            : "No routes subscribed yet."
        );
}


/* ---------- Timetable ---------- */

function tripRowStyle(
  status
) {

  return (
    status === "completed"
      ? "completed"
      : status === "upcoming"
        ? "active"
        : ""
  );
}


function renderTrips() {

  $("dashTrips").innerHTML =

    state.timetable.length

      ? state.timetable
          .slice(0, 4)
          .map(
            (trip) => {

              const status =
                statusOf(
                  trip.status
                );


              return `
                <div
                  class="timeline-item ${tripRowStyle(trip.status)}"
                >

                  <div class="timeline-time">
                    ${esc(trip.time)}
                  </div>

                  <div class="timeline-line">
                    <span></span>
                  </div>

                  <div class="timeline-info">

                    <strong>
                      ${esc(
                        trip.bus_number ||
                        "Bus"
                      )}
                    </strong>

                    <span>
                      ${esc(
                        trip.direction ||
                        ""
                      )}
                    </span>

                  </div>

                  <span
                    class="trip-status ${status.cls}"
                  >
                    ${esc(status.label)}
                  </span>

                </div>
              `;
            }
          )
          .join("")

      : emptyState(
          "No trips scheduled today."
        );
}


function renderTimetable() {
  const trips = Array.isArray(state.timetable) ? state.timetable : [];

  setText("timetableCount", `${trips.length} schedules`);

  const outbound = trips.filter(
    trip => String(trip.direction || "").toUpperCase() === "OUTBOUND"
  );

  const returning = trips.filter(
    trip => String(trip.direction || "").toUpperCase() === "RETURN"
  );

  const renderRows = (items) => items.length
    ? items.map(trip => {
        const status = statusOf(trip.status);
        return `
          <div class="split-schedule-row">
            <span class="schedule-time">${esc(trip.time || trip.departure_time || "—")}</span>
            <span class="schedule-bus">${esc(trip.bus_number || "—")}</span>
            <span class="schedule-route">${esc(trip.route_code || "—")}</span>
            <span><span class="status-badge ${status.cls}">${esc(status.label)}</span></span>
          </div>
        `;
      }).join("")
    : `<div class="split-schedule-empty">No schedules available.</div>`;

  $("timetableBody").innerHTML = `
    <section class="direction-schedule outbound-schedule">
      <div class="direction-schedule-heading">
        <div class="direction-heading-icon">↗</div>
        <div>
          <h3>Outbound – Going to University</h3>
          <p>Buses travelling to the University</p>
        </div>
        <span class="direction-count">${outbound.length} schedules</span>
      </div>
      <div class="split-schedule-header">
        <span>Time</span><span>Bus</span><span>Route</span><span>Status</span>
      </div>
      ${renderRows(outbound)}
    </section>

    <section class="direction-schedule return-schedule">
      <div class="direction-schedule-heading">
        <div class="direction-heading-icon">↙</div>
        <div>
          <h3>Return – Going Back</h3>
          <p>Buses returning from the University</p>
        </div>
        <span class="direction-count">${returning.length} schedules</span>
      </div>
      <div class="split-schedule-header">
        <span>Time</span><span>Bus</span><span>Route</span><span>Status</span>
      </div>
      ${renderRows(returning)}
    </section>
  `;
}


/* ---------- Notifications ---------- */

function renderNotifications() {

  const unread =
    state.notifications.filter(
      (notification) =>
        !notification.read
    ).length;


  const navCount =
    $("navNotifCount");


  if (navCount) {

    navCount.textContent =
      unread;

    navCount.hidden =
      unread === 0;
  }


  const notificationDot =
    $("notificationDot");


  if (notificationDot) {

    notificationDot.hidden =
      unread === 0;
  }


  setText(
    "notifPageCount",
    `${unread} new`
  );


  $("dashNotifs").innerHTML =

    state.notifications.length

      ? state.notifications
          .slice(0, 3)
          .map(
            (notification) => {

              const [
                color,
                notificationIcon
              ] =
                notifStyle(
                  notification.type
                );


              return `
                <div class="notification-item">

                  <div
                    class="notification-icon ${color}"
                  >
                    ${icon(notificationIcon)}
                  </div>

                  <div>

                    <strong>
                      ${esc(
                        notification.title
                      )}
                    </strong>

                    <span>
                      ${esc(
                        notification.message
                      )}
                    </span>

                  </div>

                </div>
              `;
            }
          )
          .join("")

      : emptyState(
          "No notifications."
        );


  $("notificationsList").innerHTML =

    state.notifications.length

      ? state.notifications
          .map(
            (notification) => {

              const [
                color,
                notificationIcon
              ] =
                notifStyle(
                  notification.type
                );


              return `
                <div
                  class="dashboard-card notification-large ${
                    notification.read
                      ? ""
                      : "unread"
                  }"
                >

                  <div
                    class="notification-icon ${color}"
                  >
                    ${icon(notificationIcon)}
                  </div>

                  <div>

                    <strong>
                      ${esc(
                        notification.title
                      )}
                    </strong>

                    <p>
                      ${esc(
                        notification.message
                      )}
                    </p>

                    <span>
                      ${esc(
                        timeAgo(
                          notification
                        )
                      )}
                    </span>

                  </div>

                </div>
              `;
            }
          )
          .join("")

      : emptyState(
          "You have no notifications."
        );
}



/* ---------- Railway-style live journey timeline ---------- */

function calculateLiveJourneyProgress(route, stops) {
  const gps = route?.liveLocation;
  if (!gps || !Array.isArray(stops) || !stops.length) return null;

  const lat = Number(gps.latitude);
  const lon = Number(gps.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const valid = stops.map((stop, index) => ({
    stop,
    index,
    lat: Number(stop.latitude ?? stop.stop_latitude ?? stop.lat),
    lon: Number(stop.longitude ?? stop.stop_longitude ?? stop.lng ?? stop.lon)
  })).filter(x => Number.isFinite(x.lat) && Number.isFinite(x.lon));

  if (!valid.length) return null;

  const rad = Math.PI / 180;
  const distance = (aLat, aLon, bLat, bLon) => {
    const dLat = (bLat - aLat) * rad;
    const dLon = (bLon - aLon) * rad;
    const h = Math.sin(dLat / 2) ** 2 +
      Math.cos(aLat * rad) * Math.cos(bLat * rad) *
      Math.sin(dLon / 2) ** 2;
    return 6371 * 2 * Math.asin(Math.sqrt(h));
  };

  let nearest = valid[0];
  let nearestKm = distance(lat, lon, nearest.lat, nearest.lon);

  for (const item of valid.slice(1)) {
    const km = distance(lat, lon, item.lat, item.lon);
    if (km < nearestKm) {
      nearest = item;
      nearestKm = km;
    }
  }

  const next = valid.find(x => x.index > nearest.index);
  if (!next) {
    return {
      currentStop: nearest.stop.stop_name || "Last stop",
      currentStopIndex: nearest.index,
      nextStop: "Destination reached",
      nextDistanceKm: 0,
      nextStopIndex: -1
    };
  }

  return {
    currentStop: nearest.stop.stop_name || `Stop ${nearest.index + 1}`,
    currentStopIndex: nearest.index,
    nextStop: next.stop.stop_name || `Stop ${next.index + 1}`,
    nextDistanceKm: distance(lat, lon, next.lat, next.lon),
    nextStopIndex: next.index
  };
}

function renderJourneyTimeline(route, targetId) {
  const target = $(targetId);
  if (!target) return;

  if (!route) {
    target.innerHTML = emptyState("No route assigned.");
    return;
  }

  const stops = Array.isArray(route.stopsData)
    ? [...route.stopsData].sort(
        (a, b) => Number(a.stop_order || 0) - Number(b.stop_order || 0)
      )
    : [];

  if (!stops.length) {
    target.innerHTML = emptyState("Route stop timetable is not available.");
    return;
  }

  const bus = route.busData || {};
  const liveProgress = calculateLiveJourneyProgress(route, stops);

  const current = String(
    route.current_stop || bus.current_stop || liveProgress?.currentStop || ""
  ).trim().toLowerCase();

  const next = String(
    route.next_stop || bus.next_stop || liveProgress?.nextStop || ""
  ).trim().toLowerCase();

  // Prefer the backend's actual live stop names over local GPS estimates.
  const currentIndexFromApi = current
    ? stops.findIndex(stop =>
        String(stop.stop_name || "").trim().toLowerCase() === current
      )
    : -1;

  const currentIndex = currentIndexFromApi >= 0
    ? currentIndexFromApi
    : Number.isInteger(liveProgress?.currentStopIndex)
      ? liveProgress.currentStopIndex : -1;

  // The next stop must occur after the current stop in route order.
  const nextIndexFromApi = next
    ? stops.findIndex((stop, index) =>
        index > currentIndex &&
        String(stop.stop_name || "").trim().toLowerCase() === next
      )
    : -1;

  const nextIndex = nextIndexFromApi >= 0
    ? nextIndexFromApi
    : Number.isInteger(liveProgress?.nextStopIndex)
      ? liveProgress.nextStopIndex : -1;

  // Use real GPS coordinates to distinguish being at a stop from travelling
  // between two stops.
  const liveGps = route.liveLocation || {};
  const gpsLat = Number(liveGps.latitude);
  const gpsLon = Number(liveGps.longitude);
  const gpsValid = Number.isFinite(gpsLat) && Number.isFinite(gpsLon) &&
    gpsLat >= -90 && gpsLat <= 90 &&
    gpsLon >= -180 && gpsLon <= 180 &&
    !(gpsLat === 0 && gpsLon === 0);

  const currentRow = stops[currentIndex];
  const nextRow = stops[nextIndex];
  const currentDisplay = currentRow?.stop_name || route.current_stop || "";
  const nextDisplay = nextRow?.stop_name || route.next_stop || "";

  const distanceToStopKm = (row) => {
    if (!row || !gpsValid) return null;
    const stopLat = Number(row.latitude ?? row.stop_latitude ?? row.lat);
    const stopLon = Number(row.longitude ?? row.stop_longitude ?? row.lon);
    if (!Number.isFinite(stopLat) || !Number.isFinite(stopLon) ||
        stopLat < -90 || stopLat > 90 ||
        stopLon < -180 || stopLon > 180) return null;

    const rad = Math.PI / 180;
    const dLat = (stopLat - gpsLat) * rad;
    const dLon = (stopLon - gpsLon) * rad;
    const h = Math.sin(dLat / 2) ** 2 +
      Math.cos(gpsLat * rad) * Math.cos(stopLat * rad) *
      Math.sin(dLon / 2) ** 2;
    return 6371 * 2 * Math.asin(Math.sqrt(h));
  };

  const distanceFromCurrentKm = distanceToStopKm(currentRow);
  const distanceToNextKm = distanceToStopKm(nextRow);

  const gpsOnline = route.gpsOnline === true ||
    route.gps_available === true;

  const busBetweenStops = gpsOnline && gpsValid &&
    currentIndex >= 0 && nextIndex > currentIndex &&
    distanceFromCurrentKm !== null && distanceFromCurrentKm > 0.2 &&
    distanceToNextKm !== null && distanceToNextKm > 0.2;

  const gpsCoordinates = gpsValid
    ? `${gpsLat.toFixed(5)}, ${gpsLon.toFixed(5)}`
    : "";

  const livePositionText = !gpsValid
    ? "Waiting for live GPS"
    : `${busBetweenStops
        ? `Between ${currentDisplay || "previous stop"} and ${nextDisplay || "next stop"}`
        : `At/near ${currentDisplay || "route stop"}`} · GPS ${gpsCoordinates}`;


  const gpsLabel = gpsOnline
    ? "Live GPS connected"
    : "Waiting for GPS update";

  const rows = stops.map((stop, index) => {
    const name = stop.stop_name || `Stop ${index + 1}`;
    const key = String(name).trim().toLowerCase();

    const explicit = String(stop.status || "").toLowerCase();
    let status = "upcoming";
    let statusLabel = "Upcoming";

    if (["completed", "complete", "arrived", "reached"].includes(explicit)) {
      status = "completed";
      statusLabel = "Completed";
    } else if (index === currentIndex && busBetweenStops) {
      status = "completed";
      statusLabel = "Passed";
    } else if (index === currentIndex) {
      status = "current";
      statusLabel = "Bus is here";
    } else if (index === nextIndex) {
      status = "next";
      statusLabel = "Next stop";
    } else if (["delayed", "late"].includes(explicit)) {
      status = "delayed";
      statusLabel = "Delayed";
    } else if (["on_time", "on time", "ontime"].includes(explicit)) {
      status = "ontime";
      statusLabel = "On time";
    }

    // Use stored campus distance when available; otherwise calculate
    // straight-line distance from this stop to the final route stop.
    const campusStop = stops[stops.length - 1];
    const stopLat = Number(stop.latitude ?? stop.stop_latitude ?? stop.lat);
    const stopLon = Number(stop.longitude ?? stop.stop_longitude ?? stop.lng ?? stop.lon);
    const campusLat = Number(campusStop?.latitude ?? campusStop?.stop_latitude ?? campusStop?.lat);
    const campusLon = Number(campusStop?.longitude ?? campusStop?.stop_longitude ?? campusStop?.lng ?? campusStop?.lon);

    let distance = stop.distance_to_campus_km ?? null;

    if ((distance === null || distance === "") &&
        [stopLat, stopLon, campusLat, campusLon].every(Number.isFinite)) {
      const rad = Math.PI / 180;
      const dLat = (campusLat - stopLat) * rad;
      const dLon = (campusLon - stopLon) * rad;
      const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(stopLat * rad) * Math.cos(campusLat * rad) *
        Math.sin(dLon / 2) ** 2;
      distance = (6371 * 2 * Math.asin(Math.sqrt(a))).toFixed(2);
    }

    const arrival = stop.actual_arrival_time ||
      stop.arrival_time ||
      stop.pickup_time ||
      stop.scheduled_pickup_time ||
      "";

    const departure = stop.actual_departure_time ||
      stop.departure_time ||
      stop.drop_time ||
      stop.scheduled_drop_time ||
      "";

    const delay = stop.delay_minutes;
    const delayText = delay !== undefined && delay !== null
      ? `${Number(delay) > 0 ? "+" : ""}${esc(delay)} min`
      : "";

    const stopCode = stop.stop_code || stop.code || "";

    const stopHtml = `
      <article class="rail-stop rail-${status}">
        <div class="rail-distance">
          <strong>${distance !== null && distance !== ""
            ? `${esc(distance)} km`
            : "—"}</strong>
          <small>${esc(stopCode || `STOP ${index + 1}`)}</small>
        </div>

        <div class="rail-track">
          <span class="rail-marker">
            ${status === "completed" ? "✓" :
              status === "current" ? "●" : ""}
          </span>
          ${index < stops.length - 1
            ? '<span class="rail-line"></span>'
            : ""}
        </div>

        <div class="rail-stop-content">
          <div class="rail-stop-heading">
            <strong>${esc(name)}</strong>
            <span class="rail-status">${esc(statusLabel)}</span>
          </div>

          <div class="rail-times">
            <div>
              <small>ARRIVAL</small>
              <strong>${esc(arrival || "—")}</strong>
            </div>
            <div>
              <small>DEPARTURE</small>
              <strong>${esc(departure || "—")}</strong>
            </div>
          </div>

          ${delayText ? `
            <div class="rail-delay">
              Delay: ${delayText}
            </div>
          ` : ""}
        </div>
      </article>`;

    const liveLocationHtml =
      busBetweenStops && index === currentIndex
        ? `
          <article class="rail-live-position">
            <div class="rail-live-distance">
              <strong>${distanceFromCurrentKm.toFixed(2)} km</strong>
              <small>FROM LAST STOP</small>
            </div>
            <div class="rail-live-track">
              <span class="rail-live-marker" aria-label="Live bus location">🚌</span>
              <span class="rail-live-line"></span>
            </div>
            <div class="rail-live-content">
              <div class="rail-live-title">
                <strong>${esc(route.bus_number || bus.bus_number || "UNIVERSITY BUS")} · LIVE LOCATION</strong>
                <span class="rail-live-badge">LIVE</span>
              </div>
              <div class="rail-live-description">
                Between ${esc(currentDisplay || "previous stop")} and
                ${esc(nextDisplay || "next stop")}
              </div>
              <div class="rail-live-next-distance">
                ${distanceToNextKm.toFixed(2)} km to next stop
              </div>
            </div>
          </article>`
        : "";

    return stopHtml + liveLocationHtml;
  }).join("");

  const destination = route.end_point || stops[stops.length - 1]?.stop_name || "Destination";
  const currentStop =
    route.current_stop || bus.current_stop || liveProgress?.currentStop || "";

  const nextName =
    route.next_stop || bus.next_stop || liveProgress?.nextStop || "";

  const distanceMeters = Number(route.distance_to_next_stop_m);
  const nextStop = nextName
    ? `${nextName}${Number.isFinite(distanceMeters) && distanceMeters > 0
        ? ` · ${(distanceMeters / 1000).toFixed(2)} km`
        : liveProgress ? ` · ${liveProgress.nextDistanceKm.toFixed(2)} km` : ""}`
    : "";

  target.innerHTML = `
    <div class="rail-journey">
      <div class="rail-journey-header">
        <div>
          <span class="rail-eyebrow">LIVE BUS JOURNEY</span>
          <h3>${esc(route.bus_number || bus.bus_number || "University Bus")}</h3>
          <p>${esc(route.name || route.code || "University Route")}</p>
          <p><strong>LIVE BUS LOCATION:</strong> ${esc(livePositionText)}</p>
        </div>
        <span class="rail-gps ${gpsOnline ? "is-live" : "is-waiting"}">
          ${esc(gpsLabel)}
        </span>
      </div>

      <div class="rail-column-head">
        <span>CAMPUS DISTANCE</span>
        <span>ARRIVAL</span>
        <span>DEPARTURE</span>
      </div>

      <div class="rail-stops">
        ${rows}
      </div>

      <div class="rail-journey-footer">
        <div>
          <small>${busBetweenStops ? "LAST PASSED STOP" : "CURRENT STOP"}</small>
          <strong>${esc(currentStop || "Awaiting GPS")}</strong>
        </div>
        <div>
          <small>LIVE BUS DISTANCE TO NEXT STOP</small>
          <strong>${esc(nextStop || "Awaiting GPS")}</strong>
        </div>
        <div>
          <small>DESTINATION</small>
          <strong>${esc(destination)}</strong>
        </div>
      </div>

      <div class="rail-update-note">
        ${gpsOnline
          ? "Journey status refreshes when new GPS data is received."
          : "Live arrival, distance and delay are waiting for GPS data."}
      </div>
    </div>`;
}

function renderActiveJourneyTimelines() {
  renderJourneyTimeline(state.activeRoute, "trackingJourneyTimeline");
  renderJourneyTimeline(state.activeRoute, "busJourneyTimeline");
}

/* ---------- Bus details ---------- */

const infoRow = (
  label,
  value
) =>

  `<div class="info-row">
    <span>${esc(label)}</span>
    <strong>
      ${esc(
        value || "Not available"
      )}
    </strong>
  </div>`;



function renderStudentLiveBusCard() {
  const panel = $("studentLiveBusPanel");
  if (!panel) return;

  if (String(state.user?.role || "").toUpperCase() !== "STUDENT") {
    panel.hidden = true;
    return;
  }
  panel.hidden = false;

  const route = state.activeRoute;
  const bus = route?.busData || {};
  const loc = route?.liveLocation || null;
  const valid = loc &&
    Number.isFinite(Number(loc.latitude)) &&
    Number.isFinite(Number(loc.longitude)) &&
    !(Number(loc.latitude) === 0 && Number(loc.longitude) === 0);

  const online = valid && route.gpsOnline === true;
  const status = online ? "GPS Online" : valid ? "GPS Stale" : "GPS Offline";

  setText("studentBusStatus", status);
  setText("studentBusCount", route ? "1 bus" : "0 buses");

  const list = $("studentLiveBusDetails");
  if (!list) return;
  if (!route) {
    list.innerHTML = '<div class="empty-state">No assigned bus found.</div>';
    return;
  }

  const current = route.current_stop || bus.current_stop ||
    $("trkCurrent")?.textContent?.trim() || "—";
  const next = route.next_stop || bus.next_stop ||
    $("trkNext")?.textContent?.trim() || "—";
  const etaValue = route.eta_minutes ?? bus.eta_minutes;
  const eta = etaValue != null
    ? fmtEta(Number(etaValue))
    : $("trkEta")?.textContent?.trim() || "—";
  const speed = valid && loc.speed != null ? facultySpeed(loc.speed) : "—";
  const updated = valid && loc.recorded_at ? facultyGpsAge(loc.recorded_at) : "No GPS update";
  const busNo = bus.bus_number || route.bus_number || "Assigned bus";
  const driver = bus.driver_id ? `Driver ID: ${esc(bus.driver_id)}` : "Driver details unavailable";

  list.innerHTML = `<article class="faculty-fleet-card">
    <div class="faculty-fleet-card-head">
      <div><h4>${esc(busNo)}</h4>
      <p>${esc(route.name || route.route_name || "University route")} · ${driver}</p></div>
      <span class="status-badge ${online ? "success" : "warning"}">${status}</span>
    </div>
    <div class="faculty-fleet-metrics">
      <div><span>Speed</span><strong>${esc(speed)}</strong></div>
      <div><span>Current stop</span><strong>${esc(current)}</strong></div>
      <div><span>Next stop</span><strong>${esc(next)}</strong></div>
      <div><span>Estimated arrival</span><strong>${esc(eta)}</strong></div>
      <div><span>Last GPS update</span><strong>${esc(updated)}</strong></div>
    </div>
  </article>`;
}

async function renderBusDetails() {

  const route =
    state.activeRoute;

  renderActiveJourneyTimelines();
  renderStudentLiveBusCard();


  if (!route) {

    $("busInfoRows").innerHTML =
      emptyState(
        "No bus assigned."
      );

    return;
  }


  const bus =
    route.busData;


  if (!bus) {

    $("busInfoRows").innerHTML =
      emptyState(
        "No bus information available."
      );

    return;
  }


  const status =
    statusOf(
      bus.status ||
      route.status
    );


  setText(
    "busType",
    bus.bus_type ||
    "Bus"
  );


  setText(
    "busNumber",
    bus.bus_number ||
    route.bus_number ||
    "—"
  );


  setText(
    "busRegistration",
    `Registration: ${
      bus.registration_number ||
      "Not available"
    }`
  );


  const badge =
    $("busStatusBadge");


  if (badge) {

    badge.className =
      `bus-detail-status status-badge ${status.cls}`;

    badge.textContent =
      status.label;
  }


  $("busInfoRows").innerHTML =

    infoRow(
      "Bus number",
      bus.bus_number
    ) +

    infoRow(
      "Bus type",
      bus.bus_type
    ) +

    infoRow(
      "Registration number",
      bus.registration_number
    ) +

    infoRow(
      "Capacity",
      bus.capacity
        ? `${bus.capacity} seats`
        : ""
    ) +

    infoRow(
      "Route",
      route.code
    ) +

    infoRow(
      "Driver ID",
      bus.driver_id
    ) +

    infoRow(
      "Trip status",
      bus.trip_status ||
      bus.status
    );
}


/* ---------- Profile ---------- */

function renderProfile() {

  const user =
    state.user || {};


  const routes =
    state.routes
      .map(
        (route) =>
          `${route.code} (${route.name})`
      )
      .join(", ");


  $("profileInfoRows").innerHTML =

    infoRow(
      "Full name",
      user.full_name ||
      user.name
    ) +

    infoRow(
      "Email",
      user.email
    ) +

    infoRow(
      "Role",
      user.role
        ? String(user.role)
            .replace(
              /^./,
              (character) =>
                character.toUpperCase()
            )
        : "Student"
    ) +

    infoRow(
      "Enrollment number",
      user.enrollment_no ||
      user.enrollment_number
    ) +

    infoRow(
      "Department",
      user.department
    ) +

    infoRow(
      "Semester",
      user.semester
    ) +

    infoRow(
      "Transport routes",
      routes
    );
}


/* ---------- Active route ---------- */

function pickActiveRoute() {

  state.activeRoute =

    state.routes.find(
      (route) =>
        route.type === "route" &&
        isRunning(route.status)
    )

    ||

    state.routes.find(
      (route) =>
        isRunning(route.status)
    )

    ||

    state.routes[0]

    ||

    null;


  if (
    state.activeRoute
  ) {

    updateBusInfo({

      bus_number:
        state.activeRoute.bus_number,

      route_code:
        state.activeRoute.code,

      status:
        state.activeRoute.status,

      current_stop:
        state.activeRoute.current_stop,

      next_stop:
        state.activeRoute.next_stop,

      eta_minutes:
        state.activeRoute.eta_minutes

    });


    setBusPhotos(state.activeRoute);

    renderRouteStopsOnMap(
      state.activeRoute
    );

    renderActiveJourneyTimelines();
  }
}


/* ---------- All University Buses Gallery ---------- */

function renderUniversityBuses() {
  const grid = $("allUniversityBusesGrid");
  const count = $("allBusesCount");

  if (!grid) return;

  const buses = state.allBuses || [];

  if (count) {
    count.textContent = `${buses.length} Buses`;
  }

  if (!buses.length) {
    grid.innerHTML = emptyState("No university buses available.");
    return;
  }

  grid.innerHTML = buses.map((bus) => {
    const photo = bus.front_photo || bus.side_photo;
    const photoUrl = photo
      ? API_BASE_URL + photo
      : "../photo/bus.jpg";

    return `
      <article class="university-bus-card">
        <img
          class="university-bus-card-photo"
          src="${esc(photoUrl)}"
          alt="${esc(bus.bus_number || "University bus")}"
          loading="lazy"
          onerror="this.onerror=null;this.src='../photo/bus.jpg';"
        >
        <div class="university-bus-card-body">
          <h3>${esc(bus.bus_number || "Bus")}</h3>
          <span class="bus-type-label">${esc(bus.bus_type || "University Bus")}</span>
          <p>Registration: ${esc(bus.registration_number || "Not available")}</p>
          <p>Capacity: ${esc(bus.capacity ?? "Not available")}</p>
        </div>
      </article>
    `;
  }).join("");
}



function applyRoleLabels() {
  const faculty = String(state.user?.role || "").toUpperCase() === "FACULTY";

  const set = (selector, value) => {
    const el = document.querySelector(selector);
    if (el) el.textContent = value;
  };

  set(".portal-label", faculty ? "Faculty portal" : "Student portal");
  set("#dashboardSection .welcome-content .section-eyebrow",
      faculty ? "Faculty dashboard" : "Student dashboard");
  set("#dashboardSection .welcome-content p",
      faculty
        ? "Monitor university buses, active routes and live fleet locations."
        : "Track your university buses, check routes and see when your bus will arrive.");

  set('.menu-item[data-page="routes"] span',
      faculty ? "All Routes" : "My Routes");
  set(".routes-card .card-eyebrow",
      faculty ? "University transport" : "Your transport");
  set(".routes-card h3", faculty ? "All Routes" : "My Routes");
  set("#routesSection .page-heading h2",
      faculty ? "All Routes" : "My Routes");
  set("#routesSection .page-heading p",
      faculty
        ? "View all active university routes and their assigned buses."
        : "Routes subscribed to your student account.");

  const stat = document.querySelector(
    "#dashboardSection .stats-grid .stat-card:first-child .stat-content"
  );

  if (stat) {
    const label = stat.querySelector("span");
    const small = stat.querySelector("small");
    if (label) label.textContent = faculty ? "University Routes" : "My Routes";
    if (small) small.textContent = faculty ? "Active university routes" : "Subscribed routes";
  }
}

/* ---------- Render everything ---------- */

function renderAll() {

  applyRoleLabels();

  renderUniversityBuses();

  renderHeader();

  renderStats();

  renderDashRoutes();

  renderRoutesPage(
    $("routesFilter")
      ? $("routesFilter").value
      : ""
  );

  renderTrips();

  renderTimetable();

  renderNotifications();

  renderProfile();

  buildSearchIndex();
}


/* ==========================================================
   10. NAVIGATION & SEARCH
   ========================================================== */

const PAGE_TITLES = {

  dashboard: "Dashboard",

  routes: "My Routes",

  tracking: "Live Tracking",

  bus: "Bus Details",

  timetable: "Timetable",

  notifications: "Notifications",

  profile: "My Profile",

  settings: "Settings"
};


function showSection(
  page
) {

  if (!PAGE_TITLES[page]) {

    page = "dashboard";
  }


  $$(".page-section")
    .forEach(
      (section) => {

        section.classList.toggle(
          "active",
          section.id ===
          `${page}Section`
        );
      }
    );


  $$(".menu-item")
    .forEach(
      (menuItem) => {

        menuItem.classList.toggle(
          "active",
          menuItem.dataset.page === page
        );
      }
    );


  const faculty = String(state.user?.role || "").toUpperCase() === "FACULTY";
  const pageTitle = faculty && page === "routes"
    ? "All Routes"
    : PAGE_TITLES[page];

  setText(
    "pageTitle",
    pageTitle
  );


  closeDrawer();

  window.scrollTo({
    top: 0
  });


  refreshMaps();
}


function openDrawer() {

  $("sidebar")
    ?.classList.add("open");

  $("sidebarOverlay")
    ?.classList.add("show");

  $("mobileMenuBtn")
    ?.setAttribute(
      "aria-expanded",
      "true"
    );
}


function closeDrawer() {

  $("sidebar")
    ?.classList.remove("open");

  $("sidebarOverlay")
    ?.classList.remove("show");

  $("mobileMenuBtn")
    ?.setAttribute(
      "aria-expanded",
      "false"
    );
}


/* ---------- Search ---------- */

function buildSearchIndex() {

  const items = [];


  state.routes.forEach(
    (route) => {

      if (route.bus_number) {

        items.push({
          kind: "Bus",
          label:
            route.bus_number,
          sub:
            route.name,
          page:
            "bus"
        });
      }


      items.push({

        kind: "Route",

        label:
          `${route.code} · ${route.name}`,

        sub:
          route.direction,

        page:
          "routes",

        filter:
          route.code
      });


      (
        route.stops || []
      ).forEach(
        (stop) => {

          items.push({

            kind: "Stop",

            label:
              typeof stop === "string"
                ? stop
                : stop.stop_name,

            sub:
              route.name,

            page:
              "routes",

            filter:
              typeof stop === "string"
                ? stop
                : stop.stop_name
          });
        }
      );

    }
  );


  state.searchIndex =
    items;
}


function runSearch(
  query
) {

  const box =
    $("searchResults");


  const q =
    query
      .trim()
      .toLowerCase();


  if (!q) {

    box.hidden = true;

    return;
  }


  const hits =
    state.searchIndex
      .filter(
        (item) =>
          `${item.label} ${item.sub}`
            .toLowerCase()
            .includes(q)
      )
      .slice(0, 8);


  box.innerHTML =

    hits.length

      ? hits
          .map(
            (hit, index) => `
              <button
                class="search-result"
                type="button"
                data-hit="${index}"
              >

                <em>
                  ${esc(hit.kind)}
                </em>

                <span>
                  ${esc(hit.label)}
                </span>

                <small>
                  ${esc(hit.sub)}
                </small>

              </button>
            `
          )
          .join("")

      : `
          <div class="search-empty">
            No matching bus, route or stop.
          </div>
        `;


  box._hits =
    hits;

  box.hidden =
    false;
}


function chooseHit(
  hit
) {

  if (!hit) {
    return;
  }


  if (hit.filter) {

    $("routesFilter").value =
      hit.filter;

    renderRoutesPage(
      hit.filter
    );
  }


  showSection(
    hit.page
  );


  $("searchResults").hidden =
    true;

  $("dashboardSearch").value =
    "";
}


/* ---------- Events ---------- */

function bindEvents() {

  $$(".menu-item")
    .forEach(
      (item) => {

        item.addEventListener(
          "click",
          (event) => {

            event.preventDefault();

            showSection(
              item.dataset.page
            );
          }
        );

      }
    );


  document.addEventListener("keydown", (event) => {
    if (
      (event.key === "Enter" || event.key === " ") &&
      event.target.matches(".route-item[data-route-id]")
    ) {
      event.preventDefault();
      event.target.click();
    }
  });

  document.addEventListener(
    "click",
    (event) => {

      const routeCard = event.target.closest(
        ".route-item[data-route-id]"
      );

      if (routeCard) {
        const selectedRoute = state.routes.find(
          route => String(route.id) === String(routeCard.dataset.routeId)
        );

        if (selectedRoute) {
          state.activeRoute = selectedRoute;

          updateBusInfo({
            bus_number: selectedRoute.bus_number,
            route_code: selectedRoute.code,
            status: selectedRoute.status,
            current_stop: selectedRoute.current_stop,
            next_stop: selectedRoute.next_stop,
            eta_minutes: selectedRoute.eta_minutes
          });

          setBusPhotos(selectedRoute);
          renderRouteStopsOnMap(selectedRoute);
          renderBusDetails();
          showSection("bus");
          startLivePolling();
        }
        return;
      }

      const opener =
        event.target.closest(
          "[data-open-page]"
        );


      if (opener) {

        if (opener.classList.contains("route-track-btn")) {
          const selectedRoute = state.routes.find(
            route => String(route.id) === String(opener.dataset.routeId)
          );

          if (selectedRoute) {
            state.activeRoute = selectedRoute;
            updateBusInfo({
              bus_number: selectedRoute.bus_number,
              route_code: selectedRoute.code,
              status: selectedRoute.status,
              current_stop: selectedRoute.current_stop,
              next_stop: selectedRoute.next_stop,
              eta_minutes: selectedRoute.eta_minutes
            });
            renderRouteStopsOnMap(selectedRoute);
            startLivePolling();
          }
        }

        showSection(
          opener.dataset.openPage
        );
      }


      if (
        !event.target.closest(
          ".search-box"
        )
      ) {

        $("searchResults").hidden =
          true;
      }

    }
  );


  $("fullMapBtn")
    ?.addEventListener(
      "click",
      () =>
        showSection("tracking")
    );


  $("trackBusBtn")
    ?.addEventListener(
      "click",
      () =>
        showSection("tracking")
    );


  $("notificationBtn")
    ?.addEventListener(
      "click",
      () =>
        showSection("notifications")
    );


  $("logoutBtn")
    ?.addEventListener(
      "click",
      logout
    );


  $("mobileMenuBtn")
    ?.addEventListener(
      "click",
      () => {

        if (
          $("sidebar")
            .classList
            .contains("open")
        ) {

          closeDrawer();

        } else {

          openDrawer();
        }
      }
    );


  $("sidebarOverlay")
    ?.addEventListener(
      "click",
      closeDrawer
    );


  window.addEventListener(
    "resize",
    () => {

      if (
        window.innerWidth > 900
      ) {

        closeDrawer();
      }

      refreshMaps();
    }
  );


  const search =
    $("dashboardSearch");


  if (search) {

    search.addEventListener(
      "input",
      () =>
        runSearch(
          search.value
        )
    );


    search.addEventListener(
      "keydown",
      (event) => {

        if (
          event.key === "Enter"
        ) {

          chooseHit(
            (
              $("searchResults")
                ._hits || []
            )[0]
          );
        }


        if (
          event.key === "Escape"
        ) {

          $("searchResults").hidden =
            true;

          search.blur();
        }

      }
    );
  }


  $("searchResults")
    ?.addEventListener(
      "click",
      (event) => {

        const button =
          event.target.closest(
            "[data-hit]"
          );


        if (!button) {
          return;
        }


        chooseHit(
          $("searchResults")
            ._hits[
              Number(
                button.dataset.hit
              )
            ]
        );
      }
    );


  document.addEventListener(
    "keydown",
    (event) => {

      if (
        event.key === "/" &&
        !/^(INPUT|TEXTAREA)$/.test(
          document.activeElement.tagName
        )
      ) {

        event.preventDefault();

        search?.focus();
      }


      if (
        event.key === "Escape"
      ) {

        closeDrawer();
      }

    }
  );


  $("routesFilter")
    ?.addEventListener(
      "input",
      (event) =>
        renderRoutesPage(
          event.target.value
        )
    );
}


/* ==========================================================
   11. SETTINGS
   ========================================================== */

const DEFAULT_SETTINGS = {

  busArrival: true,

  routeUpdates: true,

  timetableReminders: false
};


function loadSettings() {

  try {

    return {
      ...DEFAULT_SETTINGS,

      ...JSON.parse(
        localStorage.getItem(
          CONFIG.SETTINGS_KEY
        ) || "{}"
      )
    };

  } catch (error) {

    return {
      ...DEFAULT_SETTINGS
    };
  }
}


async function initSettings() {
  let settings = loadSettings();

  try {
    const result = await apiFetch("/notifications/preferences");
    settings = { ...settings, ...(result.preferences || {}) };
  } catch (error) {
    console.error("Could not load saved notification preferences:", error);
  }

  $$("[data-setting]").forEach(input => {
    const key = input.dataset.setting;
    input.checked = Boolean(settings[key]);

    input.addEventListener("change", async () => {
      settings[key] = input.checked;
      try {
        const result = await apiFetch("/notifications/preferences", {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(settings)
        });
        settings = { ...settings, ...(result.preferences || {}) };
      } catch (error) {
        input.checked = !input.checked;
        settings[key] = input.checked;
        console.error("Could not save notification preferences:", error);
        alert("Settings could not be saved. Please try again.");
      }
    });
  });
}


/* ==========================================================
   12. DATA LOADING
   ========================================================== */


/*
 * Convert backend bus response into
 * dashboard-friendly format.
 */

function normalizeBus(
  busData,
  route
) {

  if (!busData || busData.bus_assigned === false) {
    return null;
  }


  let status =
    "inactive";


  if (
    busData.trip_status === "ACTIVE"
  ) {

    status =
      "on_time";

  } else if (
    busData.trip_status === "SCHEDULED"
  ) {

    status =
      "scheduled";

  } else if (
    busData.trip_status === "COMPLETED"
  ) {

    status =
      "completed";
  }


  return {

    ...busData,

    bus_number:
      busData.bus_number ||
      route.bus_number,

    route_code:
      route.code,

    status,

    trip_status:
      busData.trip_status,

    gps_available:
      false
  };
}


/*
 * Convert backend route into dashboard object.
 */

async function buildRouteFromBackend(
  route
) {

  const routeId =
    route.route_id;


  /*
   * Get stops and bus in parallel.
   */

  const [
    stopsResult,
    busResult
  ] = await Promise.allSettled([

    getRouteStops(
      routeId
    ),

    getRouteBus(
      routeId
    )

  ]);


  let stopsData = [];


  if (
    stopsResult.status === "fulfilled" &&
    Array.isArray(
      stopsResult.value
    )
  ) {

    stopsData =
      stopsResult.value;
  }


  let busData = null;


  if (
    busResult.status === "fulfilled"
  ) {

    busData =
      normalizeBus(
        busResult.value,
        route
      );
  }


  /*
   * Convert stops into names.
   */

  const stopNames =
    stopsData.map(
      (stop) =>
        stop.stop_name
    );


  /*
   * Direction comes directly
   * from backend route.
   */

  const direction =
    [
      route.start_point,
      route.end_point
    ]
      .filter(Boolean)
      .join(" → ");


  return {

    id:
      route.route_id,

    type:
      (
        busData?.bus_type === "SHUTTLE_BUS" ||
        /shuttle/i.test(route.route_name || "")
      ) ? "shuttle" : "route",

    code:
      route.route_code,

    name:
      route.route_name,

    description:
      route.description,

    direction:
      direction ||
      "Route direction not available",

    bus_number:
      busData?.bus_number ||
      null,

    front_photo:
      busData?.front_photo ||
      null,

    side_photo:
      busData?.side_photo ||
      null,

    busData,

    stopsData,

    stops:
      stopNames,

    current_stop:
      null,

    next_stop:
      null,

    eta_minutes:
      null,

    status:
      busData?.status ||
      "inactive",

    gps_available:
      false,

    start_point:
      route.start_point,

    end_point:
      route.end_point
  };
}



function facultyList(data, keys = []) {
  if (Array.isArray(data)) return data;
  for (const key of keys) {
    if (Array.isArray(data?.[key])) return data[key];
  }
  return [];
}

async function buildFacultyRoute(route) {
  const routeId = route.route_id ?? route.id;
  const stopsData = state.facultyStops
    .filter(stop => String(stop.route_id) === String(routeId))
    .sort((a, b) => Number(a.stop_order ?? 0) - Number(b.stop_order ?? 0));

  const busData = state.allBuses.find(bus =>
    (route.route_code && bus.route_code &&
      String(bus.route_code) === String(route.route_code)) ||
    (route.route_name && bus.route_name &&
      String(bus.route_name) === String(route.route_name))
  ) || null;

  const liveBus = busData
    ? state.liveBuses.find(item =>
        String(item.bus_number) === String(busData.bus_number))
    : null;

  const normalizedBus = busData ? {
    ...busData,
    status: liveBus?.trip_status === "ACTIVE" ? "active" :
      (liveBus?.gps_online ? "active" :
        (liveBus ? "inactive" : "scheduled"))
  } : null;

  return {
    id: routeId,
    type: /shuttle/i.test(`${route.route_name || ""} ${busData?.bus_type || ""}`)
      ? "shuttle" : "route",
    code: route.route_code || "",
    name: route.route_name || "Route",
    description: route.description || "",
    direction: [route.start_point, route.end_point]
      .filter(Boolean).join(" → ") || "Route direction not available",
    bus_number: normalizedBus?.bus_number || null,
    front_photo: normalizedBus?.front_photo || null,
    side_photo: normalizedBus?.side_photo || null,
    busData: normalizedBus,
    stopsData,
    stops: stopsData.map(stop => stop.stop_name).filter(Boolean),
    current_stop: liveBus?.current_stop || null,
    next_stop: liveBus?.next_stop || null,
    eta_minutes: liveBus?.eta_minutes ?? null,
    distance_to_next_stop_m: liveBus?.distance_to_next_stop_m ?? null,
    liveLocation: liveBus ? {
      latitude: liveBus.latitude,
      longitude: liveBus.longitude,
      speed: liveBus.speed,
      recorded_at: liveBus.recorded_at
    } : null,
    gpsOnline: liveBus?.gps_online === true,
    status: normalizedBus?.status || "inactive",
    gps_available: Boolean(liveBus?.gps_online),
    start_point: route.start_point || null,
    end_point: route.end_point || null
  };
}

/*
 * Timetable:
 *
 * Endpoint is not implemented yet.
 * Therefore don't show fake demo timetable.
 */

async function loadTimetableSafely() {

  try {

    return await getTimetable();

  } catch (error) {

    console.warn(
      "Timetable API not available yet:",
      error.message
    );

    return [];
  }
}


/*
 * Notifications:
 *
 * Endpoint is not implemented yet.
 * Therefore don't show fake demo notifications.
 */

async function loadNotificationsSafely() {

  try {
    const result = await getNotifications();
    const notifications = Array.isArray(result)
      ? result
      : (result.notifications || []);

    return notifications.map(notification => ({
      ...notification,
      read: notification.is_read ?? notification.read ?? false
    }));

  } catch (error) {
    console.warn("Notifications loading failed:", error.message);
    return [];
  }
}


/*
 * Main dashboard data loader.
 */

async function loadDashboardData() {
  const stored = getStoredUser() || {};
  const role = String(
    stored.role || stored.user_role || stored.account_type || ""
  ).toUpperCase();

  state.usingDemo = false;

  if (role === "FACULTY") {
    let profileData = {};

    try {
      profileData = await apiFetch("/faculty/me");
    } catch (error) {
      console.error("Faculty profile failed:", error.message);
    }

    try {
      const [routesData, stopsData, busesData, liveData, timetableData] =
        await Promise.all([
          apiFetch("/faculty/routes"),
          apiFetch("/faculty/stops"),
          apiFetch("/faculty/buses"),
          apiFetch("/faculty/live-buses"),
          apiFetch("/faculty/timetable")
        ]);

      state.facultyStops = facultyList(stopsData, ["stops"]);
      state.allBuses = facultyList(busesData, ["buses"]);
      state.liveBuses = facultyList(liveData, ["live_buses", "buses"]);

      const routes = facultyList(routesData, ["routes"]);
      state.routes = await Promise.all(routes.map(buildFacultyRoute));
      state.timetable = facultyList(timetableData, ["timetable", "schedules"]);

    } catch (error) {
      console.error("Faculty dashboard data loading failed:", error.message);
      state.facultyStops = [];
      state.allBuses = [];
      state.liveBuses = [];
      state.routes = [];
      state.timetable = [];
    }

    state.user = {
      ...stored,
      ...(profileData || {}),
      role: "FACULTY"
    };

    state.notifications = await loadNotificationsSafely();

  } else {
    let profileData = null;

    try {
      profileData = await getStudentProfile();
    } catch (error) {
      console.error("Student profile failed:", error.message);
    }

    try {
      state.allBuses = await getAllUniversityBuses();
    } catch (error) {
      console.error("Student buses failed:", error.message);
      state.allBuses = [];
    }

    // Load the full live GPS fleet for the Student Active Buses count.
    try {
      const liveFleetData = await apiFetch("/students/live-buses");
      state.liveBuses = facultyList(liveFleetData, ["live_buses", "buses"]);
    } catch (error) {
      console.error("Student live fleet failed:", error.message);
      state.liveBuses = [];
    }

    let backendRoutes = [];

    try {
      backendRoutes = await getSubscribedRoutes();
    } catch (error) {
      console.error("Student routes failed:", error.message);
      backendRoutes = DEMO_DATA.routes;
      state.usingDemo = true;
    }

    state.routes = await Promise.all(
      backendRoutes.map(buildRouteFromBackend)
    );

    state.user = {
      ...stored,
      ...(profileData || {}),
      role: role || profileData?.role || "STUDENT"
    };

    state.timetable = await loadTimetableSafely();
    state.notifications = await loadNotificationsSafely();
  }

  const demoNotice = $("demoNotice");
  if (demoNotice) demoNotice.hidden = !state.usingDemo;
}


/* ==========================================================
   13. INIT
   ========================================================== */

async function init() {

  if (!requireAuth()) {
    return;
  }


  /*
   * Initialize UI.
   */

  initMaps();

  bindEvents();

  initSettings();


  /*
   * Load real backend data.
   */

  await loadDashboardData();


  /*
   * Render UI.
   */

  renderAll();


  /*
   * Select active route.
   */

  pickActiveRoute();


  /*
   * Render bus details.
   */

  await renderBusDetails();


  /*
   * Live GPS polling is currently disabled.
   *
   * This prevents:
   *
   * /buses/undefined/location
   *
   * 404 spam.
   */

  startLivePolling();


  refreshMaps();
}


/* ==========================================================
   START APPLICATION
   ========================================================== */

document.addEventListener(
  "DOMContentLoaded",
  init
);