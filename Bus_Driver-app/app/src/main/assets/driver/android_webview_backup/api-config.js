/*
 * University Bus Tracking - Common API Configuration
 * Works with laptop localhost and mobile hotspot hostname.
 */
(function () {
    "use strict";

    const hostname = window.location.hostname;

    if (!hostname || window.location.protocol === "file:") {
        console.error("Open the application through the frontend web server.");
        return;
    }

    window.API_BASE_URL =
        `${window.location.protocol}//${hostname}:8000`;

    console.info("University Bus API:", window.API_BASE_URL);
})();
