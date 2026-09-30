/// The OneSignal app for every platform: Android through `onesignal_flutter`,
/// and the web app through OneSignal's Web SDK. Both are configured under
/// Settings > Push & In-App in the OneSignal dashboard.
const oneSignalAppId = 'e6cdb8fb-192b-4a0e-81e1-5762f7e0b630';

/// Whether the app should offer to turn notifications on, and how.
enum PushPermission {
  /// Nothing to offer: the native apps ask at launch and leave the rest to
  /// the system settings, and some browsers have no web push.
  unavailable,

  /// An iPhone or iPad browser tab, where web push only works once the site
  /// is added to the Home Screen (iOS 16.4 or later).
  needsHomeScreen,

  /// Not asked yet. Browsers only show the prompt in response to a tap.
  canRequest,

  granted,

  /// Blocked in the browser, which will not ask again; only its site
  /// settings can undo it.
  denied,
}
