import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/models/user.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/utils/members.dart';

UserBalance _balance({
  required String name,
  required int userId,
  required num balances,
  String transactions = '1',
  String payments = '0',
  String benefits = '1',
}) =>
    UserBalance(
      name: name,
      userId: userId,
      balances: balances,
      numberOfTransactions: transactions,
      numberOfPayments: payments,
      numberOfBenefits: benefits,
    );

void main() {
  group('membersFromBalances', () {
    test('maps every balance row to a member option', () {
      final members = membersFromBalances([
        _balance(name: 'Rohit', userId: 139, balances: 3600),
        _balance(name: 'Neha', userId: 142, balances: -1400),
      ]);

      expect(members, const [
        User(name: 'Rohit', id: 139),
        User(name: 'Neha', id: 142),
      ]);
    });

    test('includes a member with no activity at all', () {
      // The property this substitution depends on, confirmed against the live
      // backend: getOverviewDataInGroup returns a freshly added member with a
      // zero balance and zero counts. If such members were dropped, someone
      // just added to the group could not be picked as the payer.
      final members = membersFromBalances([
        _balance(name: 'Rohit', userId: 139, balances: 3600),
        _balance(
          name: 'zz-test-member',
          userId: 150,
          balances: 0,
          transactions: '0',
          payments: '0',
          benefits: '0',
        ),
      ]);

      expect(members, contains(const User(name: 'zz-test-member', id: 150)));
      expect(members, hasLength(2));
    });

    test('is empty before balances have loaded', () {
      // Opening the form on a cold start with no cache yet: the pickers stay
      // hidden until the refresh lands, matching the old behaviour while
      // getUsersInGroup was in flight.
      expect(membersFromBalances(const []), isEmpty);
    });
  });
}
