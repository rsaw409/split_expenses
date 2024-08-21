import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'distribution.dart';

class Expense extends Equatable {
  final int groupId;
  final String groupName;
  final int userId;
  final String userName;
  final int transactionId;
  final String transactionTitle;
  final num transactionAmount;
  final DateTime transactionDate;
  final List<Distribution> distributions;

  const Expense({
    required this.groupId,
    required this.groupName,
    required this.userId,
    required this.userName,
    required this.transactionId,
    required this.transactionTitle,
    required this.transactionAmount,
    required this.transactionDate,
    required this.distributions,
  });

  factory Expense.fromMap(Map<String, dynamic> data) => Expense(
        groupId: data['group_id'] as int,
        groupName: data['group_name'] as String,
        userId: data['user_id'] as int,
        userName: data['user_name'] as String,
        transactionId: data['transaction_id'] as int,
        transactionTitle: data['transaction_title'] as String,
        transactionAmount: data['transaction_amount'] as num,
        transactionDate: DateTime.parse(data['transaction_date'] as String),
        distributions: (data['distributions'] as List<dynamic>)
            .map((e) => Distribution.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'group_id': groupId,
        'group_name': groupName,
        'user_id': userId,
        'user_name': userName,
        'transaction_id': transactionId,
        'transaction_title': transactionTitle,
        'transaction_amount': transactionAmount,
        'transaction_date': transactionDate.toIso8601String(),
        'distributions': distributions.map((e) => e.toMap()).toList(),
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Expense].
  factory Expense.fromJson(Map<String, dynamic> data) {
    return Expense.fromMap(data);
  }

  /// `dart:convert`
  ///
  /// Converts [Expense] to a JSON string.
  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props {
    return [
      groupId,
      groupName,
      userId,
      userName,
      transactionId,
      transactionTitle,
      transactionAmount,
      transactionDate,
      distributions,
    ];
  }
}
