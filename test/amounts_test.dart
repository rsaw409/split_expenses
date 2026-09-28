import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/services/cache_service.dart';
import 'package:split_expense/src/utils/currency.dart';

// The API sends and accepts integers in the group currency's minor unit
// (paise for INR). Decimals exist only at the UI edges.
void main() {
  group('currency', () {
    final inr = currencyFor('INR');
    final jpy = currencyFor('JPY');
    final kwd = currencyFor('KWD');
    final usd = currencyFor('USD');

    test('formats minor units in the currency, dropping zero decimals', () {
      expect(inr.format(12050), '₹120.50');
      expect(inr.format(100000), '₹1,000');
      expect(inr.format(10000000), '₹1,00,000'); // Indian grouping
      expect(usd.format(10000000), r'$100,000');
      expect(jpy.format(1500), '¥1,500'); // yen have no minor unit
      expect(kwd.format(1250), 'KWD 1.250'); // 1000 fils to the dinar
      expect(kwd.format(2000), 'KWD 2');
    });

    test('parses typed amounts exactly, per the currency\'s decimals', () {
      expect(inr.parse('166.67'), 16667);
      expect(inr.parse('0.1'), 10);
      expect(inr.parse('100'), 10000);
      expect(inr.parse('12.'), 1200);
      expect(jpy.parse('1500'), 1500);
      expect(kwd.parse('1.25'), 1250);
      expect(kwd.parse('0.005'), 5);
    });

    test('refuses amounts with more decimals than the currency has', () {
      expect(inr.parse('1.234'), isNull);
      expect(jpy.parse('1.5'), isNull);
      expect(kwd.parse('1.2345'), isNull);
      expect(inr.parse(''), isNull);
      expect(inr.parse('abc'), isNull);
    });

    test('writes amounts back for a text field', () {
      expect(inr.toText(16667), '166.67');
      expect(inr.toText(10000), '100');
      expect(inr.toText(1205), '12.05');
      expect(jpy.toText(1500), '1500');
      expect(kwd.toText(1005), '1.005');
      expect(inr.toText(-250), '-2.50');
    });

    test('text round-trips through parse without drift', () {
      for (final c in [inr, jpy, kwd]) {
        for (final amount in [0, 1, 7, 99, 100, 1001, 123456]) {
          expect(c.parse(c.toText(amount)), amount, reason: '$c $amount');
        }
      }
    });

    test('the input filter follows the decimals', () {
      expect(inr.inputPattern.stringMatch('12.345'), '12.34');
      expect(jpy.inputPattern.stringMatch('12.5'), '12');
      expect(kwd.inputPattern.stringMatch('1.2345'), '1.234');
    });

    test('an unknown or missing code falls back to INR', () {
      expect(currencyFor(null).code, 'INR');
      expect(currencyFor('XYZ').code, 'INR');
    });
  });

  group('models read integer amounts from the API', () {
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
