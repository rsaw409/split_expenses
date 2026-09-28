import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/notify_controllers/backend_reachability.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/utils/settlement.dart';
import 'package:split_expense/src/views/settle_view.dart';

UserBalance balance(int id, String name, int paise) => UserBalance(
      name: name,
      userId: id,
      balances: paise,
      numberOfTransactions: 0,
      numberOfBenefits: 0,
      numberOfPayments: 0,
    );

/// Stands in for the real controller, which probes the network on a timer.
class _FakeReachability extends ChangeNotifier implements BackendReachability {
  _FakeReachability(this.isReachable);

  @override
  final bool isReachable;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('suggestPayments', () {
    test('settles every balance exactly', () {
      final balances = [
        balance(1, 'A', 60000),
        balance(2, 'B', 15050),
        balance(3, 'C', -40000),
        balance(4, 'D', -35050),
      ];
      final payments = suggestPayments(balances);

      final net = {for (final b in balances) b.userId: b.balances};
      for (final p in payments) {
        net[p.from] = net[p.from]! + p.amount;
        net[p.to] = net[p.to]! - p.amount;
      }
      expect(net.values, everyElement(0));
    });

    test('never suggests a zero payment when both sides clear together', () {
      // C clears A exactly, so both indices must advance before D pays B.
      final payments = suggestPayments([
        balance(1, 'A', 40000),
        balance(2, 'B', 10000),
        balance(3, 'C', -40000),
        balance(4, 'D', -10000),
      ]);

      expect(payments.map((p) => (p.from, p.to, p.amount)), [
        (3, 1, 40000),
        (4, 2, 10000),
      ]);
    });

    test('is empty when everyone is settled', () {
      expect(suggestPayments([balance(1, 'A', 0), balance(2, 'B', 0)]),
          isEmpty);
    });
  });

  group('SettleView', () {
    Future<void> pumpSettle(WidgetTester tester, {bool reachable = true}) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => GroupsController()),
            ChangeNotifierProvider<BackendReachability>(
              create: (_) => _FakeReachability(reachable),
            ),
          ],
          child: MaterialApp(
            home: SettleView(userBalances: [
              balance(1, 'Asha', 30000),
              balance(2, 'Ben', 12050),
              balance(3, 'Chen', -42050),
            ]),
          ),
        ),
      );
    }

    testWidgets('asks for confirmation before recording', (tester) async {
      await pumpSettle(tester);

      final record = find.widgetWithText(FilledButton, 'Select payments to record');
      expect(tester.widget<FilledButton>(record).onPressed, isNull);

      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.text('Record 2 payments · ₹420.50'));
      await tester.pumpAndSettle();

      expect(find.text('Record 2 payments?'), findsOneWidget);
      expect(find.text('Chen → Asha'), findsOneWidget);
      expect(find.text('Chen → Ben'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Cancelling leaves the page, and the selection, exactly as it was.
      expect(find.text('Record 2 payments?'), findsNothing);
      expect(find.text('Record 2 payments · ₹420.50'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('does not ask to confirm a write that cannot go out',
        (tester) async {
      await pumpSettle(tester, reachable: false);

      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.textContaining('Record 2 payments'));
      await tester.pumpAndSettle();

      expect(find.text('Record 2 payments?'), findsNothing);
      expect(find.textContaining("Can't reach Split"), findsOneWidget);
    });
  });
}
