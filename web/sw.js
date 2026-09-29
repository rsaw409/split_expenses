'use strict';

// Offline support for the Split PWA: the app shell only. Expense data is
// cached by the app itself (SharedPreferences, i.e. localStorage on web), and
// every backend call is a POST or HEAD, which this worker never touches.
//
// - The app's own files are network-first, so an online launch always runs
//   the latest deploy, and the cache is only used when the network fails or
//   the host errors.
// - Flutter's engine (CanvasKit) and fonts load from Google's CDN at
//   versioned URLs that never change, so they are cache-first.

// Stamped with the release version by CI (see release.yml), so every deploy
// changes this file. The browser then installs the new worker, whose install
// step refreshes the precached files: without it, a file Flutter only loads
// on first use would stay at whatever version was first cached.
const BUILD = 'dev';

const CACHE = 'split-pwa-v1';

// Immutable CDN files the engine loads: CanvasKit, and the Roboto / emoji
// fallback fonts.
const CDN_PREFIXES = [
  'https://www.gstatic.com/flutter-canvaskit/',
  'https://fonts.gstatic.com/',
];

const scope = new URL(self.registration.scope);

// Precached on install, relative to the scope. Beyond the startup files, it
// lists what Flutter only fetches on first use, which would otherwise be
// missing offline if the user had never triggered it online: the ink ripple
// and overscroll shaders, the asset manifest, and the drawer's logo image.
// A path missing from a build is skipped, not fatal. Keep in step with
// pubspec.yaml's assets.
const PRECACHE = [
  '',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'version.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'icons/apple-touch-icon.png',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/shaders/ink_sparkle.frag',
  'assets/shaders/stretch_effect.frag',
  'assets/assets/images/split.webp',
];

function isAppFile(url) {
  return url.origin === scope.origin && url.pathname.startsWith(scope.pathname);
}

// The app's own page: the scope root or its index.html, whatever the query.
function isShell(url) {
  return url.origin === scope.origin &&
      (url.pathname === scope.pathname ||
       url.pathname === `${scope.pathname}index.html`);
}

function isCdnFile(url) {
  return CDN_PREFIXES.some((prefix) => url.href.startsWith(prefix));
}

// Queries on app files are only cache-busters (package_info_plus adds a random
// one to version.json), so they must not cause a miss.
function fromCache(key) {
  return caches.match(key, { ignoreSearch: true });
}

async function store(key, response) {
  if (!response.ok) return;
  const cache = await caches.open(CACHE);
  await cache.put(key, response);

  // A Flutter upgrade moves CanvasKit to a new revision directory; drop the
  // old one rather than keeping several copies of a multi-megabyte engine.
  const url = new URL(typeof key === 'string' ? key : key.url);
  const [revision] = url.href.startsWith(CDN_PREFIXES[0])
    ? url.href.slice(CDN_PREFIXES[0].length).split('/')
    : [];
  if (!revision) return;
  for (const old of await cache.keys()) {
    if (old.url.startsWith(CDN_PREFIXES[0]) &&
        !old.url.startsWith(`${CDN_PREFIXES[0]}${revision}/`)) {
      await cache.delete(old);
    }
  }
}

async function networkFirst(event) {
  const request = event.request;
  const navigate = request.mode === 'navigate';

  // Every navigation shares the shell's cache entry, since the app routes
  // whatever path it was opened at. But only the shell itself is ever stored
  // there: any other page in scope (a deep link, or someone opening
  // manifest.json in a tab) is served but not kept, or it would replace the
  // app offline.
  const key = navigate ? scope.href : request;
  const storable = !navigate || isShell(new URL(request.url));

  let response;
  try {
    response = await fetch(request);
  } catch (error) {
    const cached = await fromCache(key);
    if (cached) return cached;
    throw error;
  }

  // A 5xx is the host failing, not an answer about this file, so a cached
  // copy beats an error page. A 4xx is passed through: it is a real answer.
  if (response.status >= 500) {
    return (await fromCache(key)) ?? response;
  }
  if (storable) event.waitUntil(store(key, response.clone()));
  return response;
}

async function cacheFirst(event) {
  const cached = await caches.match(event.request);
  if (cached) return cached;
  const response = await fetch(event.request);
  event.waitUntil(store(event.request, response.clone()));
  return response;
}

// Also runs for every new deploy (see BUILD), refreshing each precached file.
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(cacheAll(PRECACHE.map((path) => new URL(path, scope).href),
      { refresh: true }));
});

// Fetches and stores each URL, one at a time so a failure skips only that
// one. Without `refresh`, URLs already cached are left alone. `no-cache`
// revalidates with the server, so an unchanged file costs only a 304.
async function cacheAll(urls, { refresh = false } = {}) {
  const cache = await caches.open(CACHE);
  for (const href of urls) {
    if (!refresh && await cache.match(href)) continue;
    try {
      await store(href, await fetch(href, { cache: 'no-cache' }));
    } catch (_) {
      // Offline or refused: it will be cached the next time it loads.
    }
  }
}

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith('split-pwa-') && name !== CACHE) {
        await caches.delete(name);
      }
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (isAppFile(url)) {
    event.respondWith(networkFirst(event));
  } else if (isCdnFile(url)) {
    event.respondWith(cacheFirst(event));
  }
});

// The page reports what it loaded before this worker controlled it (see
// flutter_bootstrap.js); fetch and keep whichever of those aren't cached yet.
self.addEventListener('message', (event) => {
  if (event.data?.type !== 'cache-urls') return;
  const urls = [];
  for (const href of event.data.urls) {
    try {
      const url = new URL(href);
      url.hash = '';
      if (isAppFile(url) || isCdnFile(url)) urls.push(url.href);
    } catch (_) {
      // Not a URL; ignore it.
    }
  }
  event.waitUntil(cacheAll(urls));
});
