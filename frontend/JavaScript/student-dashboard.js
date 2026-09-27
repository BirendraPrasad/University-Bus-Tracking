/* =========================================================
   STUDENT DASHBOARD
   SINGLE PAGE NAVIGATION
   ========================================================= */


/* =========================================================
   USER
   ========================================================= */

const storedUser =
    localStorage.getItem("user");

let user = {};

try {
    user = storedUser
        ? JSON.parse(storedUser)
        : {};
} catch (error) {
    user = {};
}

const userName =
    user.name || "Babu";

const userEmail =
    user.email || "babu1234@gmail.com";


/* =========================================================
   USER DISPLAY
   ========================================================= */

document
    .getElementById("headerUserName")
    .textContent = userName;

document
    .getElementById("welcomeName")
    .textContent = userName;

document
    .getElementById("profileName")
    .textContent = userName;

document
    .getElementById("profileFullName")
    .textContent = userName;

document
    .getElementById("profileEmail")
    .textContent = userEmail;


/* =========================================================
   PAGE TITLES
   ========================================================= */

const pageTitles = {

    dashboard: "Dashboard",

    routes: "My Routes",

    tracking: "Live Tracking",

    bus: "Bus Details",

    timetable: "Timetable",

    notifications: "Notifications",

    profile: "My Profile",

    settings: "Settings"

};


/* =========================================================
   ELEMENTS
   ========================================================= */

const menuItems =
    document.querySelectorAll(".menu-item");

const pageSections =
    document.querySelectorAll(".page-section");

const pageTitle =
    document.getElementById("pageTitle");


/* =========================================================
   SHOW PAGE
   ========================================================= */

function showPage(page) {

    /* Hide all sections */

    pageSections.forEach(section => {

        section.classList.remove("active");

    });


    /* Show selected section */

    const selectedSection =
        document.getElementById(
            `${page}Section`
        );

    if (selectedSection) {

        selectedSection.classList.add("active");

    }


    /* Active sidebar */

    menuItems.forEach(item => {

        item.classList.remove("active");

        if (
            item.dataset.page === page
        ) {

            item.classList.add("active");

        }

    });


    /* Header title */

    if (pageTitle) {

        pageTitle.textContent =
            pageTitles[page] ||
            "Dashboard";

    }


    /* Map refresh */

    setTimeout(() => {

        if (dashboardMap) {

            dashboardMap.invalidateSize();

        }

        if (trackingMap) {

            trackingMap.invalidateSize();

        }

    }, 100);


    /* Close mobile sidebar */

    const sidebar =
        document.getElementById("sidebar");

    if (sidebar) {

        sidebar.classList.remove("open");

    }


    /* Scroll top */

    window.scrollTo({
        top: 0,
        behavior: "smooth"
    });

}


/* =========================================================
   SIDEBAR CLICK
   ========================================================= */

menuItems.forEach(item => {

    item.addEventListener(
        "click",
        function(event) {

            event.preventDefault();

            const page =
                this.dataset.page;

            showPage(page);

        }
    );

});


/* =========================================================
   INTERNAL BUTTON NAVIGATION
   ========================================================= */

const openPageButtons =
    document.querySelectorAll(
        "[data-open-page]"
    );

openPageButtons.forEach(button => {

    button.addEventListener(
        "click",
        function() {

            const page =
                this.dataset.openPage;

            showPage(page);

        }
    );

});


/* =========================================================
   MOBILE MENU
   ========================================================= */

const mobileMenuBtn =
    document.getElementById(
        "mobileMenuBtn"
    );

const sidebar =
    document.getElementById("sidebar");

if (mobileMenuBtn) {

    mobileMenuBtn.addEventListener(
        "click",
        function() {

            sidebar.classList.toggle(
                "open"
            );

        }
    );

}


/* =========================================================
   DATE
   ========================================================= */

const todayDate =
    document.getElementById(
        "todayDate"
    );

if (todayDate) {

    const now = new Date();

    todayDate.textContent =
        now.toLocaleDateString(
            "en-IN",
            {
                day: "2-digit",
                month: "short",
                year: "numeric"
            }
        );

}


/* =========================================================
   DASHBOARD MAP
   ========================================================= */

let dashboardMap = null;

let trackingMap = null;


function createDashboardMap() {

    const mapElement =
        document.getElementById(
            "dashboardMap"
        );

    if (
        !mapElement ||
        dashboardMap
    ) {
        return;
    }


    dashboardMap =
        L.map(
            "dashboardMap"
        ).setView(
            [12.9716, 77.5946],
            13
        );


    L.tileLayer(
        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        {
            maxZoom: 19,

            attribution:
                "&copy; OpenStreetMap contributors"
        }
    ).addTo(
        dashboardMap
    );


    addBusMarker(
        dashboardMap,
        [12.9716, 77.5946]
    );


    addStops(
        dashboardMap
    );

}


/* =========================================================
   TRACKING MAP
   ========================================================= */

function createTrackingMap() {

    const mapElement =
        document.getElementById(
            "trackingMap"
        );

    if (
        !mapElement ||
        trackingMap
    ) {
        return;
    }


    trackingMap =
        L.map(
            "trackingMap"
        ).setView(
            [12.9716, 77.5946],
            14
        );


    L.tileLayer(
        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        {
            maxZoom: 19,

            attribution:
                "&copy; OpenStreetMap contributors"
        }
    ).addTo(
        trackingMap
    );


    addBusMarker(
        trackingMap,
        [12.9716, 77.5946]
    );


    addStops(
        trackingMap
    );

}


/* =========================================================
   BUS MARKER
   ========================================================= */

function addBusMarker(
    map,
    coordinates
) {

    const busIcon =
        L.divIcon({

            className:
                "custom-bus-marker",

            html: `
                <div style="
                    width:40px;
                    height:40px;
                    border-radius:50%;
                    background:#1769d1;
                    border:4px solid white;
                    box-shadow:0 4px 15px rgba(0,0,0,.25);
                    display:flex;
                    align-items:center;
                    justify-content:center;
                    font-size:18px;
                ">
                    🚌
                </div>
            `,

            iconSize: [40,40],

            iconAnchor: [20,20]

        });


    L.marker(
        coordinates,
        {
            icon: busIcon
        }
    )
    .addTo(map)
    .bindPopup(
        `
        <strong>BUS-001</strong><br>
        Route R002<br>
        <span style="color:#159a68">
        ● Live
        </span>
        `
    );

}


/* =========================================================
   STOPS
   ========================================================= */

function addStops(map) {

    const stops = [

        {
            name: "Main Gate",
            lat: 12.9716,
            lng: 77.5946
        },

        {
            name: "City Mall",
            lat: 12.9755,
            lng: 77.6010
        },

        {
            name: "University Gate",
            lat: 12.9800,
            lng: 77.6070
        }

    ];


    stops.forEach(stop => {

        L.circleMarker(
            [
                stop.lat,
                stop.lng
            ],
            {
                radius: 6,

                color: "#1769d1",

                fillColor: "#ffffff",

                fillOpacity: 1,

                weight: 3
            }
        )
        .addTo(map)
        .bindPopup(
            `<strong>${stop.name}</strong>`
        );

    });

}


/* =========================================================
   CREATE MAPS
   ========================================================= */

createDashboardMap();

createTrackingMap();


/* =========================================================
   FULL MAP
   ========================================================= */

const fullMapBtn =
    document.getElementById(
        "fullMapBtn"
    );

if (fullMapBtn) {

    fullMapBtn.addEventListener(
        "click",
        function() {

            showPage("tracking");

        }
    );

}


/* =========================================================
   TRACK BUS
   ========================================================= */

const trackBusBtn =
    document.getElementById(
        "trackBusBtn"
    );

if (trackBusBtn) {

    trackBusBtn.addEventListener(
        "click",
        function() {

            showPage("tracking");

        }
    );

}


/* =========================================================
   NOTIFICATION
   ========================================================= */

const notificationBtn =
    document.getElementById(
        "notificationBtn"
    );

if (notificationBtn) {

    notificationBtn.addEventListener(
        "click",
        function() {

            showPage(
                "notifications"
            );

        }
    );

}


/* =========================================================
   SEARCH
   ========================================================= */

const dashboardSearch =
    document.getElementById(
        "dashboardSearch"
    );

if (dashboardSearch) {

    dashboardSearch.addEventListener(
        "keydown",
        function(event) {

            if (
                event.key !== "Enter"
            ) {
                return;
            }


            const value =
                this.value
                    .trim()
                    .toLowerCase();


            if (!value) {
                return;
            }


            if (
                value.includes("route") ||
                value.includes("r002")
            ) {

                showPage("routes");

            }

            else if (
                value.includes("bus") ||
                value.includes("001")
            ) {

                showPage("bus");

            }

            else if (
                value.includes("stop") ||
                value.includes("gate")
            ) {

                showPage("tracking");

            }

            else {

                alert(
                    `No result found for "${this.value}"`
                );

            }

        }
    );

}


/* =========================================================
   "/" SEARCH SHORTCUT
   ========================================================= */

document.addEventListener(
    "keydown",
    function(event) {

        if (
            event.key === "/" &&
            document.activeElement.tagName !== "INPUT"
        ) {

            event.preventDefault();

            dashboardSearch.focus();

        }

    }
);


/* =========================================================
   LOGOUT
   ========================================================= */

const logoutBtn =
    document.getElementById(
        "logoutBtn"
    );

if (logoutBtn) {

    logoutBtn.addEventListener(
        "click",
        function() {

            const confirmLogout =
                confirm(
                    "Are you sure you want to logout?"
                );


            if (!confirmLogout) {
                return;
            }


            localStorage.removeItem(
                "token"
            );

            localStorage.removeItem(
                "user"
            );


            window.location.href =
                "login.html";

        }
    );

}