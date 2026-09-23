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
}) =>
    Expense(
      groupId: 63,
      groupName: 'Goa Trip',
      userId: payerId,
      userName: payerName,
      transactionId: transactionId,
      transactionTitle: title,
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
    test('identifies payments by title', () {
      expect(isPayment(_all.first), isTrue);
      expect(_all.skip(1).every(isPayment), isFalse);
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
}
