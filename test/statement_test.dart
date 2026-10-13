import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/models/expense/distribution.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/services/statement_pdf.dart';
import 'package:split_expense/src/utils/currency.dart';
import 'package:split_expense/src/utils/statement.dart';
import 'package:split_expense/src/utils/statement_wording.dart';

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

  group('statement wording', () {
    test('is in the third person', () {
      final asha = statementFor(1);

      expect(statementHeadline(asha, inr), 'Asha gets back ₹89.75');
      expect(statementHeadline(statementFor(3), inr), 'Chen owes ₹60');
      expect(statementHeadline(statementFor(1, expenses: []), inr),
          'Asha is settled up');
      expect(asha.settleUp.map((p) => settleUpWords(p, inr)),
          ['Chen pays Asha ₹60', 'Ben pays Asha ₹29.75']);
    });

    test("describes each transaction from the member's side", () {
      String describe(StatementLine line, String name) =>
          '${statementLineTitle(line)} | '
          '${statementLineDetail(line, name, inr)}';

      expect(statementFor(1).lines.map((l) => describe(l, 'Asha')), [
        "Dinner | Asha paid ₹300 · Asha's share ₹100",
        "Snacks | Ben paid ₹100.50 · Asha's share ₹50.25",
        'Payment from Chen | Asha received ₹100',
        "Taxi | Asha paid ₹40 · Asha's share ₹0",
      ]);
      expect(describe(statementFor(3).lines[1], 'Chen'),
          'Payment to Asha | Chen paid ₹100');
    });

    test('formats amounts in the group currency, whatever its decimals', () {
      final yen = statementFor(1, expenses: [
        expense(1,
            paidBy: 1,
            amount: 1500,
            date: DateTime(2026, 9, 1),
            split: {1: 750, 2: 750}),
      ]);
      expect(statementHeadline(yen, currencyFor('JPY')), 'Asha gets back ¥750');

      final dinar = statementFor(1, expenses: [
        expense(1,
            paidBy: 2,
            amount: 2500,
            date: DateTime(2026, 9, 1),
            split: {1: 1250, 2: 1250}),
      ]);
      expect(
          statementHeadline(dinar, currencyFor('KWD')), 'Asha owes KWD 1.250');
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
      int pages(List<int> pdf) => int.parse(
          RegExp(r'/Count (\d+)').firstMatch(latin1.decode(pdf))!.group(1)!);

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
