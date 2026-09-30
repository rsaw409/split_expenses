import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/allexpense_controller.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';
import 'package:split_expense/src/utils/refresh_group.dart';

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
}
