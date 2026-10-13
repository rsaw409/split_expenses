import 'package:intl/intl.dart';

import 'currency.dart';
import 'settlement.dart';
import 'statement.dart';

// The wording of a statement. It is in the third person throughout, so it
// reads the same whether it is sent to the member or posted in a group chat.

final statementDateFormat = DateFormat('d MMM yyyy');
final statementDateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

/// e.g. "Rohit owes ₹1,250.50", "Rohit gets back ₹200",
/// "Rohit is settled up".
String statementHeadline(Statement statement, Currency currency) {
  final name = statement.memberName;
  final balance = statement.balance;
  if (balance == 0) return '$name is settled up';
  return balance > 0
      ? '$name gets back ${currency.format(balance)}'
      : '$name owes ${currency.format(-balance)}';
}

String statementLineTitle(StatementLine line) => switch (line.kind) {
      StatementLineKind.expense => line.title,
      StatementLineKind.paymentSent =>
        'Payment to ${line.counterpartName ?? 'Unknown'}',
      StatementLineKind.paymentReceived =>
        'Payment from ${line.counterpartName ?? 'Unknown'}',
    };

/// e.g. "Amit paid ₹3,000 · Rohit's share ₹750".
String statementLineDetail(
  StatementLine line,
  String memberName,
  Currency currency,
) =>
    switch (line.kind) {
      StatementLineKind.expense =>
        '${line.paidByName} paid ${currency.format(line.total)} · '
            "$memberName's share ${currency.format(line.share)}",
      StatementLineKind.paymentSent =>
        '$memberName paid ${currency.format(line.paid)}',
      StatementLineKind.paymentReceived =>
        '$memberName received ${currency.format(line.share)}',
    };

/// e.g. "Rohit pays Amit ₹750".
String settleUpWords(SuggestedPayment payment, Currency currency) =>
    '${payment.fromName} pays ${payment.toName} '
    '${currency.format(payment.amount)}';
