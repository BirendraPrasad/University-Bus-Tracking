/* =========================================================
   CampusTransit Live — landing.js  (improved)
   ========================================================= */
document.addEventListener("DOMContentLoaded", () => {
  initMobileNav();
  initNavbarScroll();
  initScrollSpy();
  initScrollReveal();
  initFooterYear();
  initLoginButtons();
});

/* ---------- Navbar: scroll elevation ---------- */
function initNavbarScroll() {
  const navbar = document.getElementById("navbar");
  if (!navbar) return;
  const onScroll = () =>
    navbar.classList.toggle("is-scrolled", window.scrollY > 20);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
}

/* ---------- Mobile nav toggle ---------- */
function initMobileNav() {
  const toggle = document.getElementById("navToggle");
  const links  = document.getElementById("navLinks");
  if (!toggle || !links) return;

  toggle.addEventListener("click", () => {
    const isOpen = links.classList.toggle("is-open");
    toggle.classList.toggle("is-active", isOpen);
    toggle.setAttribute("aria-expanded", String(isOpen));
  });

  links.querySelectorAll(".navbar__link").forEach((link) => {
    link.addEventListener("click", () => {
      links.classList.remove("is-open");
      toggle.classList.remove("is-active");
      toggle.setAttribute("aria-expanded", "false");
    });
  });
}

/* ---------- Scroll spy ---------- */
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
  sections.forEach((s) => observer.observe(s));
}

/* ---------- Scroll reveal ---------- */
function initScrollReveal() {
  const els = document.querySelectorAll("[data-reveal]");
  if (!els.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12 }
  );
  els.forEach((el) => observer.observe(el));
}

/* ---------- Footer year ---------- */
function initFooterYear() {
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();
}

/* ---------- Login button routing ---------- */
function initLoginButtons() {
  const loginButtons = [
    document.getElementById("navLoginBtn"),
    document.getElementById("heroLoginBtn"),
    document.getElementById("ctaLoginBtn"),
  ].filter(Boolean);

  loginButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      /* Placeholder for future analytics / session check. */
    });
  });
}