/**
 * VectorOWL Service Worker — disabled fetch interception.
 * Previous versions caused stale-cache issues during rapid deployments.
 * Browsers' native HTTP caching (Cache-Control: immutable on hashed assets)
 * is sufficient and more reliable.
 */
self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

// Do not intercept any fetches.
