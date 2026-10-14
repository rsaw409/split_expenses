// OneSignal's push worker, registered by its Web SDK at the /push/onesignal/
// scope (see lib/src/services/push_web.dart) rather than merged into sw.js:
// only one worker can control a scope, and push messages reach the
// registration that subscribed whichever worker controls the page. Kept
// apart, a blocked OneSignal CDN can't stop the offline worker installing.
// OneSignal requires this file on the site's own origin, not a CDN.
importScripts('https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js');
