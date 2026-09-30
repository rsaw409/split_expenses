import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'push_common.dart';

// OneSignal through `onesignal_flutter`, for the native apps. See push.dart.

/// OneSignal sets up its own Firebase app for FCM from the credentials in
/// its dashboard, so the app needs no Firebase SDK or config of its own.
void initializePush() {
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(oneSignalAppId);
  OneSignal.Notifications.requestPermission(true);
}

/// This install's OneSignal push subscription id, or null if OneSignal has
/// none yet.
///
/// Polled briefly: the SDK loads an existing id in the background after
/// `initialize` without notifying observers, so right at launch it reads
/// null even on a device registered long ago. A brand-new install gets its
/// id later still, and [onPushSubscriptionChanged] covers that.
Future<String?> pushSubscriptionId() async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) return id;
    await Future.delayed(const Duration(seconds: 1));
  }
  return null;
}

/// Calls [onChanged] whenever this install's subscription id changes (it is
/// first issued, or reissued). Returns a function that stops watching.
void Function() onPushSubscriptionChanged(void Function() onChanged) {
  void observer(OSPushSubscriptionChangedState state) {
    if (state.current.id != state.previous.id) onChanged();
  }

  OneSignal.User.pushSubscription.addObserver(observer);
  return () => OneSignal.User.pushSubscription.removeObserver(observer);
}

/// Removes the `group…` tags earlier builds used for targeting (by name,
/// then by id). Nothing reads them any more, and they count toward the
/// plan's small per-device tag limit.
Future<void> removeLegacyGroupTags() async {
  final stale = (await OneSignal.User.getTags())
      .keys
      .where((key) => key.startsWith('group'))
      .toList();
  if (stale.isNotEmpty) await OneSignal.User.removeTags(stale);
}

/// Calls [onNotification] when a notification arrives while the app is open,
/// or is tapped. Returns a function that stops watching.
void Function() onNotificationReceived(void Function() onNotification) {
  void onClick(OSNotificationClickEvent _) => onNotification();
  void onWillDisplay(OSNotificationWillDisplayEvent _) => onNotification();

  OneSignal.Notifications.addClickListener(onClick);
  OneSignal.Notifications.addForegroundWillDisplayListener(onWillDisplay);
  return () {
    OneSignal.Notifications.removeClickListener(onClick);
    OneSignal.Notifications.removeForegroundWillDisplayListener(onWillDisplay);
  };
}

/// The native apps ask at launch ([initializePush]), and after that only the
/// system settings can change it, so there is nothing to offer in the app.
Future<PushPermission> pushPermission() async => PushPermission.unavailable;

Future<void> requestPushPermission() async {}
