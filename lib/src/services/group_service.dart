import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/group.dart';
import "./server.dart";

Future<Group> joinGroupFromInviteId(inviteId) async {
  var url = '$server/joinGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'invite_id': '$inviteId',
    }),
  );

  if (response.statusCode == 200) {
    final group = Group.fromJson(jsonDecode(response.body));
    return group;
  } else {
    throw Exception('Failed to get group details from Server');
  }
}

Future<Group> createGroup(groupName) async {
  var url = '$server/createGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'name': '$groupName',
    }),
  );

  if (response.statusCode == 200) {
    return Group.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to create group details in Server');
  }
}
