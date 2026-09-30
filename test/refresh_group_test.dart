import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/notify_controllers/allexpense_controller.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';
import 'package:split_expense/src/utils/refresh_group.dart';
import 'package:split_expense/src/views/all_expenses_view.dart';
import 'package:split_expense/src/views/overview_view.dart';

/// No group, so nothing is fetched; each refresh waits for [gate].
class FakeExpenses extends AllExpenseController {
  FakeExpenses() : super(null);
  int refreshes = 0;
  Completer<void> gate = Completer<void>();
  @override
  Future<void> refresh() {
    refreshes++;
    return gate.future;
  }
}

class FakeBalances extends UserBalanceController {
  FakeBalances() : super(null);
  int refreshes = 0;
  Completer<void> gate = Completer<void>();
  @override
  Future<void> refresh() {
    refreshes++;
    return gate.future;
  }
}

/// A selected group with nothing in it, or whose fetch fails.
class EmptyExpenses extends AllExpenseController {
  EmptyExpenses({this.fail = false}) : super(1);
  final bool fail;
  int refreshes = 0;
  @override
  Future<List<Expense>> fetchFromNetwork(int id) async =>
      fail ? throw Exception('offline') : <Expense>[];
  @override
  Future<List<Expense>?> readFromCache(int id) async => null;
  @override
  Future<void> writeToCache(int id, List<Expense> items) async {}
  @override
  Future<void> refresh() {
    refreshes++;
    return super.refresh();
  }
}

class EmptyBalances extends UserBalanceController {
  EmptyBalances({this.fail = false}) : super(1);
  final bool fail;
  int refreshes = 0;
  @override
  Future<List<UserBalance>> fetchFromNetwork(int id) async =>
      fail ? throw Exception('offline') : <UserBalance>[];
  @override
  Future<List<UserBalance>?> readFromCache(int id) async => null;
  @override
  Future<void> writeToCache(int id, List<UserBalance> items) async {}
  @override
  Future<void> refresh() {
    refreshes++;
    return super.refresh();
  }
}

void main() {
  late FakeExpenses expenses;
  late FakeBalances balances;
  late BuildContext context;

  Future<void> pump(WidgetTester tester) async {
    expenses = FakeExpenses();
    balances = FakeBalances();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AllExpenseController>.value(value: expenses),
          ChangeNotifierProvider<UserBalanceController>.value(value: balances),
        ],
        child: Builder(builder: (ctx) {
          context = ctx;
          return const SizedBox();
        }),
      ),
    );
  }

  // Pulling on the overview used to refresh only balances, leaving the
  // transaction list stale, and pulling on a transaction list the reverse.
  testWidgets('refreshes transactions and balances together',
      (tester) async {
    await pump(tester);
    unawaited(refreshGroupData(context));
    expect(expenses.refreshes, 1);
    expect(balances.refreshes, 1);
  });

  testWidgets('completes only once both have, for the pull spinner',
      (tester) async {
    await pump(tester);
    var done = false;
    unawaited(refreshGroupData(context).then((_) => done = true));

    expenses.gate.complete();
    await tester.pump();
    expect(done, isFalse);

    balances.gate.complete();
    await tester.pump();
    expect(done, isTrue);
  });

  // An empty or failed list is exactly when someone pulls to check again,
  // but those screens used to replace the pullable list entirely.
  group('empty and failed screens can be pulled', () {
    late EmptyExpenses expenses;
    late EmptyBalances balances;

    Future<void> pumpScreen(
      WidgetTester tester,
      Widget screen, {
      bool fail = false,
    }) async {
      expenses = EmptyExpenses(fail: fail);
      balances = EmptyBalances(fail: fail);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AllExpenseController>.value(
                value: expenses),
            ChangeNotifierProvider<UserBalanceController>.value(
                value: balances),
          ],
          child: MaterialApp(home: Scaffold(body: screen)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pull(WidgetTester tester, Finder from) async {
      await tester.fling(from, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
    }

    testWidgets('an empty transaction list', (tester) async {
      await pumpScreen(tester, const AllExpensesView());
      await pull(tester, find.text('No expenses yet'));
      expect(expenses.refreshes, 1);
      expect(balances.refreshes, 1);
    });

    testWidgets('an empty overview', (tester) async {
      await pumpScreen(tester, const OverviewView());
      await pull(tester, find.text('No balances yet'));
      expect(expenses.refreshes, 1);
      expect(balances.refreshes, 1);
    });

    testWidgets('a failed load, which Retry refreshes in full too',
        (tester) async {
      await pumpScreen(tester, const AllExpensesView(), fail: true);
      final error = find.textContaining('Could not load expenses');
      await pull(tester, error);
      expect(expenses.refreshes, 1);
      expect(balances.refreshes, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(expenses.refreshes, 2);
      expect(balances.refreshes, 2);
      // Let the controllers' one bounded retry after a failure run out.
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
