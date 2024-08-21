import 'dart:convert';

import 'package:equatable/equatable.dart';

class UserBalance extends Equatable {
  final String? name;
  final int? userId;
  final int? balances;
  final String? numberOfTransactions;
  final String? numberOfBenefits;
  final String? numberOfPayments;

  const UserBalance(
      {this.name,
      this.userId,
      this.balances,
      this.numberOfTransactions,
      this.numberOfBenefits,
      this.numberOfPayments});

  factory UserBalance.fromMap(Map<String, dynamic> data) => UserBalance(
      name: data['name'] as String?,
      userId: data['user_id'] as int?,
      balances: data['balances'] as int?,
      numberOfTransactions: data['number_of_transactions'] as String?,
      numberOfBenefits: data['number_of_benefits'] as String?,
      numberOfPayments: data['number_of_payments'] as String?);

  Map<String, dynamic> toMap() => {
        'name': name,
        'user_id': userId,
        'balances': balances,
        'number_of_transactions': numberOfTransactions,
        'number_of_benefits': numberOfBenefits,
        'number_of_payments': numberOfPayments
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [UserBalance].
  factory UserBalance.fromJson(Map<String, dynamic> data) {
    return UserBalance.fromMap(data);
  }

  /// `dart:convert`
  ///
  /// Converts [UserBalance] to a JSON string.
  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props {
    return [
      name,
      userId,
      balances,
      numberOfTransactions,
      numberOfBenefits,
      numberOfPayments
    ];
  }
}
