
"use strict";

/* =========================================
   FACULTY DASHBOARD
   University Bus Tracking System
========================================= */

const API_BASE_URL = window.API_BASE_URL;

const PAGE_TITLES = {
    overview: "Dashboard Overview",
    routes: "Bus Routes",
    stops: "Bus Stops",
    tracking: "Live Bus Tracking",
    trips: "Trip Information",
    notifications: "Notifications",
    profile: "My Profile",
    settings: "Settings"
};

let facultyProfile = null;
let facultyMap = null;
let mapInitialized = false;

/* =========================================
   AUTHENTICATION HELPERS
========================================= */

function getAuthValue(key) {
    return sessionStorage.getItem(key) ||
           localStorage.getItem(key);
}

function getAccessToken() {
    return getAuthValue("access_token") ||
           getAuthValue("token") ||
           getAuthValue("accessToken") ||
           getAuthValue("jwt");
}

function getCurrentRole() {
    return getAuthValue("user_role") ||
           getAuthValue("role") ||
           "";
}

function getUserId() {
    return getAuthValue("user_id");
}

function redirectToLogin() {
    window.location.replace("login.html");
}

function logout() {
    // Clear only authentication/session data.
    const authKeys = [
        "access_token",
        "token",
        "accessToken",
        "jwt",
        "token_type",
        "user_id",
        "user_name",
        "user_email",
        "user_role",
        "user",
        "currentUser",
        "student"
    ];

    authKeys.forEach(key => {
        localStorage.removeItem(key);
        sessionStorage.removeItem(key);
    });

    redirectToLogin();
}

function checkAuthentication() {
    const token = getAccessToken();
    const role = getCurrentRole();

    if (!token) {
        redirectToLogin();
        return false;
    }

    if (role && role.toUpperCase() !== "FACULTY") {
        alert("Access denied. Faculty account required.");
        redirectToLogin();
        return false;
    }

    return true;
}

/* =========================================
   API REQUEST HELPER
========================================= */

async function apiRequest(endpoint, options = {}) {
    const token = getAccessToken();

    if (!token) {
        redirectToLogin();
        throw new Error("Authentication token missing.");
    }

    const headers = {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
        ...(options.headers || {})
    };

    const response = await fetch(
        `${API_BASE_URL}${endpoint}`,
        {
            ...options,
            headers
        }
    );

    if (response.status === 401) {
        logout();
        throw new Error("Session expired. Please login again.");
    }

    if (response.status === 403) {
        throw new Error("You do not have permission to access this resource.");
    }

    if (!response.ok) {
        throw new Error(`API request failed: HTTP ${response.status}`);
    }

    return response.json();
}

/* =========================================
   PROFILE API
   GET /faculty/me
========================================= */

async function loadFacultyProfile() {
    try {
        showToast("Loading faculty profile...");

        const profile = await apiRequest("/faculty/me");

        if (!profile || profile.role !== "FACULTY") {
            throw new Error("Invalid faculty profile.");
        }

        facultyProfile = profile;

        renderFacultyProfile(profile);

        document.getElementById("overviewStatus").textContent =
            profile.is_active ? "Active" : "Inactive";

        document.getElementById("overviewStatus")
            .classList.toggle("inactive", !profile.is_active);

        showToast("Faculty profile loaded successfully.");

    } catch (error) {
        console.error("Faculty profile error:", error.message);

        setText("profileName", "Profile unavailable");
        setText("welcomeName", "Faculty");
        setText("sidebarName", "Faculty");
        setText("headerName", "Faculty");
        setText("overviewStatus", "Unavailable");

        showToast(error.message || "Unable to load faculty profile.");
    }
}

/* =========================================
   RENDER PROFILE
========================================= */

function setText(id, value) {
    const element = document.getElementById(id);

    if (element) {
        element.textContent =
            value !== null && value !== undefined && value !== ""
                ? String(value)
                : "—";
    }
}

function renderFacultyProfile(profile) {
    const name = profile.name || "Faculty";
    const email = profile.email || "—";
    const employeeId = profile.employee_id || "—";
    const department = profile.department || "—";
    const facultyId = profile.faculty_id ?? "—";
    const status = profile.is_active ? "Active" : "Inactive";
    const initial = name.trim().charAt(0).toUpperCase() || "F";

    // Sidebar and header
    setText("sidebarName", name);
    setText("headerName", name);
    setText("welcomeName", name);

    setText("welcomeEmployeeId", employeeId);
    setText("welcomeDepartment", department);

    // Overview
    setText("overviewName", name);
    setText("overviewEmail", email);
    setText("overviewEmployee", employeeId);
    setText("overviewDepartment", department);
    setText("overviewFacultyId", facultyId);

    // Profile page
    setText("profileName", name);
    setText("profileEmail", email);
    setText("profileEmployeeId", employeeId);
    setText("profileFacultyId", facultyId);
    setText("profileDepartment", department);
    setText("profileDepartmentField", department);
    setText("profileStatus", status);

    // Initial avatars
    ["sidebarAvatar", "headerAvatar", "profileAvatar"].forEach(id => {
        setText(id, initial);
    });
}

/* =========================================
   SIDEBAR NAVIGATION
========================================= */

function openPage(pageName) {
    if (!PAGE_TITLES[pageName]) return;

    document.querySelectorAll(".page-section").forEach(section => {
        section.classList.remove("active");
    });

    document.querySelectorAll(".nav-link").forEach(link => {
        link.classList.remove("active");
    });

    const page = document.getElementById(`page-${pageName}`);

    if (page) {
        page.classList.add("active");
    }

    const activeLink = document.querySelector(
        `.nav-link[data-page="${pageName}"]`
    );

    if (activeLink) {
        activeLink.classList.add("active");
    }

    setText("pageHeading", PAGE_TITLES[pageName]);

    closeSidebar();

    if (pageName === "tracking") {
        initializeFacultyMap();
    }
}

/* =========================================
   RESPONSIVE SIDEBAR
========================================= */

function openSidebar() {
    document.getElementById("sidebar").classList.add("open");
    document.getElementById("sidebarOverlay").classList.add("visible");
}

function closeSidebar() {
    document.getElementById("sidebar").classList.remove("open");
    document.getElementById("sidebarOverlay").classList.remove("visible");
}

/* =========================================
   LEAFLET MAP
========================================= */

function initializeFacultyMap() {
    const mapElement = document.getElementById("facultyMap");

    if (!mapElement || typeof L === "undefined") {
        setText("gpsStatus", "Map library unavailable.");
        return;
    }

    if (!mapInitialized) {
        facultyMap = L.map("facultyMap").setView(
            [20.5937, 78.9629],
            5
        );

        L.tileLayer(
            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            {
                attribution: "&copy; OpenStreetMap contributors",
                maxZoom: 19
            }
        ).addTo(facultyMap);

        mapInitialized = true;
    }

    setText(
        "gpsStatus",
        "Map ready. Waiting for verified bus GPS data."
    );

    setTimeout(() => {
        if (facultyMap) {
            facultyMap.invalidateSize();
        }
    }, 150);
}

/*
  Do not add fake GPS markers.

  Actual GPS integration should be implemented after
  verifying a Faculty-authorized location API.
*/

/* =========================================
   SEARCH FILTERS
========================================= */

function setupTableSearch(inputId, tableId) {
    const input = document.getElementById(inputId);
    const table = document.getElementById(tableId);

    if (!input || !table) return;

    input.addEventListener("input", () => {
        const query = input.value.toLowerCase().trim();

        table.querySelectorAll("tr").forEach(row => {
            const text = row.textContent.toLowerCase();
            row.style.display = text.includes(query) ? "" : "none";
        });
    });
}

/* =========================================
   REFRESH BUTTONS
========================================= */

function refreshUnavailableModule(moduleName) {
    showToast(
        `${moduleName} API is not configured yet.`
    );
}

function setupRefreshButtons() {
    const refreshActions = {
        refreshRoutes: "Bus Routes",
        refreshStops: "Bus Stops",
        refreshTrips: "Trip Information",
        refreshNotifications: "Notifications"
    };

    Object.entries(refreshActions).forEach(([id, label]) => {
        const button = document.getElementById(id);

        if (button) {
            button.addEventListener("click", () => {
                refreshUnavailableModule(label);
            });
        }
    });

    document.getElementById("refreshMap")
        ?.addEventListener("click", () => {
            if (facultyMap) {
                facultyMap.invalidateSize();
            }

            showToast("Map refreshed. GPS API integration is pending.");
        });
}

/* =========================================
   NOTIFICATION DISPLAY
========================================= */

function updateNotificationCount(count) {
    const safeCount = Number.isFinite(Number(count))
        ? Math.max(0, Number(count))
        : 0;

    setText("notificationStat", safeCount);
    setText("notificationBadge", safeCount);

    document.getElementById("topNotificationDot")
        ?.classList.toggle("visible", safeCount > 0);
}

/* =========================================
   DATE AND TIME
========================================= */

function setCurrentDate() {
    const date = new Date();

    setText(
        "currentDate",
        date.toLocaleDateString("en-IN", {
            day: "numeric",
            month: "long",
            year: "numeric"
        })
    );

    setText("footerYear", date.getFullYear());
}

/* =========================================
   TOAST MESSAGE
========================================= */

let toastTimer;

function showToast(message) {
    const toast = document.getElementById("toast");

    if (!toast) return;

    toast.textContent = message;
    toast.classList.add("show");

    clearTimeout(toastTimer);

    toastTimer = setTimeout(() => {
        toast.classList.remove("show");
    }, 3000);
}

/* =========================================
   EVENT LISTENERS
========================================= */

function setupNavigation() {
    document.querySelectorAll(".nav-link").forEach(button => {
        button.addEventListener("click", () => {
            openPage(button.dataset.page);
        });
    });

    document.querySelectorAll("[data-open-page]").forEach(button => {
        button.addEventListener("click", () => {
            openPage(button.dataset.openPage);
        });
    });

    document.getElementById("menuToggle")
        ?.addEventListener("click", openSidebar);

    document.getElementById("sidebarClose")
        ?.addEventListener("click", closeSidebar);

    document.getElementById("sidebarOverlay")
        ?.addEventListener("click", closeSidebar);

    document.getElementById("logoutBtn")
        ?.addEventListener("click", logout);

    document.getElementById("settingsLogout")
        ?.addEventListener("click", logout);
}

/* =========================================
   INITIALIZATION
========================================= */

document.addEventListener("DOMContentLoaded", async () => {
    if (!checkAuthentication()) return;

    setCurrentDate();

    setupNavigation();
    setupRefreshButtons();

    setupTableSearch("routeSearch", "routesTable");
    setupTableSearch("stopSearch", "stopsTable");

    updateNotificationCount(0);

    await loadFacultyProfile();
});
