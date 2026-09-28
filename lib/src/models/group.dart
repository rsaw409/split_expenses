import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../utils/currency.dart';

class Group extends Equatable {
  final String name;
  final int id;
  final String inviteId;

  /// ISO code such as `INR`; see [currencyFor] for its symbol and decimals.
  final String currency;

  const Group({
    required this.name,
    required this.id,
    required this.inviteId,
    this.currency = 'INR',
  });

  /// Groups saved before currencies existed have no `currency`, and are INR.
  factory Group.fromMap(Map<String, dynamic> data) => Group(
        name: data['name'] as String,
        id: data['id'] as int,
        inviteId: data['inviteId'] as String,
        currency: currencyFor(data['currency'] as String?).code,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'id': id, 'inviteId': inviteId, 'currency': currency};

  factory Group.fromJson(Map<String, dynamic> data) {
    return Group.fromMap(data);
  }

  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props {
    return [name, id, inviteId, currency];
  }
}
