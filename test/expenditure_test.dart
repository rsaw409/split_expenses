import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/models/expense/distribution.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/utils/expenditure.dart';

Expense expense(
  int id, {
  required int paidBy,
  required int amount,
  required DateTime date,
  required Map<int, int> split,
  String? category,
}) =>
    Expense(
      groupId: 1,
      groupName: 'G',
      userId: paidBy,
      userName: 'U$paidBy',
      transactionId: id,
      transactionTitle: 't$id',
      transactionCategory: category,
      transactionAmount: amount,
      transactionDate: date,
      distributions: [
        for (final e in split.entries)
          Distribution(userId: e.key, userName: 'U${e.key}', amount: e.value),
      ],
    );

void main() {
  final expenses = [
    // A pays 300 for A, B, C equally.
    expense(1,
        paidBy: 1,
        amount: 30000,
        date: DateTime(2026, 8, 10, 12),
        split: {1: 10000, 2: 10000, 3: 10000}),
    // B pays 100.50 for A and B, split unevenly.
    expense(2,
        paidBy: 2,
        amount: 10050,
        date: DateTime(2026, 9, 1, 9),
        split: {1: 5025, 2: 5025}),
    // C settles up with A: a payment, not spending.
    expense(3,
        paidBy: 3,
        amount: 10000,
        date: DateTime(2026, 9, 2),
        split: {1: 10000},
        category: 'payment'),
  ];

  test('cost is each share of the split, and payments are not spending', () {
    final result = computeExpenditure(expenses);

    expect(result.total, 40050);
    expect(result.expenseCount, 2);
    expect(result.shareOf(1), 15025);
    expect(result.shareOf(2), 15025);
    // C's settle-up payment neither adds to C's cost nor to A's.
    expect(result.shareOf(3), 10000);
    expect(result.paidBy(1), 30000);
    expect(result.paidBy(3), 0);
    // Shares always add up to the total, whatever has been settled.
    expect(result.shares.values.reduce((a, b) => a + b), result.total);
  });

  test('a range includes both of its end days in full', () {
    final result = computeExpenditure(
      expenses,
      range: DateTimeRange(
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 10),
      ),
    );

    expect(result.total, 30000);
    expect(result.shareOf(2), 10000);
  });

  test('a range with no expenses totals zero', () {
    final result = computeExpenditure(
      expenses,
      range: DateTimeRange(
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 12, 31),
      ),
    );

    expect(result.total, 0);
    expect(result.shares, isEmpty);
  });
}
