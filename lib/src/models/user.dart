import 'dart:convert';

import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String name;
  final int id;

  const User({required this.name, required this.id});

  factory User.fromMap(Map<String, dynamic> data) => User(
        name: data['name'] as String,
        id: data['id'] as int,
      );

  Map<String, dynamic> toMap() => {'name': name, 'user_id': id};

  factory User.fromJson(Map<String, dynamic> data) {
    return User.fromMap(data);
  }

  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props {
    return [name, id];
  }
}
