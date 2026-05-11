/*!
 * APEX minimal service worker
 * الغرض: تلبية شرط التثبيت في Edge/Chrome (PWA install criteria).
 * لا يُخزِّن شيئاً — كل الطلبات تذهب للشبكة مباشرة.
 * لا يتدخل في تحديثات الملفات أثناء التطوير.
 */
const APEX_SW_VERSION = 'apex-sw-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  // network-only: لا نخزّن شيئاً. هذا كافٍ لشرط التثبيت.
  event.respondWith(fetch(event.request).catch(() => Response.error()));
});
