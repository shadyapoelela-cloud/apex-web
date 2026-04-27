// APEX — No-op Service Worker (no caching, no fetch interception).
//
// Purpose: replace Flutter's default cache-everything SW with one that
// does NOTHING for network — the browser's native fetch handles every
// request directly. The SW exists only to:
//   1. Activate IMMEDIATELY (skipWaiting → no "close tab and reopen" UX trap).
//   2. Claim all open tabs on activate (replaces any older SW instantly).
//   3. Purge every existing cache the moment it activates (kills the
//      stale main.dart.js that prior SW had stashed).
//
// No fetch handler — the browser fetches everything from the network
// natively. This is critical for Firefox: an active fetch handler that
// just calls `event.respondWith(fetch(event.request))` was causing blank
// pages on /sales-invoices in Firefox (CORS/credentials handling
// differs subtly between fetch invocations). Removing the handler lets
// Firefox use its default — works in every browser.
//
// Result: live deploys on GitHub Pages reach the user on the next reload,
// no DevTools dance required. Trade-off: no offline support — acceptable
// for an active development app where instant updates matter more.

'use strict';

self.addEventListener('install', (event) => {
  // Don't wait for old tabs to close — activate the new SW instantly.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // 1. Wipe every existing cache (whatever Flutter's old SW stashed).
    if ('caches' in self) {
      try {
        const keys = await caches.keys();
        await Promise.all(keys.map((k) => caches.delete(k)));
      } catch (e) { /* ignore */ }
    }
    // 2. Take control of every open tab right now (no reload needed).
    await self.clients.claim();
  })());
});

// NO fetch handler — browser handles network natively. Critical for
// Firefox compatibility (event.respondWith(fetch(...)) was causing the
// page to blank on /sales-invoices).
