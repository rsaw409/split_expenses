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
  late int attempts;
  late bool failShare;
  late Directory temp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shared = [];
    attempts = 0;
    failShare = false;
    temp = Directory.systemTemp.createTempSync('statement_test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      attempts++;
      if (failShare) throw PlatformException(code: 'error');
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

  /// Taps Share statement and waits for the share call: building the PDF and
  /// writing its file are real work, which fake async would never finish.
  Future<void> tapShare(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(shareButton());
      for (var i = 0; i < 200 && attempts == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('offers one Share statement button, once transactions load',
      (tester) async {
    await pumpUserView(tester, expenses: _Expenses(pending: true));

    expect(shareButton(), findsOneWidget);
    expect(tester.widget<FilledButton>(shareButton()).onPressed, isNull);
    // No second way in from the app bar.
    expect(find.byTooltip('Share statement'), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('goes straight to the share sheet with the PDF', (tester) async {
    await pumpUserView(tester);
    await tapShare(tester);

    expect(shared, hasLength(1));
    expect(shared.single['mimeTypes'], ['application/pdf']);
    expect(shared.single['subject'], 'Split statement: Asha (Goa Trip)');
    // Anchored to the button, which iPad requires.
    expect(shared.single['originWidth'] as double, greaterThan(0));
    final path = (shared.single['paths'] as List).single as String;
    expect(
        path,
        matches(RegExp(r'/Split statement - Asha - Goa Trip - '
            r'\d{4}-\d{2}-\d{2}\.pdf$')));
    expect(String.fromCharCodes(File(path).readAsBytesSync().take(5)), '%PDF-');
    expect(find.text("Asha's statement shared."), findsOneWidget);
  });

  testWidgets('says so when the share sheet fails to open', (tester) async {
    failShare = true;
    await pumpUserView(tester);
    await tapShare(tester);

    expect(shared, isEmpty);
    expect(
        find.text("Couldn't create the statement. Try again."), findsOneWidget);
    // Ready to try again.
    expect(tester.widget<FilledButton>(shareButton()).onPressed, isNotNull);
  });
}
