import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/models/expense/distribution.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/services/statement_pdf.dart';
import 'package:split_expense/src/utils/currency.dart';
import 'package:split_expense/src/utils/statement.dart';
import 'package:split_expense/src/utils/statement_text.dart';

const names = {1: 'Asha', 2: 'Ben', 3: 'Chen'};

Expense expense(
  int id, {
  required int paidBy,
  required int amount,
  required DateTime date,
  required Map<int, int> split,
  String? title,
  String? category,
}) =>
    Expense(
      groupId: 1,
      groupName: 'Goa Trip',
      userId: paidBy,
      userName: names[paidBy] ?? 'U$paidBy',
      transactionId: id,
      transactionTitle: title ?? (category == 'payment' ? 'payment' : 't$id'),
      transactionCategory: category,
      transactionAmount: amount,
      transactionDate: date,
      distributions: [
        for (final e in split.entries)
          Distribution(
              userId: e.key,
              userName: names[e.key] ?? 'U${e.key}',
              amount: e.value),
      ],
    );

/// Out of order on purpose: the statement sorts by date, then by id.
final groupExpenses = [
  // Asha pays ₹40 for Ben alone: she is not in the split.
  expense(5,
      paidBy: 1,
      amount: 4000,
      date: DateTime(2026, 9, 5),
      split: {2: 4000},
      title: 'Taxi'),
  // Asha pays ₹300 for all three, equally.
  expense(1,
      paidBy: 1,
      amount: 30000,
      date: DateTime(2026, 8, 10, 12),
      split: {1: 10000, 2: 10000, 3: 10000},
      title: 'Dinner'),
  // Chen pays Asha back ₹100.
  expense(3,
      paidBy: 3,
      amount: 10000,
      date: DateTime(2026, 9, 2),
      split: {1: 10000},
      category: 'payment'),
  // Ben pays ₹100.50 for Asha and Ben, unevenly in paise.
  expense(2,
      paidBy: 2,
      amount: 10050,
      date: DateTime(2026, 9, 2),
      split: {1: 5025, 2: 5025},
      title: 'Snacks'),
  // Ben pays ₹60 for Chen: nothing to do with Asha.
  expense(4,
      paidBy: 2,
      amount: 6000,
      date: DateTime(2026, 9, 3),
      split: {3: 6000},
      title: 'Tickets'),
];

Statement statementFor(int userId, {List<Expense>? expenses}) => buildStatement(
      expenses: expenses ?? groupExpenses,
      userId: userId,
      memberName: names[userId]!,
      groupName: 'Goa Trip',
      now: DateTime(2026, 10, 11, 17, 30),
    );

final inr = currencyFor('INR');

void main() {
  // statementPdf loads its fonts from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildStatement', () {
    test('lists only what the member took part in, oldest first', () {
      final s = statementFor(1);

      expect(
          s.lines.map((l) => l.title), ['Dinner', 'Snacks', 'payment', 'Taxi']);
      // Same day: the lower transaction id first.
      expect(s.lines[1].date, s.lines[2].date);
    });

    test('moves the balance by what was paid minus what was taken out', () {
      final s = statementFor(1);

      expect(s.lines.map((l) => (l.paid, l.share, l.change, l.balance)), [
        (30000, 10000, 20000, 20000), // paid for all, own share
        (0, 5025, -5025, 14975), // share of Ben's expense
        (0, 10000, -10000, 4975), // payment received
        (4000, 0, 4000, 8975), // paid for someone else
      ]);
      expect(s.lines[2].kind, StatementLineKind.paymentReceived);
      expect(s.lines[2].counterpartName, 'Chen');
    });

    test("ends at the backend's balance: paid minus transaction parts", () {
      // getOverviewDataInGroup: sum(transactions.amount by the user) minus
      // sum(transaction_parts.amount of the user), payments included.
      int serverBalance(int userId) {
        var paid = 0;
        var parts = 0;
        for (final e in groupExpenses) {
          if (e.userId == userId) paid += e.transactionAmount;
          for (final d in e.distributions) {
            if (d.userId == userId) parts += d.amount!;
          }
        }
        return paid - parts;
      }

      for (final id in names.keys) {
        final s = statementFor(id);
        expect(s.balance, serverBalance(id), reason: names[id]);
        expect(s.lines.last.balance, s.balance, reason: names[id]);
      }
      expect(statementFor(1).balance, 8975);
    });

    test('splits the totals into expenses and payments', () {
      final asha = statementFor(1);
      expect(asha.paidForExpenses, 34000);
      expect(asha.shareOfExpenses, 15025);
      expect(asha.paymentsSent, 0);
      expect(asha.paymentsReceived, 10000);

      final chen = statementFor(3);
      expect(chen.paymentsSent, 10000);
      expect(chen.lines[1].kind, StatementLineKind.paymentSent);
      expect(chen.lines[1].counterpartName, 'Asha');
    });

    test("suggests only the settle-up payments involving the member", () {
      expect(statementFor(1).settleUp.map((p) => (p.from, p.to, p.amount)), [
        (3, 1, 6000),
        (2, 1, 2975),
      ]);
      expect(statementFor(3).settleUp.map((p) => (p.from, p.to, p.amount)), [
        (3, 1, 6000),
      ]);
    });

    test('a member with no transactions is settled up with nothing listed', () {
      final s = statementFor(1, expenses: []);
      expect(s.lines, isEmpty);
      expect(s.balance, 0);
      expect(s.settleUp, isEmpty);
    });
  });

  group('statementText', () {
    test('reads as a third-person statement', () {
      final text = statementText(statementFor(1), inr);

      expect(text,
          startsWith('*Split statement: Asha*\nGoa Trip · 11 Oct 2026\n'));
      expect(text, contains('*Asha gets back ₹89.75*'));
      expect(text, contains('Paid for expenses: ₹340'));
      expect(text, contains('Payments received: ₹100'));
      expect(text, contains('• Chen pays Asha ₹60\n• Ben pays Asha ₹29.75'));
      expect(text, contains('*Transactions (4)*'));
      expect(
          text,
          contains('10 Aug 2026 · Dinner\n'
              "Asha paid ₹300 · Asha's share ₹100\n"
              'Balance: gets back ₹200\n'));
      expect(
          text,
          contains('2 Sep 2026 · Payment from Chen\n'
              'Asha received ₹100\n'
              'Balance: gets back ₹49.75\n'));
      expect(text, endsWith('_Shared from Split_'));
      expect(text, isNot(matches(RegExp(r'\byou\b', caseSensitive: false))));
    });

    test('says who owes and who is settled up', () {
      expect(statementText(statementFor(3), inr), contains('*Chen owes ₹60*'));
      expect(statementText(statementFor(3), inr),
          contains('Payment to Asha\nChen paid ₹100\n'));
      final empty = statementText(statementFor(1, expenses: []), inr);
      expect(empty, contains('*Asha is settled up*'));
      expect(empty, contains('*Transactions (0)*\nNone yet.'));
      expect(empty, isNot(contains('To settle up')));
    });

    test('shows only the most recent transactions of a long history', () {
      final many = [
        for (var i = 1; i <= statementTextLineLimit + 2; i++)
          expense(i,
              paidBy: 1,
              amount: 100,
              date: DateTime(2026, 1, 1).add(Duration(hours: i)),
              split: {1: 50, 2: 50},
              title: 'Item $i'),
      ];
      final text = statementText(statementFor(1, expenses: many), inr);

      expect(text, contains('*Transactions (52)*'));
      expect(
          text,
          contains(
              '2 earlier transactions not shown. Share as PDF for the full list.'));
      expect(text, isNot(contains('Item 2\n')));
      expect(text, contains('Item 3\n'));
      expect(text, contains('Item 52\n'));
      // The balances still count the hidden ones.
      expect(text, contains('Balance: gets back ₹26\n\n_Shared'));
    });

    test('formats amounts in the group currency, whatever its decimals', () {
      final yen = statementText(
        statementFor(1, expenses: [
          expense(1,
              paidBy: 1,
              amount: 1500,
              date: DateTime(2026, 9, 1),
              split: {1: 750, 2: 750}),
        ]),
        currencyFor('JPY'),
      );
      expect(yen, contains('*Asha gets back ¥750*'));

      final dinar = statementText(
        statementFor(1, expenses: [
          expense(1,
              paidBy: 2,
              amount: 2500,
              date: DateTime(2026, 9, 1),
              split: {1: 1250, 2: 1250}),
        ]),
        currencyFor('KWD'),
      );
      expect(dinar, contains('*Asha owes KWD 1.250*'));
    });
  });

  group('statementPdf', () {
    test('names the file after the member, group and day', () {
      final s = buildStatement(
        expenses: const [],
        userId: 1,
        memberName: 'Asha',
        groupName: 'Goa/Trip: 2026?',
        now: DateTime(2026, 10, 1, 9),
      );
      expect(statementFileName(s),
          'Split statement - Asha - GoaTrip 2026 - 2026-10-01.pdf');
    });

    test('draws a long statement over several pages', () async {
      int pages(List<int> pdf) => int.parse(RegExp(r'/Count (\d+)')
          .firstMatch(latin1.decode(pdf))!
          .group(1)!);

      final many = [
        for (var i = 1; i <= 150; i++)
          expense(i,
              paidBy: i.isEven ? 1 : 2,
              amount: 12345,
              date: DateTime(2026, 1, 1).add(Duration(hours: i)),
              split: {1: 6173, 2: 6172},
              title: 'Item $i'),
      ];
      final bytes = await statementPdf(statementFor(1, expenses: many), inr);

      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      expect(pages(bytes), greaterThan(1));
      expect(pages(await statementPdf(statementFor(1), inr)), 1);
    });

    test('leaves out what the font cannot draw instead of a box', () async {
      final printed = <String>[];
      await runZoned(
        () => statementPdf(
          buildStatement(
            expenses: [
              expense(1,
                  paidBy: 1,
                  amount: 30000,
                  date: DateTime(2026, 9, 1),
                  split: {1: 15000, 2: 15000},
                  title: '🍕 Pizza'),
            ],
            userId: 1,
            memberName: 'राहुल',
            groupName: 'Goa 🏖️',
            now: DateTime(2026, 10, 11),
          ),
          inr,
        ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      expect(
          printed.where((l) => l.contains('Unable to find a font')), isEmpty);
    });
  });
}
