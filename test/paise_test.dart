import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/services/cache_service.dart';
import 'package:split_expense/src/utils/currency.dart';

// The API sends and accepts integer paise. Rupees exist only at the UI edges.
void main() {
  group('currency', () {
    test('formats paise as rupees', () {
      expect(formatPaise(12050), '₹120.50');
      expect(formatPaise(100000), '₹1,000');
      expect(formatPaise(16667), '₹166.67');
    });

    test('parses typed rupees into paise', () {
      expect(rupeesToPaise(166.67), 16667);
      expect(rupeesToPaise(0.1), 10);
      expect(paiseToText(16667), '166.67');
      expect(paiseToText(10000), '100');
    });
  });

  group('models read the paise API', () {
    test('balances and counts are ints', () {
      final balance = UserBalance.fromMap({
        'name': 'Neha',
        'user_id': 142,
        'balances': -16667,
        'number_of_transactions': 3,
        'number_of_benefits': 4,
        'number_of_payments': 1,
      });
      expect(balance.balances, -16667);
      expect(balance.numberOfTransactions, 3);
    });

    test('expense amounts are ints', () {
      final expense = Expense.fromMap({
        'group_id': 63,
        'group_name': 'Goa Trip',
        'user_id': 139,
        'user_name': 'Rohit',
        'transaction_id': 1,
        'transaction_title': 'Dinner',
        'transaction_category': null,
        'transaction_amount': 100000,
        'transaction_date': '2026-09-21T00:00:00.000Z',
        'distributions': [
          {'amount': 16667, 'user_id': 139, 'user_name': 'Rohit'},
        ],
      });
      expect(expense.transactionAmount, 100000);
      expect(expense.distributions.single.amount, 16667);
    });
  });

  group('cache', () {
    // A rupee-era entry: 100 parses cleanly as an int, so only the versioned
    // key keeps it from being read back as ₹1.
    final rupeeEraBalances = jsonEncode([
      {
        'name': 'Neha',
        'user_id': 142,
        'balances': 100,
        'number_of_transactions': '1',
        'number_of_benefits': '1',
        'number_of_payments': '0',
      }
    ]);

    test('ignores entries cached in rupees', () async {
      SharedPreferences.setMockInitialValues(
          {'cache_balances_63': rupeeEraBalances});
      expect(await getCachedBalances(63), isNull);
    });

    test('dropStaleCaches removes old entries and keeps everything else',
        () async {
      SharedPreferences.setMockInitialValues({
        'cache_balances_63': rupeeEraBalances,
        'cache_expenses_63': '[]',
        'theme': 'dark',
        'groups': '[]',
      });
      await setCachedExpenses(63, const []);

      await dropStaleCaches();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(),
          unorderedEquals(['cache_v2_expenses_63', 'theme', 'groups']));
      expect(await getCachedExpenses(63), isEmpty);
    });
  });
}
