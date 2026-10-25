/* ==========================================================================
   Admin Dashboard — UI shell only (Stage 3)
   Handles: sidebar toggle, section switching, dialogs.
   It does NOT call the API, read tokens, or hold any data.
   Authentication, API calls and rendering are added in Stage 5
   (admin-dashboard.js).
   ========================================================================== */
(function () {
  "use strict";

  var DEFAULT_VIEW = "overview";
  var sidebar = document.getElementById("sidebar");
  var backdrop = document.getElementById("sidebarBackdrop");
  var menuToggle = document.getElementById("menuToggle");
  var pageTitle = document.getElementById("pageTitle");
  var pageDesc = document.getElementById("pageDesc");
  var links = document.querySelectorAll(".nav-link[data-view]");
  var views = document.querySelectorAll(".view");

  /* ---------- Sidebar (mobile) ---------- */
  function setSidebar(open) {
    sidebar.classList.toggle("is-open", open);
    backdrop.hidden = !open;
    menuToggle.setAttribute("aria-expanded", String(open));
    menuToggle.setAttribute("aria-label", open ? "Close navigation menu" : "Open navigation menu");
  }
  menuToggle.addEventListener("click", function () {
    setSidebar(!sidebar.classList.contains("is-open"));
  });
  backdrop.addEventListener("click", function () { setSidebar(false); });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && sidebar.classList.contains("is-open")) {
      setSidebar(false);
      menuToggle.focus();
    }
  });

  /* ---------- Section switching (hash based, no page reload) ---------- */
  function showView(id, moveFocus) {
    var target = document.getElementById("view-" + id);
    if (!target) { id = DEFAULT_VIEW; target = document.getElementById("view-" + id); }
    views.forEach(function (v) { v.hidden = v !== target; });
    links.forEach(function (a) {
      if (a.dataset.view === id) { a.setAttribute("aria-current", "page"); }
      else { a.removeAttribute("aria-current"); }
    });
    pageTitle.textContent = target.dataset.title;
    pageDesc.textContent = target.dataset.desc || "";
    document.title = target.dataset.title.replace(/&amp;/g, "&") + " | Admin Dashboard";
    setSidebar(false);
    if (moveFocus) { pageTitle.focus(); }
    window.scrollTo(0, 0);
  }
  window.addEventListener("hashchange", function () {
    showView(location.hash.slice(1) || DEFAULT_VIEW, true);
  });
  showView(location.hash.slice(1) || DEFAULT_VIEW, false);

  /* ---------- Dialogs ---------- */
  document.addEventListener("click", function (e) {
    var opener = e.target.closest("[data-open-dialog]");
    if (opener) {
      var dlg = document.getElementById(opener.dataset.openDialog);
      if (dlg && typeof dlg.showModal === "function") { dlg.showModal(); }
      return;
    }
    var closer = e.target.closest("[data-close-dialog]");
    if (closer) {
      var parent = closer.closest("dialog");
      if (parent) { parent.close(); }
    }
  });
  // Close when clicking the dimmed backdrop (outside the dialog box).
  document.querySelectorAll("dialog").forEach(function (d) {
    d.addEventListener("click", function (e) {
      if (e.target === d) { d.close(); }
    });
  });
})();