{{flutter_js}}
{{flutter_build_config}}

// Custom bootstrap. It differs from Flutter's default in four ways:
//
// - No `serviceWorkerSettings`. Flutter's own service worker is deprecated and
//   now only unregisters itself, and its loader re-registers it whenever *any*
//   worker is registered, which would replace sw.js and then delete it.
// - It registers sw.js instead, except in debug builds.
// - It removes index.html's splash once the app has painted.
// - It keeps the browser's install prompt for the app's own Install button.

// Chromium browsers fire this once the app is installable, often before
// Flutter has started, so it is kept for lib/src/services/web_app_web.dart.
// preventDefault() stops Chrome's own install banner on Android: the app asks
// in its own dialog instead.
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  window.splitInstallPrompt = event;
});

// Debug builds (`flutter run`, compiled by dartdevc) get no worker: it would
// cache every dev module and stay registered on localhost:<port> for whatever
// runs there next.
const isDebugBuild = _flutter.buildConfig.builds
    .some((build) => build.compileTarget === 'dartdevc');
const useServiceWorker = 'serviceWorker' in navigator && !isDebugBuild;

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const splash = document.getElementById('splash');
    if (splash) {
      splash.classList.add('hidden');
      setTimeout(() => splash.remove(), 250);
    }
    if (useServiceWorker) rememberLoadedResources();
  },
});

// sw.js caches the app for offline use. It precaches the app's own files,
// but which CanvasKit build and fonts the engine fetches from Google's CDN
// depends on the browser, and on the first visit they load before the worker
// controls the page, so the page hands over the list of what it loaded.
if (useServiceWorker) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch((error) => {
      console.warn('Service worker registration failed:', error);
    });
  });
  navigator.serviceWorker.addEventListener('controllerchange',
      rememberLoadedResources);
} else if (isDebugBuild && 'serviceWorker' in navigator) {
  removeServiceWorker();
}

function rememberLoadedResources() {
  navigator.serviceWorker.ready.then((registration) => {
    const urls =
        performance.getEntriesByType('resource').map((entry) => entry.name);
    registration.active?.postMessage({ type: 'cache-urls', urls });
  });
}

// A release build previously served on this origin (say, testing a build
// locally on the port `flutter run` now uses) leaves its worker behind, which
// would keep caching every request of the debug session.
async function removeServiceWorker() {
  const script = new URL('sw.js', document.baseURI).href;
  const isOurs = (worker) => worker?.scriptURL.split('?')[0] === script;
  for (const registration of await navigator.serviceWorker.getRegistrations()) {
    if (isOurs(registration.active ?? registration.waiting ??
        registration.installing)) {
      await registration.unregister();
    }
  }
  // Unregistering only takes effect once no page uses the worker, and until
  // then it keeps serving this page, re-creating the cache with every request.
  // So reload once to run the session without it; the flag rules out a loop.
  const reloadedKey = 'split-sw-removed';
  if (isOurs(navigator.serviceWorker.controller) &&
      !sessionStorage.getItem(reloadedKey)) {
    sessionStorage.setItem(reloadedKey, '1');
    location.reload();
    return;
  }
  for (const name of await caches.keys()) {
    if (name.startsWith('split-pwa-')) await caches.delete(name);
  }
}
