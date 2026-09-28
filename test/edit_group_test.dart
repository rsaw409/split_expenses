import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/notify_controllers/allexpense_controller.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/views/edit_group_view.dart';

/// Serves a fixed list instead of the network; [pending] keeps it loading,
/// [failing] makes the load fail.
class FakeExpenses extends AllExpenseController {
  FakeExpenses(super.groupId,
      {this.list = const [], this.pending = false, this.failing = false});

  final List<Expense> list;
  final bool pending;
  final bool failing;

  @override
  Future<List<Expense>> fetchFromNetwork(int id) async {
    if (pending) return Completer<List<Expense>>().future;
    if (failing) throw Exception('offline');
    return list;
  }

  @override
  Future<List<Expense>?> readFromCache(int id) async => null;

  @override
  Future<void> writeToCache(int id, List<Expense> items) async {}
}

final anExpense = Expense(
  groupId: 1,
  groupName: 'Goa Trip',
  userId: 1,
  userName: 'Asha',
  transactionId: 1,
  transactionTitle: 'Dinner',
  transactionAmount: 10000,
  transactionDate: DateTime(2026, 9, 1),
  distributions: const [],
);

void main() {
  const goa = Group(id: 1, name: 'Goa Trip', inviteId: 'x', currency: 'INR');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpForm(WidgetTester tester, {AllExpenseController? expenses})
      async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GroupsController()),
          ChangeNotifierProvider<AllExpenseController>(
            create: (_) => expenses ?? FakeExpenses(goa.id),
          ),
        ],
        child: const MaterialApp(home: EditGroupView(group: goa)),
      ),
    );
    await tester.pump();
  }

  DropdownButton<String> currencyDropdown(WidgetTester tester) =>
      tester.widget(find.byType(DropdownButton<String>));

  const lockedHint = "Can't be changed once the group has expenses or payments.";

  FilledButton saveButton(WidgetTester tester) => tester.widget(
        find.widgetWithText(FilledButton, 'Save changes'),
      );

  testWidgets('starts with the current name and currency', (tester) async {
    await pumpForm(tester);

    expect(find.widgetWithText(TextFormField, 'Goa Trip'), findsOneWidget);
    expect(find.text('Indian Rupee (₹)'), findsOneWidget);
  });

  testWidgets('Save is enabled only once something has changed',
      (tester) async {
    await pumpForm(tester);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'Goa 2026');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    // Back to the original, give or take spaces: nothing to save.
    await tester.enterText(find.byType(TextFormField), '  Goa Trip ');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a blank name is refused before any request', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pump();

    expect(find.text('Give the group a name.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('names are capped at $maxGroupNameLength characters',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField), 'x' * 80);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, hasLength(maxGroupNameLength));
  });

  testWidgets('picking the currency it already has changes nothing',
      (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Indian Rupee (₹)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indian Rupee (₹)').last);
    await tester.pumpAndSettle();

    expect(saveButton(tester).onPressed, isNull);
  });

  group('currency', () {
    testWidgets('can change when the group has no transactions',
        (tester) async {
      await pumpForm(tester);

      expect(currencyDropdown(tester).onChanged, isNotNull);
      expect(find.text(lockedHint), findsNothing);
    });

    testWidgets('is locked once the group has a transaction', (tester) async {
      await pumpForm(tester,
          expenses: FakeExpenses(goa.id, list: [anExpense]));

      expect(currencyDropdown(tester).onChanged, isNull);
      expect(find.text(lockedHint), findsOneWidget);
    });

    testWidgets('stays locked while the list is still loading',
        (tester) async {
      await pumpForm(tester, expenses: FakeExpenses(goa.id, pending: true));

      expect(currencyDropdown(tester).onChanged, isNull);
    });

    testWidgets('stays locked when the list failed to load', (tester) async {
      await pumpForm(tester, expenses: FakeExpenses(goa.id, failing: true));

      expect(currencyDropdown(tester).onChanged, isNull);
    });

    testWidgets('stays locked when the list is for another group',
        (tester) async {
      await pumpForm(tester, expenses: FakeExpenses(99));

      expect(currencyDropdown(tester).onChanged, isNull);
    });

    testWidgets('renaming still works when the currency is locked',
        (tester) async {
      await pumpForm(tester,
          expenses: FakeExpenses(goa.id, list: [anExpense]));

      await tester.enterText(find.byType(TextFormField), 'Goa 2026');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);
    });
  });
}
