import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../utils/currency.dart';

class Group extends Equatable {
  final String name;
  final int id;
  final String inviteId;

  /// ISO code such as `INR`; see [currencyFor] for its symbol and decimals.
  final String currency;

  /// Digits after the decimal point, as the backend stored them (it uses
  /// them to format notification amounts). The app formats with
  /// [currencyFor]'s own decimals, which it sent when the group was created.
  final int currencyDecimals;

  const Group({
    required this.name,
    required this.id,
    required this.inviteId,
    this.currency = 'INR',
    int? currencyDecimals,
  }) : currencyDecimals = currencyDecimals ?? 2;

  /// Groups saved before currencies existed have no `currency`, and are INR;
  /// without `currency_decimals`, the currency's own decimals are assumed.
  factory Group.fromMap(Map<String, dynamic> data) {
    final currency = currencyFor(data['currency'] as String?);
    return Group(
      name: data['name'] as String,
      id: data['id'] as int,
      inviteId: data['inviteId'] as String,
      currency: currency.code,
      currencyDecimals:
          data['currency_decimals'] as int? ?? currency.decimals,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'id': id,
        'inviteId': inviteId,
        'currency': currency,
        'currency_decimals': currencyDecimals,
      };

  factory Group.fromJson(Map<String, dynamic> data) {
    return Group.fromMap(data);
  }

  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props {
    return [name, id, inviteId, currency, currencyDecimals];
  }
}
