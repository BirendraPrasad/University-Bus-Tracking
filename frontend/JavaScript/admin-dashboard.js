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

  var API_BASE = window.API_BASE_URL;   // same base URL the login and driver pages use
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

// PUT, DELETE and photo upload API
function apiMutation(path, method, payload, isFormData) {
  var ctrl = new AbortController();
  var timer = setTimeout(function () {
    ctrl.abort();
  }, REQUEST_TIMEOUT_MS);

  var headers = {
    "Accept": "application/json",
    "Authorization": "Bearer " + auth.token
  };

  if (!isFormData && payload !== undefined && method !== "DELETE") {
    headers["Content-Type"] = "application/json";
  }

  var options = {
    method: method,
    headers: headers,
    signal: ctrl.signal
  };

  if (payload !== undefined && method !== "DELETE") {
    options.body = isFormData ? payload : JSON.stringify(payload);
  }

  return fetch(API_BASE + path, options)
    .then(function (res) {
      clearTimeout(timer);

      return res.text().then(function (txt) {
        var body = null;

        try {
          body = txt ? JSON.parse(txt) : null;
        } catch (e) {}

        if (!res.ok) {
          if (res.status === 401) {
            clearAuth();
            goToLogin();
          }

          throw new ApiError(
            res.status,
            detailText(body) || "Request failed (" + res.status + ")."
          );
        }

        return body;
      });
    })
    .catch(function (err) {
      clearTimeout(timer);

      if (err instanceof ApiError) throw err;

      if (err && err.name === "AbortError") {
        throw new ApiError(0, "Request timed out.");
      }

      throw new ApiError(0, "Cannot connect to FastAPI server.");
    });
}



/* ================= ADMIN NOTIFICATIONS ================= */

var adminNotifications = [];
var unreadNotificationCount = 0;

function loadNotifications() {
  return api("/notifications/")
    .then(function (result) {
      adminNotifications = result.notifications || [];
      unreadNotificationCount = result.unread_count || 0;
      renderNotifications();
    })
    .catch(function (err) {
      console.error("Notification loading failed:", err);
    });
}

function renderNotifications() {
  var list = $("notificationList");
  var count = $("notificationCount");
  var unreadText = $("notificationUnreadText");

  if (!list || !count || !unreadText) return;

  count.textContent = unreadNotificationCount;
  count.hidden = unreadNotificationCount === 0;

  unreadText.textContent =
    unreadNotificationCount + " unread notifications";

  list.replaceChildren();

  if (adminNotifications.length === 0) {
    list.appendChild(el("p", "notification-empty", "No notifications yet."));
    return;
  }

  adminNotifications.forEach(function (item) {
    var card = el(
      "div",
      item.is_read ? "notification-item" : "notification-item unread"
    );

    var title = el("strong", "notification-title", item.title);
    var message = el("p", "notification-message", item.message);
    var time = el(
      "small",
      "notification-time",
      new Date(item.created_at).toLocaleString()
    );

    card.appendChild(title);
    card.appendChild(message);
    card.appendChild(time);

    if (!item.is_read) {
      card.addEventListener("click", function () {
        apiMutation(
          "/notifications/" + item.notification_id + "/read",
          "PATCH"
        ).then(function () {
          return loadNotifications();
        }).catch(function (err) {
          toast("Could not mark notification as read: " + err.message, "error");
        });
      });
    }

    list.appendChild(card);
  });
}

// Mark All as Read button
var markAllBtn = el("button", "mark-all-notifications", "Mark All as Read");

markAllBtn.type = "button";
markAllBtn.addEventListener("click", function () {
  apiMutation("/notifications/read-all", "PATCH")
    .then(function () {
      return loadNotifications();
    })
    .catch(function (err) {
      toast("Could not mark notifications as read: " + err.message, "error");
    });
});

var notificationPanel = $("notificationPanel");

if (notificationPanel) {
  notificationPanel.insertBefore(
    markAllBtn,
    notificationPanel.firstChild
  );
}


  /* ---------------------------------------------------------------- data */
 var data = {
    users: null,
    buses: null,
    drivers: null,
    routes: null,
    faculty: null,
    students: null,
    trips: null
};

var status = {
    users: "idle",
    buses: "idle",
    drivers: "idle",
    routes: "idle",
    faculty: "idle",
    students: "idle",
    trips: "idle"
};

var errors = {
    users: "",
    buses: "",
    drivers: "",
    routes: "",
    faculty: "",
    students: "",
    trips: ""
};

var PATHS = {
    users: "/users/",
    buses: "/users/buses",
    drivers: "/users/drivers",
    routes: "/users/routes",
    faculty: "/users/faculty",
    students: "/users/students",
    trips: "/trips/"
};


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

  function busPhoto(path, label) {
  if (!path) {
    return el("span", "cell-muted", "No photo");
  }

  var img = el("img", "bus-thumb");

  img.src = API_BASE + path;
  img.alt = label;
  img.loading = "lazy";
  img.style.width = "76px";
  img.style.height = "48px";
  img.style.objectFit = "cover";
  img.style.borderRadius = "6px";

  return img;
}

  function stateOf(name) { return function () { return status[name]; }; }
  function errOf(name) { return function () { return errors[name]; }; }

  /* -------------------------------------------------------- table configs */
  var tables = {};


// ================= USERS TABLE =================

tables.users = new DataTable({
    id: "tbl-users",
    noun: "users",
    search: "usr-search",

    filters: {
        "usr-role": function (r, v) {
            return r.role === v;
        }
    },

    state: stateOf("users"),
    error: errOf("users"),

    retry: function () {
        load("users");
    },

    rows: function () {
        return data.users;
    },

    emptyMsg: "The users table has no accounts.",

    searchText: function (r) {
        return textOf(r.name) + " " + textOf(r.email);
    },

    columns: [
        {
            num: true,
            cell: function (r) {
                return r.user_id;
            }
        },
        {
            cell: function (r) {
                return el("span", "cell-main", textOf(r.name) || "—");
            }
        },
        {
            cell: function (r) {
                return r.email;
            }
        },
        {
            cell: function (r) {
                return roleChip(r.role);
            }
        },

       {
          cell: function (r) {
              return boolChip(r.is_active, "Active", "Inactive");
          }
        },
       {
          cell: function (r) {
           var wrap = el("div", "row-actions");

              // Edit Button
             var edit = el("button", "btn btn--sm", "Edit");
              edit.type = "button";

              edit.addEventListener("click", function () {
                  openUserEditor(r);
              });

              // Activate / Deactivate Button
              var toggle = el(
                  "button",
                  "btn btn--sm",
                  r.is_active ? "Deactivate" : "Activate"
              );
              toggle.type = "button";

              toggle.addEventListener("click", function () {
                  changeUserStatus(r);
              });

              wrap.appendChild(edit);
              wrap.appendChild(toggle);

               return wrap;
      }
  }

]
});


// ================= OPEN USER EDITOR =================

function openUserEditor(user) {
    $("edit_user_id").value = user.user_id;
    $("edit_user_role").value = user.role;

    $("edit_name").value = user.name || "";
    $("edit_email").value = user.email || "";

    // Hide all role-specific fields first
    $("edit-driver-fields").hidden = true;
    $("edit-driver-phone-field").hidden = true;
    $("edit-student-fields").hidden = true;
    $("edit-student-dept-field").hidden = true;
    $("edit-student-sem-field").hidden = true;
    $("edit-faculty-fields").hidden = true;
    $("edit-faculty-dept-field").hidden = true;

    if (user.role === "DRIVER") {
        var driver = (data.drivers || []).find(function (r) {
            return r.user_id === user.user_id;
        });

        if (driver) {
            $("edit-driver-fields").hidden = false;
            $("edit-driver-phone-field").hidden = false;
            $("edit_license").value = driver.license_number || "";
            $("edit_phone").value = driver.phone || "";
        }

    } else if (user.role === "STUDENT") {
        var student = (data.students || []).find(function (r) {
            return r.user_id === user.user_id;
        });

        if (student) {
            $("edit-student-fields").hidden = false;
            $("edit-student-dept-field").hidden = false;
            $("edit-student-sem-field").hidden = false;
            $("edit_enrollment").value = student.enrollment_no || "";
            $("edit_student_department").value = student.department || "";
            $("edit_semester").value = student.semester || "";
        }

    } else if (user.role === "FACULTY") {
        var faculty = (data.faculty || []).find(function (r) {
            return r.user_id === user.user_id;
        });

        if (faculty) {
            $("edit-faculty-fields").hidden = false;
            $("edit-faculty-dept-field").hidden = false;
            $("edit_employee").value = faculty.employee_id || "";
            $("edit_faculty_department").value = faculty.department || "";
        }
    }

    $("dlg-user-edit").showModal();
}


 // ================= UPDATE USER =================

var editUserForm = $("editUserForm");

if (editUserForm) {
    editUserForm.addEventListener("submit", function (event) {
        event.preventDefault();

        if (!editUserForm.reportValidity()) return;

        var userId = $("edit_user_id").value;
        var role = $("edit_user_role").value;

        var payload = {
            name: $("edit_name").value.trim(),
            email: $("edit_email").value.trim()
        };

        if (role === "DRIVER") {
            payload.license_number = $("edit_license").value.trim();
            payload.phone = $("edit_phone").value.trim();
        }

        if (role === "STUDENT") {
            payload.enrollment_no = $("edit_enrollment").value.trim();
            payload.department = $("edit_student_department").value.trim();
            payload.semester = Number($("edit_semester").value);
        }

        if (role === "FACULTY") {
            payload.employee_id = $("edit_employee").value.trim();
            payload.department = $("edit_faculty_department").value.trim();
        }

        var saveButton = editUserForm.querySelector('button[type="submit"]');
        saveButton.disabled = true;
        saveButton.textContent = "Updating...";

        apiMutation(
            "/users/" + encodeURIComponent(userId),
            "PUT",
            payload,
            false
        )
        .then(function (result) {
            toast(result.message || "User updated successfully.", "success");
            $("dlg-user-edit").close();
            return loadAll();
        })
        .catch(function (err) {
            toast("Could not update user: " + err.message, "error");
        })
        .finally(function () {
            saveButton.disabled = false;
            saveButton.textContent = "Update User";
        });
    });
}


// ================= USER ACTIVATE / DEACTIVATE =================

function changeUserStatus(user) {
    var nextStatus = !user.is_active;

    var action = nextStatus ? "Activate" : "Deactivate";

    if (!confirm(action + " user " + user.name + "?")) {
        return;
    }

    apiMutation(
        "/users/" + encodeURIComponent(user.user_id) + "/status",
        "PATCH",
        {
            is_active: nextStatus
        },
        false
    )
    .then(function (result) {
        toast(
            result.message || "User status updated successfully.",
            "success"
        );

        return loadAll();
    })
    .catch(function (err) {
        toast(
            "Could not update user status: " + err.message,
            "error"
        );
    });
}



// ================= DRIVER REGISTRATION APPROVAL =================

var pendingDriverRequests = [];

function loadDriverRequests() {
    var tbody = $("pendingDriverRequestsBody");

    if (!tbody) return;

    tbody.replaceChildren();

    var loadingRow = el("tr");
    var loadingCell = el("td", null, "Loading requests...");
    loadingCell.colSpan = 7;
    loadingRow.appendChild(loadingCell);
    tbody.appendChild(loadingRow);

    return api("/users/driver-requests")
        .then(function (result) {

            // API may return an array or an object containing requests
            pendingDriverRequests = Array.isArray(result)
                ? result
                : (result.requests || []);

            renderDriverRequests();
        })
        .catch(function (err) {
            tbody.replaceChildren();

            var row = el("tr");
            var cell = el(
                "td",
                null,
                "Could not load requests: " + err.message
            );

            cell.colSpan = 7;
            row.appendChild(cell);
            tbody.appendChild(row);
        });
}


function renderDriverRequests() {
    var tbody = $("pendingDriverRequestsBody");

    if (!tbody) return;

    tbody.replaceChildren();

    if (pendingDriverRequests.length === 0) {
        var row = el("tr");
        var cell = el("td", null, "No pending driver requests.");
        cell.colSpan = 7;
        row.appendChild(cell);
        tbody.appendChild(row);
        return;
    }

    pendingDriverRequests.forEach(function (request) {

        var row = el("tr");

        row.appendChild(el("td", null, request.name || "—"));
        row.appendChild(el("td", null, request.email || "—"));
        row.appendChild(el("td", null, request.license_number || "—"));
        row.appendChild(el("td", null, request.phone || "—"));

        var requestDate = request.created_at
            ? new Date(request.created_at).toLocaleString()
            : "—";

        row.appendChild(el("td", null, requestDate));
        row.appendChild(el("td", null, request.status || "PENDING"));

        var actionsCell = el("td");
        var actions = el("div", "row-actions");

        var approveBtn = el("button", "btn btn--sm", "Approve");
        approveBtn.type = "button";

        approveBtn.addEventListener("click", function () {
            updateDriverRequest(request, "approve", approveBtn);
        });

        var rejectBtn = el("button", "btn btn--sm btn--danger", "Reject");
        rejectBtn.type = "button";

        rejectBtn.addEventListener("click", function () {
            updateDriverRequest(request, "reject", rejectBtn);
        });

        actions.appendChild(approveBtn);
        actions.appendChild(rejectBtn);

        actionsCell.appendChild(actions);
        row.appendChild(actionsCell);

        tbody.appendChild(row);
    });
}


// Approve or Reject Driver Registration
function updateDriverRequest(request, action, button) {

    var requestId = request.request_id;

    if (!requestId) {
        toast("Request ID is missing.", "error");
        return;
    }

    if (action === "reject") {
        if (!confirm("Are you sure you want to reject this driver request?")) {
            return;
        }
    }

    button.disabled = true;
    button.textContent = "Processing...";

    apiMutation(
       "/users/driver-requests/" + encodeURIComponent(requestId) + "/" + action,
        "PUT"
    )
    .then(function (result) {

        toast(
            result.message ||
            "Driver request " + action + "d successfully.",
            "success"
        );

        return Promise.all([
            loadDriverRequests(),
            action === "approve" ? load("drivers") : Promise.resolve()
        ]);
    })
    .catch(function (err) {
        toast(
            "Could not " + action + " driver request: " + err.message,
            "error"
        );

        button.disabled = false;
        button.textContent = action === "approve" ? "Approve" : "Reject";
    });
}


// Refresh Pending Driver Requests
var refreshDriverRequestsBtn = $("refreshDriverRequestsBtn");

if (refreshDriverRequestsBtn) {
    refreshDriverRequestsBtn.addEventListener("click", function () {
        refreshDriverRequestsBtn.disabled = true;

        loadDriverRequests()
            .finally(function () {
                refreshDriverRequestsBtn.disabled = false;
            });
    });
}


  // ================= FACULTY TABLE =================

tables.faculty = new DataTable({
    id: "tbl-faculty",
    noun: "faculty members",
    search: "fac-search",

    filters: {
        "fac-dept": function (row, value) {
            return row.department === value;
        }
    },

    state: stateOf("faculty"),
    error: errOf("faculty"),

    retry: function () {
        load("faculty");
    },

    rows: function () {
        return data.faculty || [];
    },

    emptyMsg: "No faculty members are registered.",

    searchText: function (row) {
        return textOf(row.name) + " " +
            textOf(row.email) + " " +
            textOf(row.employee_id) + " " +
            textOf(row.department);
    },

    columns: [
        { cell: function (row) {
            return el("span", "cell-main", textOf(row.name) || "—");
        }},
        { cell: function (row) {
            return textOf(row.email) || "—";
        }},
        { cell: function (row) {
            return textOf(row.employee_id) || "—";
        }},
        { cell: function (row) {
            return textOf(row.department) || "—";
        }},
        { cell: function (row) {
            return boolChip(row.is_active, "Active", "Inactive");
        }}
    ]
});


// ================= STUDENTS TABLE =================

tables.students = new DataTable({
    id: "tbl-students",
    noun: "students",
    search: "stu-search",

    filters: {
        "stu-dept": function (row, value) {
            return row.department === value;
        },
        "stu-sem": function (row, value) {
            return String(row.semester) === value;
        }
    },

    state: stateOf("students"),
    error: errOf("students"),

    retry: function () {
        load("students");
    },

    rows: function () {
        return data.students || [];
    },

    emptyMsg: "No students are registered.",

    searchText: function (row) {
        return textOf(row.name) + " " +
            textOf(row.email) + " " +
            textOf(row.enrollment_no) + " " +
            textOf(row.department) + " " +
            textOf(row.semester);
    },

    columns: [
        { cell: function (row) {
            return el("span", "cell-main", textOf(row.name) || "—");
        }},
        { cell: function (row) {
            return textOf(row.email) || "—";
        }},
        { cell: function (row) {
            return textOf(row.enrollment_no) || "—";
        }},
        { cell: function (row) {
            return textOf(row.department) || "—";
        }},
        { cell: function (row) {
            return textOf(row.semester) || "—";
        }},
        { cell: function (row) {
            return boolChip(row.is_active, "Active", "Inactive");
        }}
    ]
});



tables.buses = new DataTable({
  id: "tbl-buses",
  noun: "buses",
  search: "bus-search",

  filters: {
    "bus-type": function (r, v) {
      return r.bus_type === v;
    },

    "bus-driver": function (r, v) {
      return v === "none"
        ? (r.driver_id === null || r.driver_id === undefined)
        : String(r.driver_id) === v;
    }
  },

  state: stateOf("buses"),
  error: errOf("buses"),
  retry: function () {
    load("buses");
  },

  rows: function () {
    return data.buses;
  },

  emptyMsg: "No buses have been added to the system.",

  searchText: function (r) {
    return textOf(r.bus_number) + " " +
      textOf(r.registration_number) + " " +
      textOf(driverName(r.driver_id));
  },

  columns: [
    {
      cell: function (r) {
        return el("span", "cell-main", r.bus_number);
      }
    },
    {
      cell: function (r) {
        return r.bus_type;
      }
    },
    {
      cell: function (r) {
        return r.route_code
          ? r.route_code + " - " + (r.route_name || "")
          : chip("Not assigned", "chip--new");
      }
    },
    {
      num: true,
      cell: function (r) {
        return r.capacity;
      }
    },
    {
      cell: function (r) {
        return r.registration_number;
      }
    },
    {
      cell: function (r) {
        var n = driverName(r.driver_id);
        return n === null
          ? chip("Unassigned", "chip--new")
          : n;
      }
    },
    {
      cell: function () {
        return el("span", "cell-muted", "Pending");
      }
    },
    {
      cell: function (r) {
        return busPhoto(r.front_photo, "Front photo");
      }
    },
    {
      cell: function (r) {
        return busPhoto(r.side_photo, "Side photo");
      }
    },
    {
      cell: function (r) {
        var wrap = el("div", "row-actions");

        var edit = el("button", "btn btn--sm", "Edit");
        edit.type = "button";

        edit.addEventListener("click", function () {
          openBusEditor(r);
        });

        var del = el("button", "btn btn--sm btn--danger", "Delete");
        del.type = "button";

        del.addEventListener("click", function () {
          deleteBus(r);
        });

        wrap.appendChild(edit);
        wrap.appendChild(del);

        return wrap;
      }
    }
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


// ================= TRIPS TABLE =================

tables.trips = new DataTable({
  id: "tbl-trips",
  noun: "trips",
  search: "trip-search",

  filters: {
    "trip-status": function (row, value) {
      return row.status === value;
    },
    "trip-date": function (row, value) {
      return String(row.trip_date).slice(0, 10) === value;
    }
  },

  state: stateOf("trips"),
  error: errOf("trips"),

  retry: function () {
    load("trips");
  },

  rows: function () {
    return data.trips || [];
  },

  emptyMsg: "No trips have been created yet.",

 searchText: function (row) {
    return [
        row.trip_id,
        row.bus_number,
        row.route_name,
        row.route_code,
        row.driver_name,
        row.status
    ].map(textOf).join(" ");
},

  columns: [
    {
      num: true,
      cell: function (row) {
        return "TRIP-" + row.trip_id;
      }
    },
    {
      cell: function (row) {
        return row.bus_number || "—";
      }
    },
    {
      cell: function (row) {
        return row.route_code + " - " + row.route_name;
      }
    },
    {
      cell: function (row) {
        return row.driver_name || "—";
      }
    },
    {
      cell: function (row) {
        return row.trip_date
          ? new Date(row.trip_date + "T00:00:00").toLocaleDateString("en-IN")
          : "—";
      }
    },
    {
      cell: function (row) {
        var cls = row.status === "COMPLETED"
          ? "chip--api"
          : row.status === "ACTIVE"
          ? "chip--blue"
          : row.status === "SCHEDULED"
          ? "chip--new"
          : "chip--ph";

        return chip(row.status, cls);
      }
    }
  ]
});


  var selectedRouteId = null;
  var editingRouteId = null;
  var editingStopId = null;
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
          var w = el("div", "row-actions");
          var view = el("button", "btn btn--sm", "View stops");
          view.type = "button";
          view.addEventListener("click", function () { loadStops(r); });

          var edit = el("button", "btn btn--sm", "Edit");
          edit.type = "button";
          edit.addEventListener("click", function () { openRouteEditor(r); });

          var del = el("button", "btn btn--sm", "Delete");
          del.type = "button";
          del.addEventListener("click", function () { deleteRoute(r); });

          w.append(view, edit, del);
          return w;
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
      { num: true, cell: function (r) { return r.longitude; } },
      { cell: function (r) { return r.pickup_time || "—"; } },
      { cell: function (r) { return r.drop_time || "—"; } },
      { cell: function (r) {
          var w = el("div", "row-actions");
          var edit = el("button", "btn btn--sm", "Edit");
          edit.type = "button";
          edit.addEventListener("click", function () { openStopEditor(r); });

          var del = el("button", "btn btn--sm", "Delete");
          del.type = "button";
          del.addEventListener("click", function () { deleteStop(r); });

          w.append(edit, del);
          return w;
        } }
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


// Populate Faculty and Students filters from API data
var peopleFilterOptionsKey = "";

function renderPeopleFilters() {
    
  var facultyDept = $("fac-dept");
    var studentDept = $("stu-dept");
    var studentSem = $("stu-sem");

    if (!facultyDept || !studentDept || !studentSem) return;

    var facultyRows = status.faculty === "ready" ? data.faculty || [] : [];
    var studentRows = status.students === "ready" ? data.students || [] : [];

    var key = JSON.stringify({
        faculty: facultyRows.map(function (r) { return r.department; }),
        studentDept: studentRows.map(function (r) { return r.department; }),
        semester: studentRows.map(function (r) { return r.semester; })
    });

    if (key === peopleFilterOptionsKey) return;
    peopleFilterOptionsKey = key;

    function fillSelect(select, firstLabel, values, currentValue) {
        var frag = document.createDocumentFragment();
        var first = el("option", null, firstLabel);
        first.value = "";
        frag.appendChild(first);

        values.forEach(function (value) {
            var option = el("option", null, String(value));
            option.value = String(value);
            frag.appendChild(option);
        });

        select.replaceChildren(frag);
        select.value = values.map(String).indexOf(currentValue) !== -1
            ? currentValue
            : "";
    }

    var facultyDepartments = [...new Set(
        facultyRows.map(function (r) { return r.department; }).filter(Boolean)
    )].sort();

    var studentDepartments = [...new Set(
        studentRows.map(function (r) { return r.department; }).filter(Boolean)
    )].sort();

    var semesters = [...new Set(
        studentRows.map(function (r) { return r.semester; })
            .filter(function (v) { return v !== null && v !== undefined; })
    )].sort(function (a, b) { return Number(a) - Number(b); });

    fillSelect(facultyDept, "All departments", facultyDepartments, facultyDept.value);
    fillSelect(studentDept, "All departments", studentDepartments, studentDept.value);
    fillSelect(studentSem, "All semesters", semesters, studentSem.value);

    tables.faculty.filters["fac-dept"] = facultyDept.value;
    tables.students.filters["stu-dept"] = studentDept.value;
    tables.students.filters["stu-sem"] = studentSem.value;
}  


// Populate Route dropdown in Add Stop form
function renderStopRouteOptions() {
  var sel = $("stop_route");
  if (!sel) return;

  var currentValue = sel.value;
  var frag = document.createDocumentFragment();

  var placeholder = el("option", null, "Select a route");
  placeholder.value = "";
  frag.appendChild(placeholder);

  if (status.routes === "ready" && Array.isArray(data.routes)) {
    data.routes.forEach(function (route) {
      var option = el(
        "option",
        null,
        route.route_code + " - " + route.route_name
      );
      option.value = String(route.route_id);
      frag.appendChild(option);
    });
  }

  sel.replaceChildren(frag);

  var preferred = selectedRouteId !== null
    ? String(selectedRouteId)
    : currentValue;

  if (preferred && sel.querySelector('option[value="' + preferred + '"]')) {
    sel.value = preferred;
  }
}




// Populate Assigned Route dropdown for Add/Edit Bus
function renderBusRouteOptions(preferredValue) {
  var sel = $("bus_route");
  var typeSelect = $("bus_type");
  if (!sel || !typeSelect) return;

  var currentValue = preferredValue !== undefined
    ? String(preferredValue || "")
    : sel.value;

  var busType = typeSelect.value;

  var allowedCodes = busType === "ROUTE_BUS"
    ? ["R001", "R002", "R003", "R004", "R005", "R006"]
    : busType === "SHUTTLE_BUS"
      ? ["R007", "R008"]
      : [];

  var frag = document.createDocumentFragment();
  var placeholder = el("option", null, "Select a route");
  placeholder.value = "";
  frag.appendChild(placeholder);

  if (status.routes === "ready" && Array.isArray(data.routes)) {
    data.routes.forEach(function (route) {
      if (!route.is_active || !allowedCodes.includes(route.route_code)) return;

      var option = el(
        "option",
        null,
        route.route_code + " - " + route.route_name
      );
      option.value = String(route.route_id);
      frag.appendChild(option);
    });
  }

  sel.replaceChildren(frag);

  if (currentValue && sel.querySelector('option[value="' + currentValue + '"]')) {
    sel.value = currentValue;
  } else {
    sel.value = "";
  }
}


// Populate Create Trip dropdowns
function renderTripOptions() {
  var busSelect = $("trip_bus");
  var routeSelect = $("trip_route");
  var driverSelect = $("trip_driver");

  if (!busSelect || !routeSelect || !driverSelect) return;

  // Bus dropdown
  var busFrag = document.createDocumentFragment();
  var busPlaceholder = el("option", null, "Select Bus");
  busPlaceholder.value = "";
  busFrag.appendChild(busPlaceholder);

  if (status.buses === "ready" && Array.isArray(data.buses)) {
    data.buses.forEach(function (bus) {
      if (bus.driver_id === null || bus.driver_id === undefined) return;

      var option = el("option", null, bus.bus_number);
      option.value = String(bus.bus_id);
      busFrag.appendChild(option);
    });
  }

  var oldBus = busSelect.value;
  busSelect.replaceChildren(busFrag);

  if (oldBus && busSelect.querySelector('option[value="' + oldBus + '"]')) {
    busSelect.value = oldBus;
  }

  // Route dropdown
  var routeFrag = document.createDocumentFragment();
  var routePlaceholder = el("option", null, "Select Active Route");
  routePlaceholder.value = "";
  routeFrag.appendChild(routePlaceholder);

  if (status.routes === "ready" && Array.isArray(data.routes)) {
    data.routes.forEach(function (route) {
      if (route.is_active !== true) return;

      var option = el(
        "option",
        null,
        route.route_code + " - " + route.route_name
      );
      option.value = String(route.route_id);
      routeFrag.appendChild(option);
    });
  }

  var oldRoute = routeSelect.value;
  routeSelect.replaceChildren(routeFrag);

  if (oldRoute && routeSelect.querySelector('option[value="' + oldRoute + '"]')) {
    routeSelect.value = oldRoute;
  }

  // Driver dropdown follows selected bus
  updateTripDriver();
}

function updateTripDriver() {
  var busSelect = $("trip_bus");
  var driverSelect = $("trip_driver");

  if (!busSelect || !driverSelect) return;

  driverSelect.replaceChildren();

  var placeholder = el("option", null, "Select a bus first");
  placeholder.value = "";
  driverSelect.appendChild(placeholder);

  var selectedBus = (data.buses || []).find(function (bus) {
    return String(bus.bus_id) === busSelect.value;
  });

  if (!selectedBus || selectedBus.driver_id == null) return;

  var assignedDriver = (data.drivers || []).find(function (driver) {
    return String(driver.driver_id) === String(selectedBus.driver_id);
  });

  if (!assignedDriver) {
    placeholder.textContent = "Assigned driver not found";
    return;
  }

  var option = el("option", null, assignedDriver.name);
  option.value = String(assignedDriver.driver_id);
  driverSelect.appendChild(option);
  driverSelect.value = option.value;
}


  /* -------------------------------------------------------- GPS Simulator */
  function initGpsSimulator() {
    var busSelect = $("gps-sim-bus");
    var latInput = $("gps-sim-lat");
    var lngInput = $("gps-sim-lng");
    var insideBtn = $("gps-sim-inside");
    var outsideBtn = $("gps-sim-outside");
    var statusEl = $("gps-sim-status");

    if (!busSelect || !latInput || !lngInput || !insideBtn || !outsideBtn || !statusEl) return;

    var previousBus = busSelect.value;
    busSelect.replaceChildren();

    var placeholder = el("option", null, "Select a bus");
    placeholder.value = "";
    busSelect.appendChild(placeholder);

    if (status.buses === "ready" && Array.isArray(data.buses)) {
      data.buses.forEach(function (bus) {
        if (bus.driver_id == null) return;
        var option = el("option", null, bus.bus_number);
        option.value = String(bus.bus_id);
        busSelect.appendChild(option);
      });
    } else if (status.buses === "error") {
      placeholder.textContent = "Bus list unavailable";
    } else {
      placeholder.textContent = "Loading buses...";
    }

    if (previousBus && busSelect.querySelector('option[value="' + previousBus + '"]')) {
      busSelect.value = previousBus;
    }

    function sendLocation(latitude, longitude) {
      var busId = busSelect.value;
      if (!busId) {
        statusEl.textContent = "Please select a bus first.";
        return;
      }

      insideBtn.disabled = true;
      outsideBtn.disabled = true;
      statusEl.textContent = "Sending simulated GPS location...";

      apiPost("/drivers/admin/gps-simulator/" + encodeURIComponent(busId) + "/location", {
        latitude: latitude,
        longitude: longitude,
        speed: 20
      }).then(function (result) {
        var action = result.trip_action || "NONE";
        statusEl.textContent =
          "Bus: " + (result.bus_number || busId) +
          " | " + (result.message || "Location received") +
          " | Action: " + action +
          " | Source: " + (result.source || "SIMULATED") +
          (result.trip_id ? " | Trip ID: " + result.trip_id : "");
      }).catch(function (error) {
        statusEl.textContent = "Simulator error: " + ((error && error.message) || "Request failed");
      }).finally(function () {
        insideBtn.disabled = false;
        outsideBtn.disabled = false;
      });
    }

    insideBtn.onclick = function () {
      latInput.value = "13.219992";
      lngInput.value = "77.753943";
      sendLocation(13.219992, 77.753943);
    };

    outsideBtn.onclick = function () {
      latInput.value = "13.225000";
      lngInput.value = "77.753943";
      sendLocation(13.225000, 77.753943);
    };

    latInput.onchange = function () {
      // Coordinates can also be edited manually.
    };
    lngInput.onchange = function () {
      // Coordinates can also be edited manually.
    };

    latInput.onkeydown = lngInput.onkeydown = function (event) {
      if (event.key === "Enter") {
        var lat = Number(latInput.value);
        var lng = Number(lngInput.value);
        if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          statusEl.textContent = "Enter valid latitude and longitude.";
          return;
        }
        sendLocation(lat, lng);
      }
    };
  }


  /* ------------------------------------------------------ schedule management */
  var scheduleRecords = [];
  var editingScheduleId = null;

  function scheduleTime(value) {
    return value ? String(value).slice(0, 5) : "—";
  }

  function scheduleCell(row, value) {
    var cell = document.createElement("td");
    cell.textContent = value == null || value === "" ? "—" : String(value);
    row.appendChild(cell);
    return cell;
  }

  function populateScheduleOptions() {
    var busSelect = $("schedule_bus");
    var routeSelect = $("schedule_route");
    if (!busSelect || !routeSelect) return;

    busSelect.replaceChildren();
    routeSelect.replaceChildren();

    function addOption(select, value, label) {
      var option = document.createElement("option");
      option.value = value;
      option.textContent = label;
      select.appendChild(option);
    }

    addOption(busSelect, "", "Select bus");
    (data.buses || []).forEach(function (bus) {
      addOption(busSelect, String(bus.bus_id), bus.bus_number);
    });

    addOption(routeSelect, "", "Select route");
    (data.routes || []).forEach(function (route) {
      if (route.is_active === false) return;
      addOption(
        routeSelect,
        String(route.route_id),
        route.route_code + " - " + route.route_name
      );
    });
  }

  function renderSchedules() {
    var tbody = $("tbl-schedules").querySelector("tbody");
    var search = ($("schedule-search").value || "").trim().toLowerCase();
    var direction = $("schedule-direction-filter").value;

    tbody.replaceChildren();

    var visible = scheduleRecords.filter(function (item) {
      var text = [
        item.bus_number, item.route_name, item.direction,
        item.day_of_week
      ].join(" ").toLowerCase();

      return (!search || text.includes(search)) &&
        (!direction || item.direction === direction);
    });

    if (!visible.length) {
      var emptyRow = document.createElement("tr");
      var emptyCell = document.createElement("td");
      emptyCell.colSpan = 7;
      emptyCell.textContent = scheduleRecords.length
        ? "No schedules match your filters."
        : "No schedules found.";
      emptyRow.appendChild(emptyCell);
      tbody.appendChild(emptyRow);
    }

    visible.forEach(function (item) {
      var row = document.createElement("tr");
      scheduleCell(row, item.bus_number);
      scheduleCell(row, item.route_name);
      scheduleCell(row, item.direction);
      scheduleCell(row, scheduleTime(item.departure_time));
      scheduleCell(row, scheduleTime(item.arrival_time));
      scheduleCell(row, item.day_of_week);

      var actions = document.createElement("td");
      var edit = document.createElement("button");
      edit.type = "button";
      edit.className = "btn btn--sm";
      edit.textContent = "Edit";
      edit.addEventListener("click", function () {
        openScheduleEditor(item);
      });

      var remove = document.createElement("button");
      remove.type = "button";
      remove.className = "btn btn--sm";
      remove.textContent = "Delete";
      remove.style.marginLeft = "6px";
      remove.addEventListener("click", function () {
        deleteSchedule(item);
      });

      actions.appendChild(edit);
      actions.appendChild(remove);
      row.appendChild(actions);
      tbody.appendChild(row);
    });

    $("schedule-count").textContent =
      visible.length + " of " + scheduleRecords.length + " schedules";
  }

  function loadSchedules() {
    var tbody = $("tbl-schedules").querySelector("tbody");
    if (tbody) {
      tbody.replaceChildren();
      var row = document.createElement("tr");
      var cell = document.createElement("td");
      cell.colSpan = 7;
      cell.textContent = "Loading schedules...";
      row.appendChild(cell);
      tbody.appendChild(row);
    }

    return api("/schedules/").then(function (records) {
      scheduleRecords = Array.isArray(records) ? records : [];
      renderSchedules();
    }).catch(function (error) {
      if (tbody) {
        tbody.replaceChildren();
        var row = document.createElement("tr");
        var cell = document.createElement("td");
        cell.colSpan = 7;
        cell.textContent = "Could not load schedules: " + error.message;
        row.appendChild(cell);
        tbody.appendChild(row);
      }
      toast("Could not load schedules: " + error.message, "error");
    });
  }

  function openScheduleEditor(item) {
    var form = $("scheduleForm");
    form.reset();
    populateScheduleOptions();

    editingScheduleId = item ? item.schedule_id : null;

    $("dlg-schedule-title").textContent =
      item ? "Edit schedule" : "Add schedule";

    if (item) {
      $("schedule_bus").value = String(item.bus_id);
      $("schedule_route").value = String(item.route_id);
      $("schedule_direction").value = item.direction;
      $("schedule_day").value = item.day_of_week || "WORKING_DAYS";
      $("schedule_departure").value = scheduleTime(item.departure_time);
      $("schedule_arrival").value =
        item.arrival_time ? scheduleTime(item.arrival_time) : "";
    }

    $("dlg-schedule").showModal();
  }

  function deleteSchedule(item) {
    if (!confirm(
      "Delete schedule for " + item.bus_number + " on " +
      item.route_name + " (" + item.direction + ")?"
    )) return;

    apiMutation(
      "/schedules/" + encodeURIComponent(item.schedule_id),
      "DELETE"
    ).then(function () {
      toast("Schedule deleted successfully.", "success");
      return loadSchedules();
    }).catch(function (error) {
      toast("Could not delete schedule: " + error.message, "error");
    });
  }

  $("addScheduleBtn").addEventListener("click", function () {
    openScheduleEditor(null);
  });

  $("schedule-search").addEventListener("input", renderSchedules);
  $("schedule-direction-filter").addEventListener("change", renderSchedules);

  $("scheduleForm").addEventListener("submit", function (event) {
    event.preventDefault();
    var form = event.currentTarget;
    if (!form.reportValidity()) return;

    var payload = {
      bus_id: Number($("schedule_bus").value),
      route_id: Number($("schedule_route").value),
      departure_time: $("schedule_departure").value,
      arrival_time: $("schedule_arrival").value || null,
      day_of_week: $("schedule_day").value,
      direction: $("schedule_direction").value
    };

    var saveButton = form.querySelector('button[type="submit"]');
    saveButton.disabled = true;

    var request = editingScheduleId !== null
      ? apiMutation(
          "/schedules/" + encodeURIComponent(editingScheduleId),
          "PUT",
          payload
        )
      : apiPost("/schedules/", payload);

    request.then(function () {
      $("dlg-schedule").close();
      toast(
        editingScheduleId !== null
          ? "Schedule updated successfully."
          : "Schedule created successfully.",
        "success"
      );
      editingScheduleId = null;
      return loadSchedules();
    }).catch(function (error) {
      toast("Could not save schedule: " + error.message, "error");
    }).finally(function () {
      saveButton.disabled = false;
    });
  });

  /* --------------------------------------------------------------- render */
function renderAll() {
  renderKpis();
  renderDriverFilter();
  renderPeopleFilters();
  renderStopRouteOptions();
  renderBusRouteOptions();
  renderTripOptions();
  initGpsSimulator();
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
      loadSchedules();
      return failed.length;
    });
  }
  refreshBtn.addEventListener("click", function () {
    loadAll().then(function (failed) { if (!failed) { toast("Data refreshed.", "success"); } });
  });



  // Update assigned driver when bus changes
var tripBusSelect = $("trip_bus");

if (tripBusSelect) {
  tripBusSelect.addEventListener("change", updateTripDriver);
}


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


  // Add Student form submission
  var studentForm = $("studentForm");

  if (studentForm) {
    studentForm.addEventListener("submit", function (event) {
      event.preventDefault();

      if (!studentForm.reportValidity()) return;

      var saveButton = studentForm.querySelector('button[type="submit"]');

      var payload = {
        name: $("s_name").value.trim(),
        email: $("s_email").value.trim(),
        password: $("s_password").value,
        enrollment_no: $("enrollment_no").value.trim(),
        department: $("s_department").value.trim(),
        semester: Number($("semester").value)
      };

      saveButton.disabled = true;
      saveButton.textContent = "Saving...";

      apiPost("/users/students", payload)
        .then(function (result) {
          toast(result.message || "Student created successfully.", "success");
          studentForm.reset();

          var dialog = $("dlg-student");
          if (dialog && dialog.open) dialog.close();

          return loadAll();
        })
        .catch(function (err) {
          toast("Could not create student: " + err.message, "error");
        })
        .finally(function () {
          saveButton.disabled = false;
          saveButton.textContent = "Save Student";
        });
    });
  }


  // Add Faculty form submission
  var facultyForm = $("facultyForm");

  if (facultyForm) {
    facultyForm.addEventListener("submit", function (event) {
      event.preventDefault();

      if (!facultyForm.reportValidity()) return;

      var saveButton = facultyForm.querySelector('button[type="submit"]');

      var payload = {
        name: $("f_name").value.trim(),
        email: $("f_email").value.trim(),
        password: $("f_password").value,
        employee_id: $("employee_id").value.trim(),
        department: $("f_department").value.trim()
      };

      saveButton.disabled = true;
      saveButton.textContent = "Saving...";

      apiPost("/users/faculty", payload)
        .then(function (result) {
          toast(result.message || "Faculty created successfully.", "success");
          facultyForm.reset();

          var dialog = $("dlg-faculty");
          if (dialog && dialog.open) dialog.close();

          return loadAll();
        })
        .catch(function (err) {
          toast("Could not create faculty: " + err.message, "error");
        })
        .finally(function () {
          saveButton.disabled = false;
          saveButton.textContent = "Save Faculty";
        });
    });
  }


// ---------------- BUS CRUD AND PHOTO UPLOAD ----------------

var busForm = $("busForm");
var editingBusId = null;


// Open bus form for editing
function openBusEditor(bus) {
  editingBusId = bus.bus_id;

  $("dlg-bus-t").textContent = "Edit Bus — " + bus.bus_number;

  $("bus_number").value = bus.bus_number || "";
  $("bus_type").value = bus.bus_type || "";
  $("capacity").value = bus.capacity || "";
  $("registration_number").value = bus.registration_number || "";
  renderBusRouteOptions(bus.route_id);

  $("front_photo").value = "";
  $("side_photo").value = "";

  setBusPhotoPreview("front_photo", "front_photo_preview", bus.front_photo);
  setBusPhotoPreview("side_photo", "side_photo_preview", bus.side_photo);

  $("dlg-bus").showModal();
}


// Bus photo previews: existing images and newly selected images
function setBusPhotoPreview(inputId, previewId, savedPath) {
  var input = $(inputId);
  var preview = $(previewId);

  if (!input || !preview) return;

  if (preview.dataset.objectUrl) {
    URL.revokeObjectURL(preview.dataset.objectUrl);
    delete preview.dataset.objectUrl;
  }

  var file = input.files && input.files[0];

  if (file) {
    var objectUrl = URL.createObjectURL(file);
    preview.dataset.objectUrl = objectUrl;
    preview.src = objectUrl;
    preview.hidden = false;
    return;
  }

  if (savedPath) {
    preview.src = API_BASE + savedPath;
    preview.hidden = false;
  } else {
    preview.removeAttribute("src");
    preview.hidden = true;
  }
}

["front_photo", "side_photo"].forEach(function (id) {
  var input = $(id);
  if (!input) return;

  input.addEventListener("change", function () {
    setBusPhotoPreview(
      id,
      id + "_preview",
      null
    );
  });
});


// Refresh available routes when Bus Type changes
var busTypeSelect = $("bus_type");
if (busTypeSelect) {
  busTypeSelect.addEventListener("change", function () {
    renderBusRouteOptions("");
  });
}


// Open form for adding a new bus
document.querySelectorAll('[data-open-dialog="dlg-bus"]').forEach(function (btn) {
  btn.addEventListener("click", function () {
    editingBusId = null;

    busForm.reset();
    renderBusRouteOptions("");

    setBusPhotoPreview("front_photo", "front_photo_preview", null);
    setBusPhotoPreview("side_photo", "side_photo_preview", null);

    $("dlg-bus-t").textContent = "Add Bus";
  });
});


// Upload bus photos
function uploadBusPhotos(busId) {
  var front = $("front_photo").files[0];
  var side = $("side_photo").files[0];

  if (!front && !side) {
    return Promise.resolve();
  }

  var formData = new FormData();

  if (front) {
    formData.append("front_photo", front);
  }

  if (side) {
    formData.append("side_photo", side);
  }

  return apiMutation(
    "/users/buses/" + busId + "/photos",
    "POST",
    formData,
    true
  );
}


// Delete bus
function deleteBus(bus) {
  if (!confirm("Delete bus " + bus.bus_number + "?")) {
    return;
  }

  apiMutation(
    "/users/buses/" + bus.bus_id,
    "DELETE"
  )
    .then(function () {
      toast("Bus deleted successfully.", "success");
      return loadAll();
    })
    .catch(function (err) {
      toast("Could not delete bus: " + err.message, "error");
    });
}




  // Route and Stop Add/Edit/Delete actions
  function openRouteEditor(route) {
    editingRouteId = route.route_id;
    $("route_name").value = route.route_name || "";
    $("route_code").value = route.route_code || "";
    $("start_point").value = route.start_point || "";
    $("end_point").value = route.end_point || "";
    $("description").value = route.description || "";
    $("dlg-route-t").textContent = "Edit Route";
    $("routeForm").querySelector(".note").textContent = "Update the route details and save your changes.";
    $("routeForm").querySelector('button[type="submit"]').textContent = "Update Route";
    $("dlg-route").showModal();
  }

  function deleteRoute(route) {
    if (!confirm("Delete route " + route.route_code + " - " + route.route_name + "?")) return;

    apiMutation("/users/routes/" + encodeURIComponent(route.route_id), "DELETE")
      .then(function (result) {
        if (selectedRouteId === route.route_id) {
          selectedRouteId = null;
          stops.rows = [];
          stops.status = "idle";
          $("stopsRouteName").textContent = "";
          tables.stops.render();
        }
        toast(result.message || "Route deleted successfully.", "success");
        return loadAll();
      })
      .catch(function (err) {
        toast("Could not delete route: " + err.message, "error");
      });
  }

  function openStopEditor(stop) {
    editingStopId = stop.stop_id;
    $("stop_route").value = String(stop.route_id);
    $("stop_route").disabled = true;
    $("stop_name").value = stop.stop_name || "";
    $("latitude").value = stop.latitude;
    $("longitude").value = stop.longitude;
    $("stop_order").value = stop.stop_order;
    $("stop_pickup_time").value = stop.pickup_time ? stop.pickup_time.substring(0, 5) : "";
    $("stop_drop_time").value = stop.drop_time ? stop.drop_time.substring(0, 5) : "";
    $("dlg-stop-t").textContent = "Edit Stop";
    $("dlg-stop").showModal();
  }

  function deleteStop(stop) {
    if (!confirm("Delete stop " + stop.stop_name + "?")) return;

    apiMutation("/users/stops/" + encodeURIComponent(stop.stop_id), "DELETE")
      .then(function (result) {
        toast(result.message || "Stop deleted successfully.", "success");
        var route = findRoute(selectedRouteId);
        if (route) return loadStops(route);
      })
      .catch(function (err) {
        toast("Could not delete stop: " + err.message, "error");
      });
  }

  // Reset forms when Add buttons are clicked.
  document.querySelectorAll('[data-open-dialog="dlg-route"]').forEach(function (btn) {
    btn.addEventListener("click", function () {
      editingRouteId = null;
      routeForm.reset();
      $("dlg-route-t").textContent = "Add route";
      $("routeForm").querySelector(".note").textContent = "Create a new route and save it to the database.";
      $("routeForm").querySelector('button[type="submit"]').textContent = "Save Route";
    });
  });

  document.querySelectorAll('[data-open-dialog="dlg-stop"]').forEach(function (btn) {
    btn.addEventListener("click", function () {
      editingStopId = null;
      stopForm.reset();
      $("stop_route").disabled = false;
      renderStopRouteOptions();
      if (selectedRouteId !== null) $("stop_route").value = String(selectedRouteId);
      $("dlg-stop-t").textContent = "Add stop";
    });
  });

  // Add/Edit Stop form submission
  var stopForm = $("stopForm");

  if (stopForm) {
    stopForm.addEventListener("submit", function (event) {
      event.preventDefault();
      if (!stopForm.reportValidity()) return;

      var saveButton = stopForm.querySelector('button[type="submit"]');
      var isEditing = editingStopId !== null;

      var payload = {
        stop_name: $("stop_name").value.trim(),
        latitude: Number($("latitude").value),
        longitude: Number($("longitude").value),
        stop_order: Number($("stop_order").value),
        pickup_time: $("stop_pickup_time").value || null,
        drop_time: $("stop_drop_time").value || null
      };

      if (!isEditing) payload.route_id = Number($("stop_route").value);

      if (!isEditing && !payload.route_id) {
        toast("Please select a route.", "error");
        return;
      }

      if (
        !Number.isFinite(payload.latitude) ||
        payload.latitude < -90 || payload.latitude > 90 ||
        !Number.isFinite(payload.longitude) ||
        payload.longitude < -180 || payload.longitude > 180 ||
        !Number.isInteger(payload.stop_order) || payload.stop_order < 1
      ) {
        toast("Please enter valid coordinates and stop order.", "error");
        return;
      }

      saveButton.disabled = true;
      saveButton.textContent = isEditing ? "Updating..." : "Saving...";

      var request = isEditing
        ? apiMutation("/users/stops/" + encodeURIComponent(editingStopId), "PUT", payload)
        : apiPost("/users/stops", payload);

      request.then(function (result) {
        var routeId = isEditing ? selectedRouteId : payload.route_id;
        toast(result.message || (isEditing ? "Stop updated successfully." : "Stop created successfully."), "success");
        editingStopId = null;
        stopForm.reset();
        $("stop_route").disabled = false;
        $("dlg-stop").close();
        selectedRouteId = routeId;
        return loadAll();
      }).catch(function (err) {
        toast("Could not save stop: " + err.message, "error");
      }).finally(function () {
        saveButton.disabled = false;
        saveButton.textContent = "Save Stop";
      });
    });
  }

  // Add/Edit Route form submission
  var routeForm = $("routeForm");

  if (routeForm) {
    routeForm.addEventListener("submit", function (event) {
      event.preventDefault();
      if (!routeForm.reportValidity()) return;

      var saveButton = routeForm.querySelector('button[type="submit"]');
      var isEditing = editingRouteId !== null;

      var payload = {
        route_name: $("route_name").value.trim(),
        route_code: $("route_code").value.trim(),
        start_point: $("start_point").value.trim(),
        end_point: $("end_point").value.trim(),
        description: $("description").value.trim()
      };

      saveButton.disabled = true;
      saveButton.textContent = isEditing ? "Updating..." : "Saving...";

      var request = isEditing
        ? apiMutation("/users/routes/" + encodeURIComponent(editingRouteId), "PUT", payload)
        : apiPost("/users/routes", payload);

      request.then(function (result) {
        toast(result.message || (isEditing ? "Route updated successfully." : "Route created successfully."), "success");
        selectedRouteId = result.route_id;
        editingRouteId = null;
        routeForm.reset();
        $("dlg-route").close();
        return loadAll();
      }).catch(function (err) {
        toast("Could not save route: " + err.message, "error");
      }).finally(function () {
        saveButton.disabled = false;
        saveButton.textContent = editingRouteId !== null ? "Update Route" : "Save Route";
      });
    });
  }

// Add and Edit Bus form submission
if (busForm) {
  busForm.addEventListener("submit", function (event) {
    event.preventDefault();

    if (!busForm.reportValidity()) {
      return;
    }

    var saveButton = busForm.querySelector('button[type="submit"]');

    var payload = {
      bus_number: $("bus_number").value.trim(),
      bus_type: $("bus_type").value,
      capacity: Number($("capacity").value),
      registration_number: $("registration_number").value.trim(),
      route_id: $("bus_route").value
        ? Number($("bus_route").value)
        : null
    };

    var wasEditing = editingBusId !== null;
    var busId = editingBusId;

    saveButton.disabled = true;
    saveButton.textContent = "Saving...";

    var request = wasEditing
      ? apiMutation(
          "/users/buses/" + busId,
          "PUT",
          payload,
          false
        )
      : apiPost("/users/buses", payload);

    request
      .then(function (result) {
        if (wasEditing) {
          return busId;
        }

        if (result && (result.bus_id || result.id)) {
          return result.bus_id || result.id;
        }

        return load("buses").then(function () {
          var found = (data.buses || []).find(function (b) {
            return b.bus_number === payload.bus_number;
          });

          if (!found) {
            throw new ApiError(200, "Bus saved but ID not found.");
          }

          return found.bus_id;
        });
      })
      .then(function (id) {
        return uploadBusPhotos(id);
      })
      .then(function () {
        toast(
          wasEditing
            ? "Bus updated successfully."
            : "Bus created successfully.",
          "success"
        );

        busForm.reset();
        editingBusId = null;

        $("dlg-bus").close();
        $("dlg-bus-t").textContent = "Add Bus";

        return loadAll();
      })
      .catch(function (err) {
        toast("Could not save bus: " + err.message, "error");
      })
      .finally(function () {
        saveButton.disabled = false;
        saveButton.textContent = "Save Bus";
      });
  });
}

// Create Trip form submission
var tripForm = $("tripForm");

if (tripForm) {
  tripForm.addEventListener("submit", function (event) {
    event.preventDefault();

    if (!tripForm.reportValidity()) return;

    var payload = {
      bus_id: Number($("trip_bus").value),
      route_id: Number($("trip_route").value),
      driver_id: Number($("trip_driver").value),
      trip_date: $("trip_date_in").value
    };

    if (
      !payload.bus_id ||
      !payload.route_id ||
      !payload.driver_id ||
      !payload.trip_date
    ) {
      toast("Please fill all trip details.", "error");
      return;
    }

    var saveButton = tripForm.querySelector('button[type="submit"]');
    saveButton.disabled = true;
    saveButton.textContent = "Saving...";

    apiPost("/trips/", payload)
     .then(function (result) {
      toast(result.message || "Trip scheduled successfully.", "success");
     tripForm.reset();

     updateTripDriver();

     var dialog = $("dlg-trip");
     if (dialog && dialog.open) dialog.close();

     return load("trips");
    })
    
      .catch(function (err) {
        toast("Could not create trip: " + err.message, "error");
      })
      .finally(function () {
        saveButton.disabled = false;
        saveButton.textContent = "Save Trip";
      });
  });
}



/* ------------------------------------------------------ Live Fleet Map */
var fleetMap = null;
var fleetBusLayer = null;
var fleetRouteLayer = null;
var fleetRefreshTimer = null;

var fleetBusData = [];
var fleetSelectedBusId = "";

function fleetFreshness(bus) {
    if (!bus.recorded_at) return "OFFLINE";
    var age = Date.now() - new Date(bus.recorded_at).getTime();
    if (!Number.isFinite(age) || age < 0) return "OFFLINE";
    if (age <= 60000) return "LIVE";
    if (age <= 300000) return "STALE";
    return "OFFLINE";
}

function updateFleetBusDetails() {
    var select = $("fleet-bus-select");
    if (!select) return;

    var bus = fleetBusData.find(function (item) {
        return String(item.bus_id) === String(fleetSelectedBusId);
    });

    var fields = {
        "fleet-detail-number": bus ? bus.bus_number : "—",
        "fleet-detail-route": bus ? ((bus.route_code || "—") + " - " + (bus.route_name || "—")) : "—",
        "fleet-detail-driver": bus ? (bus.driver_name || "Not assigned") : "—",
        "fleet-detail-trip": bus ? (bus.trip_id || "No active trip") : "—",
        "fleet-detail-source": bus ? (bus.source || "—") : "—",
        "fleet-detail-lat": bus && bus.latitude != null ? bus.latitude : "—",
        "fleet-detail-lng": bus && bus.longitude != null ? bus.longitude : "—",
        "fleet-detail-speed": bus && bus.speed != null ? bus.speed + " km/h" : "—",
        "fleet-detail-time": bus && bus.recorded_at ? new Date(bus.recorded_at).toLocaleString() : "No GPS record",
        "fleet-detail-freshness": bus ? fleetFreshness(bus) : "—"
    };

    Object.keys(fields).forEach(function (id) {
        var element = $(id);
        if (element) element.textContent = String(fields[id]);
    });
}

function updateFleetBusOptions(buses) {
    var select = $("fleet-bus-select");
    if (!select) return;

    var previous = fleetSelectedBusId;
    select.replaceChildren();

    var placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.textContent = "Select a bus";
    select.appendChild(placeholder);

    buses.forEach(function (bus) {
        var option = document.createElement("option");
        option.value = String(bus.bus_id);
        option.textContent = bus.bus_number + (bus.route_code ? " - " + bus.route_code : "");
        select.appendChild(option);
    });

    var exists = buses.some(function (bus) {
        return String(bus.bus_id) === String(previous);
    });

    fleetSelectedBusId = exists ? previous : "";
    select.value = fleetSelectedBusId;
    updateFleetBusDetails();
}


function initFleetMap() {
    if (fleetMap) return true;
    if (!window.L || !$("fleet-map")) return false;

    fleetMap = L.map("fleet-map").setView([13.219992, 77.753943], 10);

    var busSelect = $("fleet-bus-select");
    if (busSelect && !busSelect.dataset.bound) {
        busSelect.addEventListener("change", function () {
            fleetSelectedBusId = busSelect.value;
            updateFleetBusDetails();
        });
        busSelect.dataset.bound = "true";
    }

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "&copy; OpenStreetMap contributors"
    }).addTo(fleetMap);

    fleetBusLayer = L.layerGroup().addTo(fleetMap);
    fleetRouteLayer = L.layerGroup().addTo(fleetMap);

    return true;
}

function refreshFleetMap() {
    if (!initFleetMap()) return;

    api("/trips/live-fleet").then(function (buses) {
        if (!Array.isArray(buses)) throw new Error("Invalid fleet response.");

        fleetBusData = buses;
        updateFleetBusOptions(buses);

        fleetBusLayer.clearLayers();
        fleetRouteLayer.clearLayers();

        var bounds = [];
        var routeIds = {};

        buses.forEach(function (bus) {
            if (bus.route_id) routeIds[bus.route_id] = true;

            if (bus.latitude === null || bus.longitude === null) return;

            var lat = Number(bus.latitude);
            var lng = Number(bus.longitude);

            if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

            var age = bus.recorded_at
                ? Date.now() - new Date(bus.recorded_at).getTime()
                : Infinity;

            var freshness = age <= 60000 ? "LIVE"
                : age <= 300000 ? "STALE" : "OFFLINE";

            var color = freshness === "LIVE" ? "#16a34a"
                : freshness === "STALE" ? "#f59e0b" : "#dc2626";

            var marker = L.circleMarker([lat, lng], {
                radius: 9,
                color: "#ffffff",
                weight: 2,
                fillColor: color,
                fillOpacity: 1
            }).addTo(fleetBusLayer);

            var popup = document.createElement("div");
            [
                "Bus: " + bus.bus_number,
                "Route: " + (bus.route_code || "Not assigned"),
                "Driver: " + (bus.driver_name || "Not assigned"),
                "Trip: " + (bus.trip_id || "No active trip"),
                "Status: " + freshness,
                "GPS source: " + (bus.source || "Unknown"),
                "Speed: " + (bus.speed == null ? "N/A" : bus.speed + " km/h"),
                "Last update: " + (bus.recorded_at || "Unavailable")
            ].forEach(function (line) {
                var row = document.createElement("div");
                row.textContent = line;
                popup.appendChild(row);
            });

            marker.bindPopup(popup);
            bounds.push([lat, lng]);
        });

        return Promise.all(Object.keys(routeIds).map(function (routeId) {
            return api("/users/routes/" + encodeURIComponent(routeId) + "/stops")
                .then(function (stops) {
                    if (!Array.isArray(stops)) return;

                    function validStopCoordinates(stop) {
                        var lat = Number(stop.latitude);
                        var lng = Number(stop.longitude);

                        return stop.latitude != null &&
                            stop.longitude != null &&
                            Number.isFinite(lat) &&
                            Number.isFinite(lng) &&
                            lat >= 6 && lat <= 38 &&
                            lng >= 68 && lng <= 98 &&
                            !(lat === 0 && lng === 0);
                    }

                    var points = stops
                        .filter(validStopCoordinates)
                        .sort(function (a, b) {
                            return a.stop_order - b.stop_order;
                        })
                        .map(function (stop) {
                            return [Number(stop.latitude), Number(stop.longitude)];
                        });

                    if (points.length >= 2) {
                        L.polyline(points, {
                            color: "#2563eb",
                            weight: 4,
                            opacity: 0.65
                        }).addTo(fleetRouteLayer);
                    }

                    stops.forEach(function (stop) {
                        if (!validStopCoordinates(stop)) return;

                        var stopMarker = L.circleMarker(
                            [Number(stop.latitude), Number(stop.longitude)],
                            {
                                radius: 4,
                                color: "#1d4ed8",
                                fillColor: "#ffffff",
                                fillOpacity: 1,
                                weight: 2
                            }
                        );

                        stopMarker.bindTooltip(
                            String(stop.stop_order) + ". " + String(stop.stop_name)
                        );
                        stopMarker.addTo(fleetRouteLayer);
                    });
                }).catch(function (error) {
                    console.warn("Could not load stops for route " + routeId, error);
                });
        })).then(function () {
            fleetMap.invalidateSize();

            var mapSection = $("view-live-map");

            if (mapSection && !mapSection.hidden) {
                if (bounds.length) {
                    fleetMap.fitBounds(bounds, {
                        padding: [40, 40],
                        maxZoom: 15
                    });
                } else {
                    fleetMap.setView([13.219992, 77.753943], 12);
                }
            }
        });
    }).catch(function (error) {
        console.error("Live Fleet Map error:", error);
        toast("Live Fleet Map could not refresh: " + error.message, "error");
    });
}

window.addEventListener("hashchange", function () {
    window.setTimeout(function () {
        if (fleetMap) fleetMap.invalidateSize();
        refreshFleetMap();
    }, 300);
});

refreshFleetMap();
fleetRefreshTimer = window.setInterval(refreshFleetMap, 15000);

 renderAll();
loadAll();
loadSchedules();
loadNotifications();
loadDriverRequests();
})();