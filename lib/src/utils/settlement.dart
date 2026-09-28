import 'dart:math';

import '../models/user_balance.dart';

/// One payment that settle-up suggests: [fromName] pays [toName] [amount]
/// paise.
class SuggestedPayment {
  const SuggestedPayment({
    required this.from,
    required this.fromName,
    required this.to,
    required this.toName,
    required this.amount,
  });

  final int from;
  final String fromName;
  final int to;
  final String toName;

  /// In paise.
  final int amount;

  /// The wire shape `savePayments` expects, minus the idempotency key. No
  /// group name: the backend reads it from the database, so a renamed group
  /// is never notified under a stale name.
  Map<String, dynamic> toMap() => {
        'from': from,
        'fromName': fromName,
        'to': to,
        'toName': toName,
        'amount': amount,
      };
}

/// Pairs the largest debtors with the largest creditors until every balance
/// is zero. Balances are paise, so this is exact integer arithmetic.
///
/// Each step advances at least one side, so a debtor never pays the same
/// creditor twice — settle-up's idempotency keys (from/to/amount) rely on
/// that. Both sides advance when they zero out together, which is what keeps
/// a ₹0 payment out of the list.
List<SuggestedPayment> suggestPayments(List<UserBalance> balances) {
  final creditors = [
    for (final b in balances)
      if (b.balances > 0) (user: b, left: b.balances),
  ]..sort((a, b) => b.left.compareTo(a.left));
  final debtors = [
    for (final b in balances)
      if (b.balances < 0) (user: b, left: -b.balances),
  ]..sort((a, b) => b.left.compareTo(a.left));

  final payments = <SuggestedPayment>[];
  var i = 0;
  var j = 0;
  var owed = debtors.isEmpty ? 0 : debtors[0].left;
  var due = creditors.isEmpty ? 0 : creditors[0].left;

  while (i < debtors.length && j < creditors.length) {
    final amount = min(owed, due);
    payments.add(SuggestedPayment(
      from: debtors[i].user.userId,
      fromName: debtors[i].user.name,
      to: creditors[j].user.userId,
      toName: creditors[j].user.name,
      amount: amount,
    ));
    owed -= amount;
    due -= amount;

    if (owed == 0 && ++i < debtors.length) owed = debtors[i].left;
    if (due == 0 && ++j < creditors.length) due = creditors[j].left;
  }

  return payments;
}
