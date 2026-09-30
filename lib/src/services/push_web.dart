import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'push_common.dart';
import 'web_app.dart';

// OneSignal's Web SDK (v16) through JS interop, for web builds. See push.dart.
//
// The SDK registers its own service worker, web/push/onesignal/
// OneSignalSDKWorker.js, at the /push/onesignal/ scope, apart from the
// offline worker (web/sw.js) at the root: only one worker can control a
// scope, and push messages reach the registration that subscribed whichever
// worker controls the page. Keeping them apart is OneSignal's own advice,
// and it means a blocked OneSignal CDN can never break the offline worker.

/// The one site the OneSignal app's web configuration accepts, since a
/// OneSignal app takes a single origin. Anywhere else, `localhost` included,
/// init could only fail, so the SDK isn't even loaded.
const _siteOrigin = 'https://split.rsaw409.me';

const _sdkUrl = 'https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js';

/// How long a caller waits for the SDK before treating push as unavailable.
const _sdkTimeout = Duration(seconds: 15);

Future<_OneSignal?>? _sdk;

/// The SDK once [_sdk] has it, for [requestPushPermission] to use without
/// waiting.
_OneSignal? _initialized;

/// The SDK once initialised, or null where push can't work: another origin,
/// the script blocked (ad blockers commonly block OneSignal's CDN) or not
/// loadable offline, or init failing. It never completes if the script
/// hangs, so callers that wait on it use [_sdkWithin].
Future<_OneSignal?> get _ready => _sdk ??= _load();

Future<_OneSignal?> _sdkWithin() =>
    _ready.timeout(_sdkTimeout, onTimeout: () => null);

Future<_OneSignal?> _load() {
  // A browser tab only shows the install gate, so it has no use for push.
  if (Uri.base.origin != _siteOrigin || runningInBrowserTab) {
    return Future.value(null);
  }

  final ready = Completer<_OneSignal?>();
  void unavailable(Object reason) {
    debugPrint('OneSignal web push unavailable: $reason');
    if (!ready.isCompleted) ready.complete(null);
  }

  // The SDK runs whatever is queued here once it has loaded.
  _deferred ??= _DeferredQueue._(JSArray<JSFunction>());
  _deferred!.push(((_OneSignal sdk) {
    sdk
        .init(_InitOptions(
          appId: oneSignalAppId,
          serviceWorkerPath: 'push/onesignal/OneSignalSDKWorker.js',
          serviceWorkerParam: _ServiceWorkerParam(scope: '/push/onesignal/'),
        ))
        .toDart
        .then((_) {
      _initialized = sdk;
      if (!ready.isCompleted) ready.complete(sdk);
    }, onError: unavailable);
  }).toJS);

  final script = web.HTMLScriptElement()..src = _sdkUrl;
  script.addEventListener(
    'error',
    ((web.Event _) => unavailable('$_sdkUrl failed to load')).toJS,
  );
  web.document.head!.appendChild(script);
  return ready.future;
}

/// Starts loading the SDK. Unlike Android it doesn't ask for permission:
/// browsers only show the prompt in response to a tap, and Chrome quietly
/// hides prompts shown on page load. See [requestPushPermission].
void initializePush() => _ready;

/// This browser's OneSignal push subscription id, or null if it has none:
/// notifications aren't turned on, or push is unavailable here.
///
/// Polled briefly once permission is granted, since the SDK may still be
/// creating the subscription with OneSignal. [onPushSubscriptionChanged]
/// covers an id that arrives later still.
Future<String?> pushSubscriptionId() async {
  final sdk = await _sdkWithin();
  if (sdk == null || !sdk.notifications.permission) return null;
  for (var attempt = 0; attempt < 10; attempt++) {
    final id = sdk.user.pushSubscription.id;
    if (id != null && id.isNotEmpty) return id;
    await Future.delayed(const Duration(seconds: 1));
  }
  return null;
}

/// Calls [onChanged] whenever this browser's subscription id changes: when
/// notifications are first turned on, or the subscription is reissued.
/// Returns a function that stops watching.
void Function() onPushSubscriptionChanged(void Function() onChanged) =>
    _listen(
      (sdk) => sdk.user.pushSubscription,
      'change',
      ((_SubscriptionChange change) {
        if (change.current?.id != change.previous?.id) onChanged();
      }).toJS,
    );

/// Web subscriptions never had the tags the native apps are cleaned of.
Future<void> removeLegacyGroupTags() async {}

/// Calls [onNotification] when a notification arrives while the app is open,
/// or is clicked. Returns a function that stops watching.
void Function() onNotificationReceived(void Function() onNotification) {
  final listener = ((JSAny? _) => onNotification()).toJS;
  final stops = [
    for (final event in const ['click', 'foregroundWillDisplay'])
      _listen((sdk) => sdk.notifications, event, listener),
  ];
  return () {
    for (final stop in stops) {
      stop();
    }
  };
}

Future<PushPermission> pushPermission() async {
  if (Uri.base.origin != _siteOrigin) return PushPermission.unavailable;
  // Notifications are offered in the installed app only; a tab asks to
  // install instead. On iPhone a tab has no web push at all, and an app
  // added to the Home Screen does from iOS 16.4 (checked below).
  if (runningInBrowserTab) return PushPermission.unavailable;
  final sdk = await _sdkWithin();
  if (sdk == null || !sdk.notifications.isPushSupported()) {
    return PushPermission.unavailable;
  }
  return switch (web.Notification.permission) {
    'granted' => PushPermission.granted,
    'denied' => PushPermission.denied,
    _ => PushPermission.canRequest,
  };
}

/// Shows the browser's permission prompt. Must be called from a tap
/// handler: browsers ignore a prompt that no user action led to. Once the
/// SDK has loaded, the prompt is requested before anything is awaited, so
/// it stays inside the tap even in Safari, which is strictest about that.
/// Once granted, the SDK subscribes and [onPushSubscriptionChanged] fires.
Future<void> requestPushPermission() async {
  final sdk = _initialized ?? await _sdkWithin();
  if (sdk == null) return;
  try {
    await sdk.notifications.requestPermission().toDart;
  } catch (error) {
    debugPrint('Requesting notification permission failed: $error');
  }
}

/// Adds [listener] to an SDK emitter once the SDK is ready, unless the
/// returned function, which removes it, has been called first.
void Function() _listen(
  _Emitter Function(_OneSignal sdk) emitter,
  String event,
  JSFunction listener,
) {
  var stopped = false;
  _Emitter? target;
  _ready.then((sdk) {
    if (sdk == null || stopped) return;
    target = emitter(sdk)..addEventListener(event, listener);
  });
  return () {
    stopped = true;
    target?.removeEventListener(event, listener);
  };
}

// Bindings for the parts of the Web SDK used above:
// https://documentation.onesignal.com/docs/en/web-sdk-reference

/// `window.OneSignalDeferred`: an array until the SDK loads, which then
/// replaces it with an object whose `push` runs a callback straight away.
@JS('OneSignalDeferred')
external _DeferredQueue? get _deferred;

@JS('OneSignalDeferred')
external set _deferred(_DeferredQueue? value);

extension type _DeferredQueue._(JSObject _) implements JSObject {
  external void push(JSFunction callback);
}

extension type _OneSignal._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init(_InitOptions options);

  @JS('User')
  external _User get user;

  @JS('Notifications')
  external _Notifications get notifications;
}

extension type _InitOptions._(JSObject _) implements JSObject {
  external factory _InitOptions({
    String appId,
    String serviceWorkerPath,
    _ServiceWorkerParam serviceWorkerParam,
  });
}

extension type _ServiceWorkerParam._(JSObject _) implements JSObject {
  external factory _ServiceWorkerParam({String scope});
}

extension type _User._(JSObject _) implements JSObject {
  @JS('PushSubscription')
  external _PushSubscription get pushSubscription;
}

/// The SDK's namespaces take listeners the way a DOM EventTarget does.
extension type _Emitter._(JSObject _) implements JSObject {
  external void addEventListener(String event, JSFunction listener);
  external void removeEventListener(String event, JSFunction listener);
}

extension type _PushSubscription._(JSObject _) implements _Emitter {
  external String? get id;
}

extension type _Notifications._(JSObject _) implements _Emitter {
  /// Whether the browser has granted notification permission to the site.
  external bool get permission;

  external bool isPushSupported();

  external JSPromise<JSAny?> requestPermission();
}

extension type _SubscriptionChange._(JSObject _) implements JSObject {
  external _SubscriptionState? get previous;
  external _SubscriptionState? get current;
}

extension type _SubscriptionState._(JSObject _) implements JSObject {
  external String? get id;
}
