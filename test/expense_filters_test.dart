import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/models/expense/distribution.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/utils/expense_filters.dart';

/// Mirrors a real group fetched from the backend, so these tests pin the
/// server's filter semantics rather than the implementation's own opinion.
///
/// tid 223 is a payment (Neha → Rohit); 220/221/222 are expenses split four
/// ways. Rohit benefits from all four, since he received the payment.
const _neha = 142, _priya = 140, _rohit = 139, _aman = 141;

Expense _expense({
  required int transactionId,
  required String title,
  required int payerId,
  required String payerName,
  required num amount,
  required List<int> distributedTo,
  String? category,
}) =>
    Expense(
      groupId: 63,
      groupName: 'Goa Trip',
      userId: payerId,
      userName: payerName,
      transactionId: transactionId,
      transactionTitle: title,
      transactionCategory: category,
      transactionAmount: amount,
      transactionDate: DateTime(2026, 9, 21),
      distributions: distributedTo
          .map((id) => Distribution(
                amount: amount / distributedTo.length,
                userId: id,
                userName: '$id',
              ))
          .toList(),
    );

final _all = <Expense>[
  _expense(
    transactionId: 223,
    title: 'payment',
    category: 'payment',
    payerId: _neha,
    payerName: 'Neha',
    amount: 1500,
    distributedTo: [_rohit],
  ),
  _expense(
    transactionId: 222,
    title: 'Scooty Rental',
    payerId: _aman,
    payerName: 'Aman',
    amount: 1200,
    distributedTo: [_neha, _rohit, _priya, _aman],
  ),
  _expense(
    transactionId: 221,
    title: 'Dinner at Beach Shack',
    payerId: _priya,
    payerName: 'Priya',
    amount: 2400,
    distributedTo: [_aman, _priya, _rohit, _neha],
  ),
  _expense(
    transactionId: 220,
    title: 'Beach Resort Booking',
    payerId: _rohit,
    payerName: 'Rohit',
    amount: 8000,
    distributedTo: [_aman, _rohit, _neha, _priya],
  ),
];

List<int> _ids(List<Expense> expenses) =>
    expenses.map((e) => e.transactionId).toList();

void main() {
  group('filterExpenses', () {
    test('identifies payments by the server category, not the title', () {
      expect(isPayment(_all.first), isTrue);
      expect(_all.skip(1).any(isPayment), isFalse);
    });

    test('an expense merely titled "payment" is not a payment', () {
      // The bug this discriminator replaces: matching on the title made any
      // expense a user happened to call "payment" render as a transfer and
      // land in the Payments row.
      final titledPayment = _expense(
        transactionId: 300,
        title: 'payment',
        payerId: _rohit,
        payerName: 'Rohit',
        amount: 250,
        distributedTo: [_rohit, _neha],
      );

      expect(isPayment(titledPayment), isFalse);
      expect(
        filterExpenses([titledPayment], byId: _rohit, isPayments: true),
        isEmpty,
        reason: 'it must not be counted as one of Rohit\'s payments',
      );
      expect(
        filterExpenses([titledPayment], byId: _rohit, isPayments: false),
        hasLength(1),
        reason: 'it belongs in the Expenses row',
      );
    });

    test('"Expenses" row: paid by the user, excluding payments', () {
      expect(_ids(filterExpenses(_all, byId: _rohit, isPayments: false)), [220]);
      expect(filterExpenses(_all, byId: _neha, isPayments: false), isEmpty);
      expect(_ids(filterExpenses(_all, byId: _priya, isPayments: false)), [221]);
      expect(_ids(filterExpenses(_all, byId: _aman, isPayments: false)), [222]);
    });

    test('"Payments" row: payments made by the user', () {
      expect(_ids(filterExpenses(_all, byId: _neha, isPayments: true)), [223]);
      expect(filterExpenses(_all, byId: _rohit, isPayments: true), isEmpty);
    });

    test('"Benefits from" row: user appears in the distributions', () {
      // Rohit's 4 includes the payment he received — payments are not excluded
      // from this filter, matching the backend.
      expect(_ids(filterExpenses(_all, userId: _rohit)), [223, 222, 221, 220]);
      expect(_ids(filterExpenses(_all, userId: _neha)), [222, 221, 220]);
      expect(_ids(filterExpenses(_all, userId: _priya)), [222, 221, 220]);
      expect(_ids(filterExpenses(_all, userId: _aman)), [222, 221, 220]);
    });

    test('counts match what the backend reports per user', () {
      // number_of_transactions / number_of_payments / number_of_benefits
      const expected = {
        _neha: [0, 1, 3],
        _priya: [1, 0, 3],
        _rohit: [1, 0, 4],
        _aman: [1, 0, 3],
      };

      expected.forEach((userId, counts) {
        expect(
          [
            filterExpenses(_all, byId: userId, isPayments: false).length,
            filterExpenses(_all, byId: userId, isPayments: true).length,
            filterExpenses(_all, userId: userId).length,
          ],
          counts,
          reason: 'counts for user $userId',
        );
      });
    });

    test('no filters returns everything, in the original order', () {
      expect(_ids(filterExpenses(_all)), [223, 222, 221, 220]);
    });
  });

  group('wire and cache round trip', () {
    // Copied from a real getAllExpensesInGroup response, so this pins the
    // field name the discriminator depends on.
    Map<String, dynamic> row(Object? category) => {
          'group_id': 63,
          'group_name': 'Goa Trip',
          'user_id': 142,
          'user_name': 'Neha',
          'transaction_id': 223,
          'transaction_title': 'payment',
          'transaction_category': category,
          'transaction_amount': 1500,
          'transaction_date': '2026-09-21T00:00:00.000Z',
          'distributions': [
            {'amount': 1500, 'user_id': 139, 'user_name': 'Rohit'},
          ],
        };

    test('parses transaction_category from the API payload', () {
      expect(isPayment(Expense.fromMap(row('payment'))), isTrue);
      expect(isPayment(Expense.fromMap(row(null))), isFalse);
    });

    test('survives the cache round trip, so cached payments stay payments', () {
      final cached = Expense.fromMap(
        jsonDecode(jsonEncode(Expense.fromMap(row('payment')).toMap()))
            as Map<String, dynamic>,
      );

      expect(isPayment(cached), isTrue);
    });

    test('infers the category for a cache entry predating the field', () {
      // No key at all means a cache entry written by an older build. Falling
      // back to the title only here keeps payments already on disk rendering
      // correctly instead of degrading to "payment / <payer>" until a refetch.
      final legacy = row('payment')..remove('transaction_category');

      expect(isPayment(Expense.fromMap(legacy)), isTrue);
    });

    test('a present-but-null category is authoritative, not a missing field',
        () {
      // This is the distinction that lets the fallback exist without
      // reinstating the bug: the server sends the key as null for expenses, so
      // an expense titled "payment" must stay an expense.
      final titled = row(null)..['transaction_title'] = 'payment';

      expect(titled.containsKey('transaction_category'), isTrue);
      expect(isPayment(Expense.fromMap(titled)), isFalse);
    });
  });
}
