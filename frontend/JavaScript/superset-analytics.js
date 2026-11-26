import { embedDashboard } from "https://esm.sh/@superset-ui/embedded-sdk@0.2.0";

(function () {
  "use strict";

  const API_BASE = window.API_BASE_URL;
  const SUPERSET_DOMAIN = "http://localhost:8088";
  const EMBED_ID = "95ddec6d-afa5-4d19-ad3b-b3c81ba7d236";

  let embedded = false;
  let loading = false;

  function getAdminToken() {
    return localStorage.getItem("access_token") ||
           sessionStorage.getItem("access_token");
  }

  async function loadDashboard() {
    const mountPoint = document.getElementById("superset-dashboard");
    const status = document.getElementById("superset-status");

    if (!mountPoint || embedded || loading) return;

    const adminToken = getAdminToken();
    if (!adminToken) {
      status.textContent = "Admin session not found. Please login again.";
      return;
    }

    loading = true;
    status.textContent = "Connecting to Superset...";

    try {
      await embedDashboard({
        id: EMBED_ID,
        supersetDomain: SUPERSET_DOMAIN,
        mountPoint,
        fetchGuestToken: async () => {
          const response = await fetch(
            API_BASE + "/api/superset/guest-token",
            {
              method: "POST",
              headers: {
                "Authorization": "Bearer " + adminToken,
                "Accept": "application/json"
              }
            }
          );

          if (!response.ok) {
            throw new Error("Guest Token API failed: HTTP " + response.status);
          }

          const data = await response.json();
          if (!data.token) throw new Error("Guest Token missing");
          return data.token;
        },
        dashboardUiConfig: {
          hideTitle: false,
          filters: { expanded: false }
        }
      });

      embedded = true;
      status.textContent = "Superset Analytics connected.";
    } catch (error) {
      console.error("Superset embedding error:", error);
      status.textContent = "Unable to load Superset: " + error.message;
    } finally {
      loading = false;
    }
  }

  function checkView() {
    if (location.hash === "#superset") loadDashboard();
  }

  window.addEventListener("hashchange", checkView);
  document.addEventListener("DOMContentLoaded", checkView);
  checkView();
})();
