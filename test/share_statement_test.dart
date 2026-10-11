import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/notify_controllers/allexpense_controller.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';
import 'package:split_expense/src/views/user_view.dart';

import 'statement_test.dart' show groupExpenses;

class _Expenses extends AllExpenseController {
  _Expenses({this.list = const [], this.pending = false}) : super(1);

  final List<Expense> list;
  final bool pending;

  @override
  Future<List<Expense>> fetchFromNetwork(int id) async {
    if (pending) return Completer<List<Expense>>().future;
    return list;
  }

  @override
  Future<List<Expense>?> readFromCache(int id) async => null;

  @override
  Future<void> writeToCache(int id, List<Expense> items) async {}
}

class _Balances extends UserBalanceController {
  _Balances(this.list) : super(1);

  final List<UserBalance> list;

  @override
  Future<List<UserBalance>> fetchFromNetwork(int id) async => list;

  @override
  Future<List<UserBalance>?> readFromCache(int id) async => null;

  @override
  Future<void> writeToCache(int id, List<UserBalance> items) async {}
}

/// Goa Trip selected, without loading anything (loadGroups would go to the
/// network).
class _Groups extends GroupsController {
  @override
  Map<String, dynamic> get selectedGroup =>
      const Group(id: 1, name: 'Goa Trip', inviteId: 'x').toMap();
}

UserBalance asha(int balance) => UserBalance(
      name: 'Asha',
      userId: 1,
      balances: balance,
      numberOfTransactions: 3,
      numberOfBenefits: 3,
      numberOfPayments: 0,
    );

const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late List<Map<Object?, Object?>> shared;
  late Directory temp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shared = [];
    temp = Directory.systemTemp.createTempSync('statement_test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'com.whatsapp';
    });
    messenger.setMockMethodCallHandler(pathChannel, (call) async => temp.path);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, null);
    messenger.setMockMethodCallHandler(pathChannel, null);
    temp.deleteSync(recursive: true);
  });

  Future<void> pumpUserView(
    WidgetTester tester, {
    AllExpenseController? expenses,
    int serverBalance = 8975,
  }) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GroupsController>(create: (_) => _Groups()),
          ChangeNotifierProvider<AllExpenseController>(
            create: (_) => expenses ?? _Expenses(list: groupExpenses),
          ),
          ChangeNotifierProvider<UserBalanceController>(
            create: (_) => _Balances([asha(serverBalance)]),
          ),
        ],
        child: MaterialApp(home: UserView(userBalance: asha(serverBalance))),
      ),
    );
    await tester.pump();
  }

  Finder shareButton() => find.widgetWithText(FilledButton, 'Share statement');
  Finder shareIcon() => find.byTooltip('Share statement');

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(shareButton());
    await tester.pumpAndSettle();
  }

  testWidgets('waits for the transactions to load', (tester) async {
    await pumpUserView(tester, expenses: _Expenses(pending: true));

    expect(tester.widget<FilledButton>(shareButton()).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
              find.ancestor(of: shareIcon(), matching: find.byType(IconButton)))
          .onPressed,
      isNull,
    );
  });

  testWidgets('shares the statement as text', (tester) async {
    await pumpUserView(tester);
    await openSheet(tester);

    expect(find.text("Asha's balance and all 4 transactions in Goa Trip."),
        findsOneWidget);
    expect(find.text('This may not include the latest transactions.'),
        findsNothing);

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single['text'],
        startsWith('*Split statement: Asha*\nGoa Trip · '));
    expect(shared.single['subject'], 'Split statement: Asha (Goa Trip)');
    // Anchored to the button, which iPad requires.
    expect(shared.single['originWidth'] as double, greaterThan(0));

    expect(find.text('Share statement'), findsOneWidget); // the sheet closed
    expect(find.text("Asha's statement shared."), findsOneWidget);
  });

  testWidgets('shares the statement as a PDF file', (tester) async {
    await pumpUserView(tester);
    await openSheet(tester);

    // PDF is the default. Building it and writing the file are real work.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Share'));
      for (var i = 0; i < 200 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single['mimeTypes'], ['application/pdf']);
    final path = (shared.single['paths'] as List).single as String;
    expect(
        path,
        matches(RegExp(r'/Split statement - Asha - Goa Trip - '
            r'\d{4}-\d{2}-\d{2}\.pdf$')));
    expect(String.fromCharCodes(File(path).readAsBytesSync().take(5)), '%PDF-');
    expect(find.text("Asha's statement shared."), findsOneWidget);
  });

  testWidgets('warns when the balances disagree with the transactions',
      (tester) async {
    // The overview says Asha gets back more than her transactions add up to:
    // one of the two lists is behind.
    await pumpUserView(tester, serverBalance: 12000);
    await openSheet(tester);

    expect(find.text('This may not include the latest transactions.'),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Refresh'), findsOneWidget);
  });
}
