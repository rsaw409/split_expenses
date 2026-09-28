import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'api_exception.dart';
import 'server.dart';

/// Tells the backend which groups this device belongs to, so it can send a
/// group's notifications straight to its devices.
///
/// Replaces the device's whole list on every call, so a retry is harmless, a
/// left group is simply absent, and any drift heals on the next call.
///
/// By plain group id, deliberately: ids are sequential, so anyone could
/// register for any group, but every other endpoint is keyed by the same
/// unauthenticated id, so invite ids would not have made group data private.
Future<void> registerDevice({
  required String subscriptionId,
  required List<int> groupIds,
}) async {
  final response = await http
      .post(
        Uri.parse('$server/registerDevice'),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'subscription_id': subscriptionId,
          'group_ids': groupIds,
        }),
      )
      .timeout(writeTimeout);

  if (response.statusCode != 200) {
    throw apiExceptionFrom(response, 'Failed to register for notifications.');
  }
}

/// This device's push identity and registration. An interface so tests can
/// stand in for OneSignal, which has no implementation off-device.
class PushRegistration {
  const PushRegistration();

  /// This install's OneSignal push subscription id, or null if OneSignal has
  /// none yet.
  ///
  /// Polled briefly: the SDK loads an existing id in the background after
  /// `initialize` without notifying observers, so right at launch it reads
  /// null even on a device registered long ago. A brand-new install gets
  /// its id later still, and [onSubscriptionChanged] covers that.
  Future<String?> subscriptionId() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final id = OneSignal.User.pushSubscription.id;
      if (id != null && id.isNotEmpty) return id;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// Calls [onChanged] whenever this install's subscription id changes (it
  /// is first issued, or reissued). Returns a function that stops watching.
  void Function() onSubscriptionChanged(void Function() onChanged) {
    void observer(OSPushSubscriptionChangedState state) {
      if (state.current.id != state.previous.id) onChanged();
    }

    OneSignal.User.pushSubscription.addObserver(observer);
    return () => OneSignal.User.pushSubscription.removeObserver(observer);
  }

  Future<void> register(String subscriptionId, List<int> groupIds) =>
      registerDevice(subscriptionId: subscriptionId, groupIds: groupIds);

  /// Removes the `group…` tags earlier builds used for targeting (by name,
  /// then by id). Nothing reads them any more, and they count toward the
  /// plan's small per-device tag limit.
  Future<void> removeGroupTags() async {
    final stale = (await OneSignal.User.getTags())
        .keys
        .where((key) => key.startsWith('group'))
        .toList();
    if (stale.isNotEmpty) await OneSignal.User.removeTags(stale);
  }
}
