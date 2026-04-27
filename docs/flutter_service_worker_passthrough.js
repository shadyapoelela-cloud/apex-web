// APEX — Network-only Service Worker (no caching).
//
// Purpose: replace Flutter's default cache-everything SW with one that:
//   1. Activates IMMEDIATELY (skipWaiting → no "close tab and reopen" UX trap).
//   2. Claims all open tabs on activate (existing tabs get the new SW).
//   3. Purges every existing cache the moment it activates (kills the
//      stale main.dart.js that prior SW had cached).
//   4. Passes every fetch straight through to the network — never caches.
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

self.addEventListener('fetch', (event) => {
  // Network-only. No cache lookups, no cache writes.
  // (Letting fetch fall through to the browser default would also
  // bypass the cache, but explicitly responding signals intent.)
  event.respondWith(fetch(event.request));
});
