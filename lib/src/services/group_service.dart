import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/group.dart';
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
  );

  if (response.statusCode == 200) {
    final group = Group.fromJson(jsonDecode(response.body));
    return group;
  } else {
    throw apiExceptionFrom(response, 'Invalid or expired invite code.');
  }
}

Future<Group> createGroup(String groupName) async {
  var url = '$server/createGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'name': groupName,
    }),
  );

  if (response.statusCode == 200) {
    return Group.fromJson(jsonDecode(response.body));
  } else {
    throw apiExceptionFrom(response, 'Failed to create group.');
  }
}
