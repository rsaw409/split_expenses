import 'dart:convert';

import 'package:equatable/equatable.dart';

class Group extends Equatable {
  final String name;
  final int id;
  final String inviteId;

  const Group({required this.name, required this.id, required this.inviteId});

  factory Group.fromMap(Map<String, dynamic> data) => Group(
      name: data['name'] as String,
      id: data['id'] as int,
      inviteId: data['inviteId'] as String);

  Map<String, dynamic> toMap() =>
      {'name': name, 'id': id, 'inviteId': inviteId};

  factory Group.fromJson(Map<String, dynamic> data) {
    return Group.fromMap(data);
  }

  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props {
    return [name, id, inviteId];
  }
}
