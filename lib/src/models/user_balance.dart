import 'dart:convert';

import 'package:equatable/equatable.dart';

class UserBalance extends Equatable {
  final String name;
  final int userId;

  /// The member's avatar seed, or null for members added before avatars
  /// existed; see `utils/avatar.dart`.
  final String? avatar;
  /// In the group currency's minor units, like every amount the API sends. Positive means the member
  /// gets money back.
  final int balances;
  final int numberOfTransactions;
  final int numberOfBenefits;
  final int numberOfPayments;

  const UserBalance(
      {required this.name,
      required this.userId,
      this.avatar,
      required this.balances,
      required this.numberOfTransactions,
      required this.numberOfBenefits,
      required this.numberOfPayments});

  factory UserBalance.fromMap(Map<String, dynamic> data) => UserBalance(
        name: data['name'] as String,
        userId: data['user_id'] as int,
        avatar: data['avatar'] as String?,
        balances: data['balances'] as int,
        numberOfTransactions: data['number_of_transactions'] as int,
        numberOfBenefits: data['number_of_benefits'] as int,
        numberOfPayments: data['number_of_payments'] as int,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'user_id': userId,
        'avatar': avatar,
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
      avatar,
      balances,
      numberOfTransactions,
      numberOfBenefits,
      numberOfPayments
    ];
  }
}
