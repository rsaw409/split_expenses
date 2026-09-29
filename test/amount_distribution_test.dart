import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/components/amount_distribution.dart';
import 'package:split_expense/src/components/customchip.dart';
import 'package:split_expense/src/models/user.dart';
import 'package:split_expense/src/utils/currency.dart';

void main() {
  const users = [
    User(id: 1, name: 'Alice Brown'),
    User(id: 2, name: 'Bob Stone'),
    User(id: 3, name: 'Carol Doe'),
  ];

  List<Map<String, dynamic>>? submitted;

  // Reopens the sheet with a selection saved by an earlier open: those maps
  // are not the objects the sheet builds its chips from this time.
  Future<void> openWith(
      WidgetTester tester, List<Map<String, dynamic>> selected,
      {int total = 10000, Currency? currency}) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    submitted = null;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAmountDistributionModal(
                context, total, users, selected, (val) => submitted = val,
                currency: currency),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // Amounts are paise throughout: the total is ₹100.
  final previous = [
    {'id': 1, 'name': 'Alice Brown', 'amount': 5000},
    {'id': 2, 'name': 'Bob Stone', 'amount': 5000},
  ];

  testWidgets('a reopened sheet shows the saved selection', (tester) async {
    await openWith(tester, previous);

    // One row per saved member, not zero, and their amounts are restored.
    expect(find.widgetWithText(TextFormField, '50'), findsNWidgets(2));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(submitted!.map((u) => u['id']), [1, 2]);
  });

  testWidgets('tapping a saved member deselects instead of duplicating',
      (tester) async {
    await openWith(tester, previous);

    await tester.tap(_chip('Alice Brown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(submitted, [
      {'id': 2, 'name': 'Bob Stone', 'avatar': null, 'amount': 10000},
    ]);
  });

  testWidgets('adding a member after reopening adds them once', (tester) async {
    await openWith(tester, previous);

    await tester.tap(_chip('Carol Doe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(submitted!.map((u) => u['id']), [1, 2, 3]);
    final total = submitted!.fold<int>(0, (a, u) => a + (u['amount'] as int));
    expect(total, 10000);
  });

  testWidgets('a decimal share can be typed and rebalances the others',
      (tester) async {
    await openWith(tester, previous);

    final first = find.byType(TextField).first;
    for (final typed in ['3', '33', '33.', '33.3', '33.33']) {
      await tester.enterText(first, typed);
      await tester.pump();
    }
    expect(tester.widget<TextField>(first).controller!.text, '33.33');

    // Done straight away, without the keyboard's action key.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(submitted!.map((u) => u['amount']), [3333, 6667]);
  });

  testWidgets('in yen, an equal split hands out whole yen that add up',
      (tester) async {
    // ¥1000 has no minor unit: stored as 1000, and three ways it cannot
    // split evenly, so one person carries the extra yen.
    await openWith(tester, previous,
        total: 1000, currency: currencyFor('JPY'));

    await tester.tap(_chip('Carol Doe'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '334'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '333'), findsNWidgets(2));
    expect(find.text('¥ '), findsNWidgets(3));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(submitted!.map((u) => u['amount']), [334, 333, 333]);
  });
}

/// A member's chip in the split sheet. The name also labels their amount
/// field once selected, so match the chip itself.
Finder _chip(String name) => find.descendant(
      of: find.byType(CustomChip),
      matching: find.text(name),
    );
