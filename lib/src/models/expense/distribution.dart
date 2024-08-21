import 'dart:convert';

import 'package:equatable/equatable.dart';

class Distribution extends Equatable {
  final int? amount;
  final int? userId;
  final String? userName;

  const Distribution({this.amount, this.userId, this.userName});

  factory Distribution.fromMap(Map<String, dynamic> data) => Distribution(
        amount: data['amount'] as int?,
        userId: data['user_id'] as int?,
        userName: data['user_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'user_id': userId,
        'user_name': userName,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Distribution].
  factory Distribution.fromJson(Map<String, dynamic> data) {
    return Distribution.fromMap(data);
  }

  /// `dart:convert`
  ///
  /// Converts [Distribution] to a JSON string.
  String toJson() => json.encode(toMap());

  @override
  List<Object?> get props => [amount, userId, userName];
}
