"use strict";

const CACHE_NAME = "university-bus-driver-v1";

self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();

      await Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      );

      await self.clients.claim();
    })()
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;

  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Never cache API requests or GPS-related data.
  if (url.origin !== self.location.origin) return;
  if (url.pathname.startsWith("/drivers/")) return;
  if (url.pathname.startsWith("/students/")) return;
  if (url.pathname.startsWith("/auth/")) return;
});
