import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/group.dart';
import '../utils/currency.dart';
import '../utils/group_icon.dart';
import './api_exception.dart';
import "./server.dart";

Future<Group> joinGroupFromInviteId(String inviteId) async {
  var url = '$server/joinGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'invite_id': inviteId,
    }),
  ).timeout(writeTimeout);

  if (response.statusCode == 200) {
    final group = Group.fromJson(jsonDecode(response.body));
    return group;
  } else {
    // The server reports a mistyped code as a raw crypto error under a 400, so
    // its message is never shown here — for the user there is only one
    // meaningful outcome: the code didn't work.
    throw apiExceptionFrom(
      response,
      'Invalid or expired invite code.',
      useServerMessage: false,
    );
  }
}

/// Creates a group with its first [members] in one atomic request.
///
/// Each member carries the avatar seed shown on the form; the server saves it
/// with them.
///
/// [idempotencyKey] makes a retry return the group already created rather
/// than a second one; the server dedupes on the key alone, so a changed
/// payload must come with a new key (see `IdempotencyKey`).
Future<Group> createGroup({
  required String name,
  required String currency,
  required List<({String name, String avatar})> members,
  required GroupIcon icon,
  required String idempotencyKey,
}) async {
  var url = '$server/createGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode({
      'name': name,
      ...currencyFor(currency).toApiFields(),
      'members': [
        for (final m in members) {'name': m.name, 'avatar': m.avatar},
      ],
      'icon': icon.emoji,
      'icon_color': icon.color,
      'idempotency_key': idempotencyKey,
    }),
  ).timeout(writeTimeout);

  if (response.statusCode == 200) {
    return Group.fromJson(jsonDecode(response.body));
  } else {
    throw apiExceptionFrom(response, 'Failed to create group.');
  }
}

/// The current details of [groupIds], so names and currencies changed on
/// another device show up here. Ids the server does not know are left out.
Future<List<Group>> fetchGroups(List<int> groupIds) async {
  final response = await http
      .post(
        Uri.parse('$server/getGroups'),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'group_ids': groupIds}),
      )
      .timeout(readTimeout);

  if (response.statusCode == 200) {
    return [
      for (final g in jsonDecode(response.body) as List)
        Group.fromMap(g as Map<String, dynamic>),
    ];
  }
  throw apiExceptionFrom(response, 'Failed to load groups.');
}

/// Renames [groupId], changes its currency and/or its icon; pass only what
/// changed. Needs no idempotency key: setting the same values twice is
/// harmless.
Future<Group> updateGroup(
  int groupId, {
  String? name,
  String? currency,
  GroupIcon? icon,
}) async {
  final response = await http
      .post(
        Uri.parse('$server/updateGroup'),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'group_id': groupId,
          if (name != null) 'name': name,
          // The backend needs both together, and trusts the decimals.
          if (currency != null) ...currencyFor(currency).toApiFields(),
          // Also only together: the backend refuses one without the other.
          if (icon != null) ...{'icon': icon.emoji, 'icon_color': icon.color},
        }),
      )
      .timeout(writeTimeout);

  if (response.statusCode == 200) {
    return Group.fromJson(jsonDecode(response.body));
  }
  throw apiExceptionFrom(response, 'Failed to update group.');
}
