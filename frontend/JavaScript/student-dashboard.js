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

const API_BASE_URL = "http://127.0.0.1:8000";

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

    routes: "/students/me/routes",

    routeStops: (routeId) =>
      `/students/me/routes/${encodeURIComponent(routeId)}/stops`,

    routeBus: (routeId) =>
      `/students/me/routes/${encodeURIComponent(routeId)}/bus`,

    timetable: "/students/me/timetable",

    notifications: "/students/me/notifications"

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

  for (const key of keys) {

    const value = localStorage.getItem(key);

    if (value) {
      return value;
    }
  }

  return null;
}


function getToken() {

  return readStorage(CONFIG.TOKEN_KEYS);
}


function getStoredUser() {

  const raw = readStorage(CONFIG.USER_KEYS);

  if (!raw) {
    return null;
  }

  let user;

  try {

    user = JSON.parse(raw);

  } catch (error) {

    user = {
      name: raw
    };
  }

  if (!user || typeof user !== "object") {
    return null;
  }

  const safe = {
    ...user
  };

  delete safe.password;
  delete safe.hashed_password;

  return safe;
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


const getSubscribedRoutes = () =>
  apiFetch(CONFIG.ENDPOINTS.routes);


const getRouteStops = (routeId) =>
  apiFetch(CONFIG.ENDPOINTS.routeStops(routeId));


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

  completed: {
    label: "Completed",
    cls: "ok"
  },

  upcoming: {
    label: "Upcoming",
    cls: "info"
  }
};


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
    status === "delayed"
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
    23.3441,
    85.3096
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

  const coordinates =
    route.stopsData
      .filter(
        (stop) =>
          typeof stop.latitude === "number" &&
          typeof stop.longitude === "number"
      )
      .map(
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

      route.stopsData.forEach(
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
            coordinates
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


/*
 * GPS polling is currently disabled.
 *
 * This prevents requests such as:
 *
 * /buses/undefined/location
 *
 * until the Driver GPS API is ready.
 */

async function pollLiveLocation() {

  const route =
    state.activeRoute;

  if (!route) {
    return;
  }


  /*
   * Check whether a real GPS endpoint
   * has been implemented.
   */

  if (!route.gps_available) {

    setText(
      "mapUpdated",
      "Waiting for driver GPS"
    );

    setText(
      "trkMessage",
      "Live GPS will appear when the driver starts sharing location"
    );

    const liveDot =
      $("liveDot");

    if (liveDot) {
      liveDot.classList.remove("on");
    }

    return;
  }


  /*
   * Future GPS implementation goes here.
   */

  console.log(
    "GPS endpoint is not implemented yet."
  );
}


function startLivePolling() {

  clearInterval(
    state.pollTimer
  );


  /*
   * Do NOT poll until GPS API exists.
   *
   * This removes repeated 404 requests.
   */

  state.pollTimer = null;
}


/* ==========================================================
   9. RENDERERS
   ========================================================== */

function renderHeader() {

  const user =
    state.user || {};


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

  const running =
    state.routes.filter(
      (route) =>
        isRunning(
          route.status
        )
    );


  const etas =
    state.routes
      .map(
        (route) =>
          route.eta_minutes
      )
      .filter(
        (minutes) =>
          typeof minutes === "number"
      );


  const next =
    state.routes
      .filter(
        (route) =>
          typeof route.eta_minutes === "number"
      )
      .sort(
        (a, b) =>
          a.eta_minutes -
          b.eta_minutes
      )[0];


  setText(
    "statRoutes",
    state.routes.length
  );


  setText(
    "statActive",
    running.length
  );


  setText(
    "statTrips",
    state.timetable.length
  );


  setText(
    "statNext",
    etas.length
      ? fmtEta(
          Math.min(...etas)
        )
      : "—"
  );


  setText(
    "statNextStop",

    next &&
    next.current_stop

      ? `At ${next.current_stop}`

      : "GPS pending"
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
                statusOf(
                  route.status
                );


              return `
                <div class="route-item">

                  <div class="route-bus-image">
                    <img
                      src="../images/university-bus.jpg"
                      alt=""
                    >
                  </div>

                  <div class="route-info">

                    <div class="route-top">

                      <strong>
                        ${esc(route.name)}
                      </strong>

                      <span
                        class="status-badge ${status.cls}"
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
    statusOf(
      route.status
    );


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
          src="../images/university-bus.jpg"
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
            class="status-badge ${status.cls}"
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

  setText(
    "timetableCount",

    `${state.timetable.length} trip${
      state.timetable.length === 1
        ? ""
        : "s"
    }`
  );


  $("timetableBody").innerHTML =

    state.timetable.length

      ? state.timetable
          .map(
            (trip) => {

              const status =
                statusOf(
                  trip.status
                );


              return `
                <div class="schedule-row">

                  <span>
                    ${esc(trip.time)}
                  </span>

                  <span>
                    ${esc(
                      trip.bus_number ||
                      "—"
                    )}
                  </span>

                  <span>
                    ${esc(
                      trip.route_code ||
                      "—"
                    )}
                  </span>

                  <span>
                    ${esc(
                      trip.direction ||
                      "—"
                    )}
                  </span>

                  <span>

                    <span
                      class="status-badge ${status.cls}"
                    >
                      ${esc(status.label)}
                    </span>

                  </span>

                </div>
              `;
            }
          )
          .join("")

      : emptyState(
          "No timetable data available yet."
        );
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


async function renderBusDetails() {

  const route =
    state.activeRoute;


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


    renderRouteStopsOnMap(
      state.activeRoute
    );
  }
}


/* ---------- Render everything ---------- */

function renderAll() {

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


  setText(
    "pageTitle",
    PAGE_TITLES[page]
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


  document.addEventListener(
    "click",
    (event) => {

      const opener =
        event.target.closest(
          "[data-open-page]"
        );


      if (opener) {

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


function initSettings() {

  const settings =
    loadSettings();


  $$("[data-setting]")
    .forEach(
      (input) => {

        input.checked =
          !!settings[
            input.dataset.setting
          ];


        input.addEventListener(
          "change",
          () => {

            settings[
              input.dataset.setting
            ] =
              input.checked;


            localStorage.setItem(
              CONFIG.SETTINGS_KEY,
              JSON.stringify(
                settings
              )
            );

          }
        );

      }
    );
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

  if (!busData) {
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
      "route",

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

    return await getNotifications();

  } catch (error) {

    console.warn(
      "Notifications API not available yet:",
      error.message
    );

    return [];
  }
}


/*
 * Main dashboard data loader.
 */

async function loadDashboardData() {

  const stored =
    getStoredUser() || {};


  /*
   * Load profile.
   */

  let profileData = null;


  try {

    profileData =
      await getStudentProfile();

  } catch (error) {

    console.error(
      "Student profile failed:",
      error.message
    );
  }


  /*
   * Load subscribed routes.
   */

  let backendRoutes = [];


  try {

    backendRoutes =
      await getSubscribedRoutes();

  } catch (error) {

    console.error(
      "Student routes failed:",
      error.message
    );


    /*
     * Only use demo route data
     * if the actual routes API fails.
     */

    backendRoutes =
      DEMO_DATA.routes;

    state.usingDemo =
      true;
  }


  /*
   * Build each route with:
   *
   * route
   * ↓
   * stops
   * ↓
   * bus
   */

  const routeResults =
    await Promise.all(
      backendRoutes.map(
        (route) =>
          buildRouteFromBackend(
            route
          )
      )
    );


  state.user = {

    ...stored,

    ...(profileData || {})
  };


  state.routes =
    routeResults;


  /*
   * Load timetable and notifications.
   */

  state.timetable =
    await loadTimetableSafely();


  state.notifications =
    await loadNotificationsSafely();


  /*
   * Demo notice should only indicate
   * route fallback, not missing optional APIs.
   */

  const demoNotice =
    $("demoNotice");


  if (demoNotice) {

    demoNotice.hidden =
      !state.usingDemo;
  }
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