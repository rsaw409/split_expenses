import 'package:flutter/material.dart';

import '../models/expense/expense.dart';
import 'expense_filters.dart';

/// What a group spent over some period, and each member's part of it.
class Expenditure {
  const Expenditure({
    required this.total,
    required this.shares,
    required this.paid,
    required this.expenseCount,
  });

  /// Sum of every expense in the period, in paise.
  final int total;

  /// Cost incurred per user id: their share of each expense's split, in
  /// paise. This is what a member actually consumed, so it is the same
  /// whether or not settle-up payments have been made yet.
  final Map<int, int> shares;

  /// Amount each user id paid up front for the group's expenses, in paise.
  final Map<int, int> paid;

  final int expenseCount;

  int shareOf(int userId) => shares[userId] ?? 0;
  int paidBy(int userId) => paid[userId] ?? 0;
}

/// Totals [expenses] whose date falls in [range] (inclusive of both days,
/// in local time), or all of them when [range] is null.
///
/// Payments are skipped: they move money between members to settle what is
/// owed, and counting them would double-count the spending they settle.
Expenditure computeExpenditure(
  List<Expense> expenses, {
  DateTimeRange? range,
}) {
  final start = range == null ? null : _startOfDay(range.start);
  final end = range == null
      ? null
      : _startOfDay(range.end).add(const Duration(days: 1));

  var total = 0;
  var count = 0;
  final shares = <int, int>{};
  final paid = <int, int>{};

  for (final expense in expenses) {
    if (isPayment(expense)) continue;

    final date = expense.transactionDate.toLocal();
    if (start != null && date.isBefore(start)) continue;
    if (end != null && !date.isBefore(end)) continue;

    total += expense.transactionAmount;
    count += 1;
    paid.update(expense.userId, (v) => v + expense.transactionAmount,
        ifAbsent: () => expense.transactionAmount);

    for (final d in expense.distributions) {
      final userId = d.userId;
      final amount = d.amount;
      if (userId == null || amount == null) continue;
      shares.update(userId, (v) => v + amount, ifAbsent: () => amount);
    }
  }

  return Expenditure(
    total: total,
    shares: shares,
    paid: paid,
    expenseCount: count,
  );
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
