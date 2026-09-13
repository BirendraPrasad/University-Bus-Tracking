/* =========================================================
   CampusTransit Live — main.js
   Landing page behaviour only. No API calls, no backend
   assumptions — safe to reuse this file's patterns on
   future pages.
   ========================================================= */

document.addEventListener("DOMContentLoaded", () => {
  initMobileNav();
  initScrollSpy();
  initFooterYear();
  initLoginButtons();
});

/* ---------- Mobile nav toggle ---------- */
function initMobileNav() {
  const toggle = document.getElementById("navToggle");
  const links = document.getElementById("navLinks");
  if (!toggle || !links) return;

  toggle.addEventListener("click", () => {
    const isOpen = links.classList.toggle("is-open");
    toggle.setAttribute("aria-expanded", String(isOpen));
  });

  // Close the mobile menu after a nav link is tapped
  links.querySelectorAll(".navbar__link").forEach((link) => {
    link.addEventListener("click", () => {
      links.classList.remove("is-open");
      toggle.setAttribute("aria-expanded", "false");
    });
  });
}

/* ---------- Highlight the nav link for the section in view ---------- */
function initScrollSpy() {
  const sections = ["home", "features", "how-it-works", "about"]
    .map((id) => document.getElementById(id))
    .filter(Boolean);
  const links = Array.from(document.querySelectorAll(".navbar__link"));
  if (!sections.length || !links.length) return;

  const setActive = (id) => {
    links.forEach((link) => {
      const target = link.getAttribute("href").replace("#", "");
      link.classList.toggle("is-active", target === id);
    });
  };

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) setActive(entry.target.id);
      });
    },
    { rootMargin: "-40% 0px -50% 0px", threshold: 0 }
  );

  sections.forEach((section) => observer.observe(section));
}

/* ---------- Footer year ---------- */
function initFooterYear() {
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();
}

/* ---------- Login button routing ----------
   All Login CTAs on this page point to login.html via
   their href attribute already, so no click handler is
   strictly required. This hook exists so a future page
   (or an auth check) can intercept the click without
   editing the HTML — e.g. redirecting to a role-specific
   dashboard once login.html exists and a session check
   is available. Currently it just lets the default link
   navigation happen. */
function initLoginButtons() {
  const loginButtons = [
    document.getElementById("navLoginBtn"),
    document.getElementById("heroLoginBtn"),
    document.getElementById("ctaLoginBtn"),
  ].filter(Boolean);

  loginButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      // Placeholder for future logic (e.g. analytics, session
      // check). Navigation itself is handled by href="login.html".
    });
  });
}