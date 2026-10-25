/* ==========================================================================
   Admin Dashboard — Stage 5: read-only integration with the existing API.

   Uses ONLY endpoints that already exist in backend/app/routers/user.py:
     GET /users/                  GET /users/buses
     GET /users/drivers           GET /users/routes
     GET /users/routes/{id}/stops
   All of them are protected by require_admin on the backend.

   Nothing is created, edited or deleted from this file.
   All API data is written to the page with textContent / createElement
   (never innerHTML), so API values cannot inject markup.
   ========================================================================== */
(function () {
  "use strict";

  var API_BASE = "http://127.0.0.1:8000";   // same base URL the login and driver pages use
  var LOGIN_PAGE = "login.html";             // same folder as this page
  var PAGE_SIZE = 10;
  var REQUEST_TIMEOUT_MS = 15000;
  var AUTH_KEYS = ["access_token", "token_type", "user_id", "user_name", "user_email", "user_role"];

  /* ---------------------------------------------------------------- auth */
  function readStore(store, key) {
    try { return store.getItem(key); } catch (e) { return null; }
  }
  function readAuth() {
    var stores = [window.localStorage, window.sessionStorage];
    for (var i = 0; i < stores.length; i++) {
      var token = readStore(stores[i], "access_token");
      if (token) {
        return {
          token: token,
          type: readStore(stores[i], "token_type") || "bearer",
          name: readStore(stores[i], "user_name") || "",
          role: (readStore(stores[i], "user_role") || "").toUpperCase()
        };
      }
    }
    return null;
  }
  function clearAuth() {
    [window.localStorage, window.sessionStorage].forEach(function (store) {
      AUTH_KEYS.forEach(function (k) { try { store.removeItem(k); } catch (e) { /* ignore */ } });
    });
  }
  function goToLogin() { window.location.replace(LOGIN_PAGE); }

  var auth = readAuth();
  // Frontend guard is a convenience only. The backend enforces ADMIN on every endpoint below.
  if (!auth || (auth.role && auth.role !== "ADMIN")) { goToLogin(); return; }

  /* ------------------------------------------------------------- helpers */
  function $(id) { return document.getElementById(id); }
  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) { n.className = cls; }
    if (text !== undefined && text !== null) { n.textContent = text; }
    return n;
  }
  function chip(text, cls) { return el("span", "chip " + cls, text); }

  var toasts = $("toasts");
  function toast(message, kind) {
    var t = el("div", "toast toast--" + (kind || "info"), message);
    toasts.appendChild(t);
    setTimeout(function () { if (t.parentNode) { t.parentNode.removeChild(t); } }, kind === "error" ? 8000 : 4000);
  }

  /* ----------------------------------------------------------- API client */
  function ApiError(status, message) { this.status = status; this.message = message; }

  function detailText(body) {
    if (!body || body.detail === undefined) { return ""; }
    if (typeof body.detail === "string") { return body.detail; }
    if (Array.isArray(body.detail)) {
      return body.detail.map(function (d) { return d && d.msg ? d.msg : ""; }).filter(Boolean).join("; ");
    }
    return "";
  }

  function api(path) {
    var ctrl = new AbortController();
    var timer = setTimeout(function () { ctrl.abort(); }, REQUEST_TIMEOUT_MS);
    return fetch(API_BASE + path, {
      method: "GET",
      headers: { "Accept": "application/json", "Authorization": "Bearer " + auth.token },
      signal: ctrl.signal
    }).then(function (res) {
      clearTimeout(timer);
      return res.text().then(function (txt) {
        var body = null;
        try { body = txt ? JSON.parse(txt) : null; } catch (e) { body = null; }
        if (res.ok) { return body; }
        var detail = detailText(body);
        if (res.status === 401) {
          clearAuth(); goToLogin();
          throw new ApiError(401, "Your session has expired. Redirecting to sign in.");
        }
        if (res.status === 403) { throw new ApiError(403, "Your account does not have administrator access to this data."); }
        if (res.status === 404) { throw new ApiError(404, "This API endpoint was not found (404)." + (detail ? " " + detail : "")); }
        if (res.status === 422) { throw new ApiError(422, "The server rejected the request: " + (detail || "invalid input") + "."); }
        if (res.status >= 500) { throw new ApiError(res.status, "The server reported an error (" + res.status + "). Check the FastAPI terminal for details."); }
        throw new ApiError(res.status, detail || ("Request failed (" + res.status + ")."));
      });
    }, function (err) {
      clearTimeout(timer);
      if (err && err.name === "AbortError") {
        throw new ApiError(0, "The server did not respond within " + (REQUEST_TIMEOUT_MS / 1000) + " seconds.");
      }
      throw new ApiError(0, "Cannot reach the server at " + API_BASE + ". Check that FastAPI is running (uvicorn) and that this page is opened from http://127.0.0.1:5500 or http://localhost:5500.");
    });
  }


  
function apiPost(path, payload) {
  var ctrl = new AbortController();
  var timer = setTimeout(function () {
    ctrl.abort();
  }, REQUEST_TIMEOUT_MS);

  return fetch(API_BASE + path, {
    method: "POST",
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer " + auth.token
    },
    body: JSON.stringify(payload),
    signal: ctrl.signal
  })
    .then(function (res) {
      clearTimeout(timer);

      return res.text().then(function (txt) {
        var body = null;

        try {
          body = txt ? JSON.parse(txt) : null;
        } catch (e) {
          body = null;
        }

        if (!res.ok) {
          var detail = detailText(body);
          throw new ApiError(
            res.status,
            detail || "Request failed (" + res.status + ")."
          );
        }

        return body;
      });
    })
    .catch(function (err) {
      clearTimeout(timer);

      if (err instanceof ApiError) {
        throw err;
      }

      if (err && err.name === "AbortError") {
        throw new ApiError(0, "Request timed out.");
      }

      throw new ApiError(
        0,
        "Cannot connect to the API. Check that FastAPI is running."
      );
    });
}



  /* ---------------------------------------------------------------- data */
  var data = { users: null, buses: null, drivers: null, routes: null };
  var status = { users: "idle", buses: "idle", drivers: "idle", routes: "idle" };
  var errors = { users: "", buses: "", drivers: "", routes: "" };
  var PATHS = { users: "/users/", buses: "/users/buses", drivers: "/users/drivers", routes: "/users/routes" };

  function load(name) {
    status[name] = "loading"; errors[name] = "";
    renderAll();
    return api(PATHS[name]).then(function (rows) {
      if (!Array.isArray(rows)) { throw new ApiError(200, "Unexpected response format from " + PATHS[name] + "."); }
      data[name] = rows; status[name] = "ready";
    }).catch(function (e) {
      data[name] = null; status[name] = "error"; errors[name] = (e && e.message) || "Unknown error.";
    }).then(renderAll);
  }

  function driverName(id) {
    if (id === null || id === undefined) { return null; }
    if (!data.drivers) { return "Driver ID " + id; }
    for (var i = 0; i < data.drivers.length; i++) {
      if (data.drivers[i].driver_id === id) { return data.drivers[i].name; }
    }
    return "Driver ID " + id;
  }
  function busFor(driverId) {
    if (!data.buses) { return null; }
    var out = [];
    data.buses.forEach(function (b) { if (b.driver_id === driverId) { out.push(b.bus_number); } });
    return out;
  }

  /* --------------------------------------------------------- table widget */
  function DataTable(cfg) {
    this.cfg = cfg;
    this.table = $(cfg.id);
    this.body = this.table.tBodies[0] || this.table.appendChild(document.createElement("tbody"));
    this.pager = this.table.parentElement.nextElementSibling;
    this.page = 1;
    this.query = "";
    this.filters = {};
    this.columns = this.table.tHead.rows[0].cells.length;
    var self = this;
    (cfg.search ? [$(cfg.search)] : []).forEach(function (inp) {
      inp.addEventListener("input", function () { self.query = inp.value.trim().toLowerCase(); self.page = 1; self.render(); });
    });
    Object.keys(cfg.filters || {}).forEach(function (id) {
      var sel = $(id); self.filters[id] = sel.value;
      sel.addEventListener("change", function () { self.filters[id] = sel.value; self.page = 1; self.render(); });
    });
    if (this.pager) {
      var btns = this.pager.querySelectorAll("button");
      btns[0].addEventListener("click", function () { self.page--; self.render(); });
      btns[1].addEventListener("click", function () { self.page++; self.render(); });
    }
  }

  DataTable.prototype.messageRow = function (node) {
    var tr = el("tr"); var td = el("td"); td.colSpan = this.columns; td.appendChild(node); tr.appendChild(td);
    this.body.replaceChildren(tr);
  };

  DataTable.prototype.setPager = function (shown, total, pages) {
    if (!this.pager) { return; }
    var btns = this.pager.querySelectorAll("button");
    this.pager.querySelector("span").textContent = total === 0 ? "Showing 0 of 0" : "Showing " + shown + " of " + total + " (page " + this.page + " of " + pages + ")";
    btns[0].disabled = this.page <= 1; btns[1].disabled = this.page >= pages;
  };

  DataTable.prototype.render = function () {
    var cfg = this.cfg, st = cfg.state(), self = this;
    this.table.setAttribute("aria-busy", st === "loading" ? "true" : "false");

    if (st === "loading") {
      var frag = document.createDocumentFragment();
      for (var r = 0; r < 4; r++) {
        var tr = el("tr");
        for (var c = 0; c < this.columns; c++) { var td = el("td"); td.appendChild(el("span", "skeleton skeleton-line", "loading")); tr.appendChild(td); }
        frag.appendChild(tr);
      }
      this.body.replaceChildren(frag); this.setPager(0, 0, 1); return;
    }
    if (st === "error") {
      var box = el("div", "error-state");
      box.setAttribute("role", "alert");
      box.appendChild(el("strong", null, "Could not load " + cfg.noun));
      box.appendChild(el("p", null, cfg.error()));
      var retry = el("button", "btn btn--sm", "Try again"); retry.type = "button";
      retry.addEventListener("click", cfg.retry);
      box.appendChild(retry);
      this.messageRow(box); this.setPager(0, 0, 1); return;
    }
    if (st === "idle") {
      this.messageRow(emptyState(cfg.idleTitle || "Nothing selected", cfg.idleMsg || "")); this.setPager(0, 0, 1); return;
    }

    var all = cfg.rows();
    var q = this.query;
    var rows = all.filter(function (row) {
      if (q && cfg.searchText(row).toLowerCase().indexOf(q) === -1) { return false; }
      for (var id in cfg.filters || {}) {
        if (self.filters[id] && !cfg.filters[id](row, self.filters[id])) { return false; }
      }
      return true;
    });
    if (rows.length === 0) {
      var filtered = all.length > 0;
      this.messageRow(emptyState(filtered ? "No matching " + cfg.noun : "No " + cfg.noun + " yet",
        filtered ? "No records match the current search or filters." : cfg.emptyMsg));
      this.setPager(0, 0, 1); return;
    }
    var pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
    if (this.page > pages) { this.page = pages; }
    if (this.page < 1) { this.page = 1; }
    var slice = rows.slice((this.page - 1) * PAGE_SIZE, this.page * PAGE_SIZE);
    var out = document.createDocumentFragment();
    slice.forEach(function (row) {
      var tr = cfg.rowClass && cfg.rowClass(row) ? el("tr", cfg.rowClass(row)) : el("tr");
      cfg.columns.forEach(function (col) {
        var td = el("td", col.num ? "num" : "");
        var v = col.cell(row);
        if (v instanceof Node) { td.appendChild(v); } else { td.textContent = v === null || v === undefined || v === "" ? "—" : String(v); }
        tr.appendChild(td);
      });
      out.appendChild(tr);
    });
    this.body.replaceChildren(out);
    this.setPager(slice.length, rows.length, pages);
  };

  function emptyState(title, msg) {
    var d = el("div", "empty");
    d.appendChild(el("strong", null, title));
    if (msg) { d.appendChild(el("p", null, msg)); }
    return d;
  }
  function textOf(v) { return v === null || v === undefined ? "" : String(v); }
  function boolChip(v, yes, no) { return v ? chip(yes, "chip--api") : chip(no, "chip--ph"); }
  function roleChip(role) { return chip(role, role === "ADMIN" ? "chip--blue" : "chip--ph"); }

  function stateOf(name) { return function () { return status[name]; }; }
  function errOf(name) { return function () { return errors[name]; }; }

  /* -------------------------------------------------------- table configs */
  var tables = {};

  tables.users = new DataTable({
    id: "tbl-users", noun: "users", search: "usr-search",
    filters: { "usr-role": function (r, v) { return r.role === v; } },
    state: stateOf("users"), error: errOf("users"), retry: function () { load("users"); },
    rows: function () { return data.users; },
    emptyMsg: "The users table has no accounts.",
    searchText: function (r) { return textOf(r.name) + " " + textOf(r.email); },
    columns: [
      { num: true, cell: function (r) { return r.user_id; } },
      { cell: function (r) { return el("span", "cell-main", textOf(r.name) || "—"); } },
      { cell: function (r) { return r.email; } },
      { cell: function (r) { return roleChip(r.role); } },
      { cell: function (r) { return boolChip(r.is_active, "Active", "Inactive"); } }
    ]
  });

  tables.buses = new DataTable({
    id: "tbl-buses", noun: "buses", search: "bus-search",
    filters: {
      "bus-type": function (r, v) { return r.bus_type === v; },
      "bus-driver": function (r, v) { return v === "none" ? (r.driver_id === null || r.driver_id === undefined) : String(r.driver_id) === v; }
    },
    state: stateOf("buses"), error: errOf("buses"), retry: function () { load("buses"); },
    rows: function () { return data.buses; },
    emptyMsg: "No buses have been added to the system.",
    searchText: function (r) { return textOf(r.bus_number) + " " + textOf(r.registration_number) + " " + textOf(driverName(r.driver_id)); },
    columns: [
      { cell: function (r) { return el("span", "cell-main", r.bus_number); } },
      { cell: function (r) { return r.bus_type; } },
      { num: true, cell: function (r) { return r.capacity; } },
      { cell: function (r) { return r.registration_number; } },
      { cell: function (r) {
          var n = driverName(r.driver_id);
          return n === null ? chip("Unassigned", "chip--new") : n;
        } },
      { cell: function () { return el("span", "cell-muted", "Pending"); } }
    ]
  });

  tables.drivers = new DataTable({
    id: "tbl-drivers", noun: "drivers", search: "drv-search",
    state: stateOf("drivers"), error: errOf("drivers"), retry: function () { load("drivers"); },
    rows: function () { return data.drivers; },
    emptyMsg: "No drivers have been added to the system.",
    searchText: function (r) { return textOf(r.name) + " " + textOf(r.email) + " " + textOf(r.license_number); },
    columns: [
      { cell: function (r) { return el("span", "cell-main", r.name); } },
      { cell: function (r) { return r.email; } },
      { cell: function (r) { return r.license_number; } },
      { cell: function (r) { return r.phone; } },
      { cell: function (r) {
          if (!data.buses) { return el("span", "cell-muted", status.buses === "error" ? "Bus data unavailable" : "Loading…"); }
          var b = busFor(r.driver_id);
          return b.length ? b.join(", ") : chip("No bus", "chip--ph");
        } }
    ]
  });

  var selectedRouteId = null;
  tables.routes = new DataTable({
    id: "tbl-routes", noun: "routes", search: "rt-search",
    state: stateOf("routes"), error: errOf("routes"), retry: function () { load("routes"); },
    rows: function () { return data.routes; },
    emptyMsg: "No routes have been added to the system.",
    rowClass: function (r) { return r.route_id === selectedRouteId ? "is-selected" : ""; },
    searchText: function (r) { return textOf(r.route_code) + " " + textOf(r.route_name) + " " + textOf(r.start_point) + " " + textOf(r.end_point); },
    columns: [
      { cell: function (r) { return el("span", "cell-main", r.route_code); } },
      { cell: function (r) { return r.route_name; } },
      { cell: function (r) { return r.start_point; } },
      { cell: function (r) { return r.end_point; } },
      { cell: function (r) { return boolChip(r.is_active, "Active", "Inactive"); } },
      { cell: function (r) {
          var b = el("button", "btn btn--sm", "View stops"); b.type = "button";
          b.setAttribute("aria-label", "View stops for route " + textOf(r.route_code));
          b.addEventListener("click", function () { loadStops(r); });
          var w = el("div", "row-actions"); w.appendChild(b); return w;
        } }
    ]
  });

  /* ---- stops of the selected route (GET /users/routes/{id}/stops) ---- */
  var stops = { status: "idle", rows: [], error: "" };
  tables.stops = new DataTable({
    id: "tbl-stops", noun: "stops",
    state: function () { return stops.status; }, error: function () { return stops.error; },
    retry: function () { var r = findRoute(selectedRouteId); if (r) { loadStops(r); } },
    rows: function () { return stops.rows; },
    idleTitle: "No route selected", idleMsg: "Choose “View stops” on a route to see its stops in order.",
    emptyMsg: "This route has no stops yet.",
    searchText: function () { return ""; },
    columns: [
      { num: true, cell: function (r) { return r.stop_order; } },
      { cell: function (r) { return el("span", "cell-main", r.stop_name); } },
      { num: true, cell: function (r) { return r.latitude; } },
      { num: true, cell: function (r) { return r.longitude; } }
    ]
  });
  function findRoute(id) {
    if (!data.routes) { return null; }
    for (var i = 0; i < data.routes.length; i++) { if (data.routes[i].route_id === id) { return data.routes[i]; } }
    return null;
  }
  function loadStops(route) {
    selectedRouteId = route.route_id;
    $("stopsRouteName").textContent = "— " + route.route_code + " " + route.route_name;
    stops.status = "loading"; tables.routes.render(); tables.stops.render();
    api("/users/routes/" + encodeURIComponent(route.route_id) + "/stops").then(function (rows) {
      if (selectedRouteId !== route.route_id) { return; }   // a newer selection superseded this one
      if (!Array.isArray(rows)) { throw new ApiError(200, "Unexpected response format."); }
      stops.rows = rows; stops.status = "ready";
    }).catch(function (e) {
      if (selectedRouteId !== route.route_id) { return; }
      stops.status = "error"; stops.error = (e && e.message) || "Unknown error.";
    }).then(function () { tables.stops.render(); });
  }

  /* ------------------------------------------------------------- overview */
  function setKpi(key, value, st, err) {
    var v = document.querySelector('[data-kpi="' + key + '"]');
    var n = document.querySelector('[data-kpi-note="' + key + '"]');
    if (!v) { return; }
    v.classList.remove("skeleton");
    if (st === "loading" || st === "idle") { v.classList.add("skeleton"); v.textContent = "000"; }
    else if (st === "error") { v.textContent = "—"; }
    else { v.textContent = String(value); }
    if (n) {
      if (!n.dataset.base) { n.dataset.base = n.textContent; }
      n.textContent = st === "error" ? "Could not load. See the section page for details." : n.dataset.base;
      n.title = st === "error" ? err : "";
      n.classList.toggle("error-inline", st === "error");
    }
  }
  function renderKpis() {
    var s = status, d = data;
    setKpi("buses", d.buses && d.buses.length, s.buses, errors.buses);
    setKpi("drivers", d.drivers && d.drivers.length, s.drivers, errors.drivers);
    setKpi("routes", d.routes && d.routes.length, s.routes, errors.routes);
    setKpi("active-routes", d.routes && d.routes.filter(function (r) { return r.is_active; }).length, s.routes, errors.routes);
    setKpi("buses-assigned", d.buses && d.buses.filter(function (b) { return b.driver_id !== null && b.driver_id !== undefined; }).length, s.buses, errors.buses);
    setKpi("users", d.users && d.users.length, s.users, errors.users);
    setKpi("students", d.users && d.users.filter(function (u) { return u.role === "STUDENT"; }).length, s.users, errors.users);
  }

  /* ------------------------------------------------- filter option lists */
  var driverOptionsKey = "";
  function renderDriverFilter() {
    var sel = $("bus-driver");
    var key = status.drivers === "ready" ? data.drivers.map(function (d) { return d.driver_id + ":" + d.name; }).join("|") : "";
    if (key === driverOptionsKey && sel.options.length > 1) { return; }
    driverOptionsKey = key;
    var current = sel.value;
    var frag = document.createDocumentFragment();
    [["", "All drivers"], ["none", "Unassigned"]].forEach(function (o) { var op = el("option", null, o[1]); op.value = o[0]; frag.appendChild(op); });
    if (status.drivers === "ready") {
      data.drivers.forEach(function (d) { var op = el("option", null, d.name); op.value = String(d.driver_id); frag.appendChild(op); });
    }
    sel.replaceChildren(frag);
    sel.value = current && sel.querySelector('option[value="' + current + '"]') ? current : "";
    tables.buses.filters["bus-driver"] = sel.value;
  }

  /* --------------------------------------------------------------- render */
  function renderAll() {
    renderKpis();
    renderDriverFilter();
    Object.keys(tables).forEach(function (k) { tables[k].render(); });
  }

  /* ----------------------------------------------------------- user chip */
  var name = auth.name || "Administrator";
  $("userName").textContent = name;
  $("userRole").textContent = auth.role === "ADMIN" ? "Administrator" : "Admin (verified by server)";
  $("userAvatar").textContent = name.trim().charAt(0).toUpperCase() || "A";

  $("signOutBtn").addEventListener("click", function () { clearAuth(); goToLogin(); });

  /* -------------------------------------------------------------- refresh */
  var refreshBtn = $("refreshBtn"), stamp = $("lastRefreshed");
  function loadAll() {
    refreshBtn.disabled = true; refreshBtn.setAttribute("aria-busy", "true");
    return Promise.all(Object.keys(PATHS).map(load)).then(function () {
      refreshBtn.disabled = false; refreshBtn.removeAttribute("aria-busy");
      var failed = Object.keys(PATHS).filter(function (k) { return status[k] === "error"; });
      stamp.textContent = "Last refreshed " + new Date().toLocaleTimeString();
      if (failed.length) { toast("Could not load: " + failed.join(", ") + ". See the messages on each page.", "error"); }
      if (selectedRouteId !== null) { var r = findRoute(selectedRouteId); if (r) { loadStops(r); } }
      return failed.length;
    });
  }
  refreshBtn.addEventListener("click", function () {
    loadAll().then(function (failed) { if (!failed) { toast("Data refreshed.", "success"); } });
  });



    // Add Driver form submission
  var driverForm = $("driverForm");

  if (driverForm) {
    driverForm.addEventListener("submit", function (event) {
      event.preventDefault();

      if (!driverForm.reportValidity()) return;

      var saveButton = driverForm.querySelector('button[type="submit"]');

      var payload = {
        name: $("d_name").value.trim(),
        email: $("d_email").value.trim(),
        password: $("d_password").value,
        license_number: $("license_number").value.trim(),
        phone: $("phone").value.trim()
      };

      saveButton.disabled = true;
      saveButton.textContent = "Saving...";

      apiPost("/users/drivers", payload)
        .then(function (result) {
          toast(result.message || "Driver created successfully.", "success");
          driverForm.reset();

          var dialog = $("dlg-driver");
          if (dialog && dialog.open) dialog.close();

          return loadAll();
        })
        .catch(function (err) {
          toast("Could not create driver: " + err.message, "error");
        })
        .finally(function () {
          saveButton.disabled = false;
          saveButton.textContent = "Save Driver";
        });
    });
  }

  renderAll();
  loadAll();
})();

 