import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'push.dart';
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

/// This device's push identity and registration: OneSignal's native SDK in
/// the apps, its Web SDK in the browser (see push.dart). An interface so
/// tests can stand in for OneSignal, which has no implementation in tests.
class PushRegistration {
  const PushRegistration();

  /// This install's OneSignal push subscription id, or null if it has none
  /// yet (on web, until the user turns notifications on).
  Future<String?> subscriptionId() => pushSubscriptionId();

  /// Calls [onChanged] whenever this install's subscription id changes (it
  /// is first issued, or reissued). Returns a function that stops watching.
  void Function() onSubscriptionChanged(void Function() onChanged) =>
      onPushSubscriptionChanged(onChanged);

  Future<void> register(String subscriptionId, List<int> groupIds) =>
      registerDevice(subscriptionId: subscriptionId, groupIds: groupIds);

  /// Removes the `group…` tags earlier builds used for targeting.
  Future<void> removeGroupTags() => removeLegacyGroupTags();
}
