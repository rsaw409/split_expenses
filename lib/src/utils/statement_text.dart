import 'package:intl/intl.dart';

import 'currency.dart';
import 'settlement.dart';
import 'statement.dart';

// The wording of a statement, shared by the text and PDF versions. It is in
// the third person throughout, so it reads the same whether it is sent to the
// member or posted in a group chat.

/// The text version shows at most this many transactions, the most recent,
/// so a long history stays a readable message (and under WhatsApp's length
/// limit). The PDF has them all.
const statementTextLineLimit = 50;

final statementDateFormat = DateFormat('d MMM yyyy');
final statementDateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

/// e.g. "owes ₹1,250.50", "gets back ₹200", "settled up".
String balanceWords(int balance, Currency currency) => balance == 0
    ? 'settled up'
    : balance > 0
        ? 'gets back ${currency.format(balance)}'
        : 'owes ${currency.format(-balance)}';

/// e.g. "Rohit owes ₹1,250.50", "Rohit is settled up".
String statementHeadline(Statement statement, Currency currency) => statement
            .balance ==
        0
    ? '${statement.memberName} is settled up'
    : '${statement.memberName} ${balanceWords(statement.balance, currency)}';

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

/// The statement as a message. Headings use WhatsApp's `*bold*`, which other
/// apps show as plain asterisks, still readable.
String statementText(Statement statement, Currency currency) {
  final name = statement.memberName;
  final lines = statement.lines;
  final out = StringBuffer()
    ..writeln('*Split statement: $name*')
    ..writeln(
        '${statement.groupName} · ${statementDateFormat.format(statement.generatedAt)}')
    ..writeln()
    ..writeln('*${statementHeadline(statement, currency)}*')
    ..writeln(
        'Paid for expenses: ${currency.format(statement.paidForExpenses)}')
    ..writeln(
        'Share of expenses: ${currency.format(statement.shareOfExpenses)}')
    ..writeln('Payments made: ${currency.format(statement.paymentsSent)}')
    ..writeln(
        'Payments received: ${currency.format(statement.paymentsReceived)}');

  if (statement.settleUp.isNotEmpty) {
    out
      ..writeln()
      ..writeln('*To settle up*');
    for (final payment in statement.settleUp) {
      out.writeln('• ${settleUpWords(payment, currency)}');
    }
  }

  out
    ..writeln()
    ..writeln('*Transactions (${lines.length})*');
  if (lines.isEmpty) {
    out
      ..writeln('None yet.')
      ..writeln();
  }

  final hidden = lines.length - statementTextLineLimit;
  if (hidden > 0) {
    out
      ..writeln(
          '$hidden earlier ${hidden == 1 ? 'transaction' : 'transactions'}'
          ' not shown. Share as PDF for the full list.')
      ..writeln();
  }

  for (final line in hidden > 0 ? lines.sublist(hidden) : lines) {
    out
      ..writeln(
          '${statementDateFormat.format(line.date)} · ${statementLineTitle(line)}')
      ..writeln(statementLineDetail(line, name, currency))
      ..writeln('Balance: ${balanceWords(line.balance, currency)}')
      ..writeln();
  }

  out.write('_Shared from Split_');
  return out.toString();
}
