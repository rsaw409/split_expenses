import 'package:equatable/equatable.dart';

/// A group member, only ever constructed in memory — from the balances the
/// group already caches, via `utils/members.dart`. It is never deserialised
/// from JSON, which is why it carries no `fromMap`/`fromJson`: the endpoint
/// that used to return users is gone.
class User extends Equatable {
  final String name;
  final int id;

  const User({required this.name, required this.id});

  /// Used by the split editor, which works in plain maps.
  Map<String, dynamic> toMap() => {'name': name, 'id': id};

  @override
  List<Object?> get props {
    return [name, id];
  }
}
