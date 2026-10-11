import '../models/expense/expense.dart';
import '../models/user_balance.dart';
import 'expense_filters.dart';
import 'settlement.dart';

enum StatementLineKind { expense, paymentSent, paymentReceived }

/// One transaction a member took part in, and what it did to their balance.
class StatementLine {
  const StatementLine({
    required this.date,
    required this.kind,
    required this.title,
    required this.paidByName,
    required this.counterpartName,
    required this.total,
    required this.paid,
    required this.share,
    required this.balance,
  });

  /// Local time.
  final DateTime date;
  final StatementLineKind kind;

  /// The expense's title; for a payment, the title it was saved under.
  final String title;
  final String paidByName;

  /// For a payment, the other member: who it went to, or came from.
  final String? counterpartName;

  /// The whole transaction, in minor units.
  final int total;

  /// What the member put in: the expense or payment, if they paid it.
  final int paid;

  /// What the member took out: their share of an expense's split, or a
  /// payment they received.
  final int share;

  /// The member's balance after this transaction. Positive means they get
  /// money back.
  final int balance;

  int get change => paid - share;
}

/// Everything a member's statement shows, from their first transaction to
/// now. Amounts are minor units of the group's currency.
class Statement {
  const Statement({
    required this.userId,
    required this.memberName,
    required this.groupName,
    required this.generatedAt,
    required this.lines,
    required this.paidForExpenses,
    required this.shareOfExpenses,
    required this.paymentsSent,
    required this.paymentsReceived,
    required this.settleUp,
  });

  final int userId;
  final String memberName;
  final String groupName;
  final DateTime generatedAt;

  /// Oldest first, like a bank statement, so each line's balance follows
  /// from the one before.
  final List<StatementLine> lines;

  final int paidForExpenses;
  final int shareOfExpenses;
  final int paymentsSent;
  final int paymentsReceived;

  /// The payments settle-up would suggest that involve this member.
  final List<SuggestedPayment> settleUp;

  /// Positive means the member gets money back.
  int get balance =>
      paidForExpenses + paymentsSent - shareOfExpenses - paymentsReceived;
}

/// Builds [userId]'s statement from the group's full transaction list.
///
/// A transaction moves a member's balance by what they paid minus what they
/// took out (their split share, or a payment received). That is exactly how
/// the backend computes `balances` in `getOverviewDataInGroup` (transactions
/// they made, minus the transaction parts in their name), and the expense
/// list's `distributions` are those same parts, so the last line's balance
/// equals the server's once both lists are current.
///
/// Settle-up suggestions are worked out from balances computed over the same
/// list rather than from `UserBalanceController`, so the statement agrees with
/// itself even when the two lists were fetched at different times. When both
/// are current they are the same suggestions the Settle up screen shows.
Statement buildStatement({
  required List<Expense> expenses,
  required int userId,
  required String memberName,
  required String groupName,
  required DateTime now,
}) {
  final sorted = [...expenses]..sort((a, b) {
      final byDate = a.transactionDate.compareTo(b.transactionDate);
      return byDate != 0 ? byDate : a.transactionId.compareTo(b.transactionId);
    });

  final lines = <StatementLine>[];
  var paidForExpenses = 0;
  var shareOfExpenses = 0;
  var paymentsSent = 0;
  var paymentsReceived = 0;
  var balance = 0;

  for (final expense in sorted) {
    final sent = expense.userId == userId;
    var inSplit = false;
    var share = 0;
    for (final d in expense.distributions) {
      if (d.userId != userId) continue;
      inSplit = true;
      share += d.amount ?? 0;
    }
    if (!sent && !inSplit) continue;

    final paid = sent ? expense.transactionAmount : 0;
    final payment = isPayment(expense);
    if (payment) {
      paymentsSent += paid;
      paymentsReceived += share;
    } else {
      paidForExpenses += paid;
      shareOfExpenses += share;
    }
    balance += paid - share;

    lines.add(StatementLine(
      date: expense.transactionDate.toLocal(),
      kind: !payment
          ? StatementLineKind.expense
          : sent
              ? StatementLineKind.paymentSent
              : StatementLineKind.paymentReceived,
      title: expense.transactionTitle,
      paidByName: expense.userName,
      counterpartName: !payment
          ? null
          : sent
              ? expense.distributions.firstOrNull?.userName
              : expense.userName,
      total: expense.transactionAmount,
      paid: paid,
      share: share,
      balance: balance,
    ));
  }

  final settleUp = suggestPayments(_balancesFrom(sorted))
      .where((p) => p.from == userId || p.to == userId)
      .toList();

  return Statement(
    userId: userId,
    memberName: memberName,
    groupName: groupName,
    generatedAt: now,
    lines: lines,
    paidForExpenses: paidForExpenses,
    shareOfExpenses: shareOfExpenses,
    paymentsSent: paymentsSent,
    paymentsReceived: paymentsReceived,
    settleUp: settleUp,
  );
}

/// Every member's balance over [expenses], for [suggestPayments]. A member
/// with no transactions has a zero balance and nothing to settle, so the list
/// need not include them.
List<UserBalance> _balancesFrom(List<Expense> expenses) {
  final names = <int, String>{};
  final balances = <int, int>{};

  for (final expense in expenses) {
    names[expense.userId] = expense.userName;
    balances.update(expense.userId, (v) => v + expense.transactionAmount,
        ifAbsent: () => expense.transactionAmount);
    for (final d in expense.distributions) {
      final id = d.userId;
      final amount = d.amount;
      if (id == null || amount == null) continue;
      names.putIfAbsent(id, () => d.userName ?? '');
      balances.update(id, (v) => v - amount, ifAbsent: () => -amount);
    }
  }

  return [
    for (final MapEntry(key: id, value: amount) in balances.entries)
      UserBalance(
        name: names[id] ?? '',
        userId: id,
        balances: amount,
        numberOfTransactions: 0,
        numberOfBenefits: 0,
        numberOfPayments: 0,
      ),
  ];
}
