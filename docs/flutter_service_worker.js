'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"apex_sw.js": "4321c4b2365ed4545b2895ec6437f25f",
"app/apex_sw.js": "4321c4b2365ed4545b2895ec6437f25f",
"app/assets/AssetManifest.bin": "5feaa7496b5e8827161fbd54fb800ac5",
"app/assets/AssetManifest.bin.json": "112210445fd29ef10c7352cf039fdac1",
"app/assets/AssetManifest.json": "f7a4fe781707a366a402b4a3ff2ec75d",
"app/assets/assets/apex_logo.png": "e198169b7fe31cfd058459541ff2c1cb",
"app/assets/FontManifest.json": "ac3f70900a17dc2eb8830a3e27c653c3",
"app/assets/fonts/MaterialIcons-Regular.otf": "cbd131ff6ce4aab3a8458dafb706c63b",
"app/assets/NOTICES": "b2fe1fdc01017a25791e1e7014f2020d",
"app/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"app/assets/packages/syncfusion_flutter_datagrid/assets/font/FilterIcon.ttf": "b8e5e5bf2b490d3576a9562f24395532",
"app/assets/packages/syncfusion_flutter_datagrid/assets/font/UnsortIcon.ttf": "acdd567faa403388649e37ceb9adeb44",
"app/assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"app/canvaskit/canvaskit.js": "42e05a9f91b79e57785ec9bfc00b225c",
"app/canvaskit/canvaskit.js.symbols": "fb4a73c9dad886e036c3d222f44cfa4a",
"app/canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"app/canvaskit/chromium/canvaskit.js": "d6271c4ef1261e212b5a1bb898830cce",
"app/canvaskit/chromium/canvaskit.js.symbols": "4fce448c55821f9c1fcf493895f5169f",
"app/canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"app/canvaskit/skwasm.js": "84da1e9f1f623c2236616062f8113f39",
"app/canvaskit/skwasm.js.symbols": "61ca8ce5c6c98fbbcb1d24a05fac3890",
"app/canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"app/canvaskit/skwasm.worker.js": "b31cd002f2ed6e6d27aed1fa7658efae",
"app/clean.html": "9e8a76c83bdf062dd58dbb8006542cca",
"app/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"app/flutter.js": "dc84edd4c17e3c4c430feb0e0688cce9",
"app/flutter_bootstrap.js": "3ed7e8c1944c89981125d5b18e770caf",
"app/flutter_service_worker_passthrough.js": "72dbe1a08a70b69f30971b5650d6f3dc",
"app/icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"app/icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"app/icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"app/icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"app/index.html": "c61f0d2fd7b904451f0275d95b48f848",
"app/main.dart.js": "5bd05a6f4b4c1807fe4f3cfbc28d369a",
"app/manifest.json": "0d3dd8412093a96bf42554f4dca48475",
"app/version.json": "ebd9fd4cb6bd519d4ee5ded6d1896d31",
"assets/AssetManifest.bin": "5feaa7496b5e8827161fbd54fb800ac5",
"assets/AssetManifest.bin.json": "112210445fd29ef10c7352cf039fdac1",
"assets/AssetManifest.json": "f7a4fe781707a366a402b4a3ff2ec75d",
"assets/assets/apex_logo.png": "e198169b7fe31cfd058459541ff2c1cb",
"assets/FontManifest.json": "ac3f70900a17dc2eb8830a3e27c653c3",
"assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
"assets/NOTICES": "6ec65f6d25f673a2a3d1666acb9f320f",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"assets/packages/syncfusion_flutter_datagrid/assets/font/FilterIcon.ttf": "c17d858d09fb1c596ef0adbf08872086",
"assets/packages/syncfusion_flutter_datagrid/assets/font/UnsortIcon.ttf": "6d8ab59254a120b76bf53f167e809470",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"audit/api_audit.md": "9406fe57d6c23427db522e02bce83166",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"clean.html": "9e8a76c83bdf062dd58dbb8006542cca",
"contact.html": "0cc2ed353967416d6316c3f952b9bf2b",
"css/apex.css": "aedd0a991d67f437af8433382daf5d4c",
"customers.html": "6e4e911dda0ab99dcb5d0259fd0a65b4",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"flutter_bootstrap.js": "9e45fbc5e861d79beed0428e94ebf42d",
"flutter_service_worker_passthrough.js": "72dbe1a08a70b69f30971b5650d6f3dc",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "55f7216b99ef0d6689616388b69c6bb2",
"/": "55f7216b99ef0d6689616388b69c6bb2",
"main.dart.js": "e6ebb95d9e24098151b78052fe4f597d",
"manifest.json": "0d3dd8412093a96bf42554f4dca48475",
"pricing.html": "b9776dc73ea3cf5647648f661520f7cd",
"product.html": "b9ea5d4e563f97735d47e2f89ec8fd00",
"resources.html": "e0c983fba18c8c4f52ab0f28252bad14",
"solutions.html": "ea2cb10a1807192236cdf5047a3434c3",
"version.json": "ebd9fd4cb6bd519d4ee5ded6d1896d31"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
