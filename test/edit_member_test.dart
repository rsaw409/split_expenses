import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/components/member_avatar.dart';
import 'package:split_expense/src/models/expense/expense.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/notify_controllers/allexpense_controller.dart';
import 'package:split_expense/src/notify_controllers/backend_reachability.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';
import 'package:split_expense/src/views/edit_member_view.dart';
import 'package:split_expense/src/views/user_view.dart';

UserBalance member(int id, String name, {String? avatar}) => UserBalance(
      name: name,
      userId: id,
      avatar: avatar,
      balances: 0,
      numberOfTransactions: 0,
      numberOfBenefits: 0,
      numberOfPayments: 0,
    );

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

class _Expenses extends AllExpenseController {
  _Expenses() : super(1);

  @override
  Future<List<Expense>> fetchFromNetwork(int id) async => const [];

  @override
  Future<List<Expense>?> readFromCache(int id) async => null;

  @override
  Future<void> writeToCache(int id, List<Expense> items) async {}
}

/// Goa Trip selected, without loading anything (loadGroups would go to the
/// network).
class _Groups extends GroupsController {
  @override
  Map<String, dynamic> get selectedGroup =>
      const Group(id: 1, name: 'Goa Trip', inviteId: 'x').toMap();
}

/// Unreachable, so a form that gets past validation says so instead of
/// sending a request: its snackbar is how these tests see that it would have.
class _Unreachable extends ChangeNotifier implements BackendReachability {
  @override
  bool get isReachable => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const cantReach = "Can't reach Split — check your connection and try again.";

void main() {
  final asha = member(1, 'Asha', avatar: 'seedAsha1');
  final ben = member(2, 'Ben', avatar: 'seedBen22');
  final carol = member(3, 'Carol');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<UserBalance>? members,
  }) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GroupsController>(create: (_) => _Groups()),
          ChangeNotifierProvider<AllExpenseController>(
            create: (_) => _Expenses(),
          ),
          // Loaded up front, as it is when the overview opens a member.
          ChangeNotifierProvider<UserBalanceController>(
            lazy: false,
            create: (_) => _Balances(members ?? [asha, ben, carol]),
          ),
          ChangeNotifierProvider<BackendReachability>(
            create: (_) => _Unreachable(),
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pump();
  }

  Finder saveButton() => find.widgetWithText(TextButton, 'Save');
  bool canSave(WidgetTester tester) =>
      tester.widget<TextButton>(saveButton()).onPressed != null;
  String seedShown(WidgetTester tester) =>
      tester.widget<SeedAvatar>(find.byType(SeedAvatar)).seed;

  group('EditMemberView', () {
    testWidgets('starts with the name and avatar the member has',
        (tester) async {
      await pump(tester, EditMemberView(member: asha));

      expect(find.widgetWithText(TextFormField, 'Asha'), findsOneWidget);
      expect(seedShown(tester), 'seedAsha1');
    });

    testWidgets('Save is enabled only once something has changed',
        (tester) async {
      await pump(tester, EditMemberView(member: asha));
      expect(canSave(tester), isFalse);

      await tester.enterText(find.byType(TextFormField), 'Asha Rao');
      await tester.pump();
      expect(canSave(tester), isTrue);

      // Back to the original, give or take spaces: nothing to save.
      await tester.enterText(find.byType(TextFormField), ' Asha  ');
      await tester.pump();
      expect(canSave(tester), isFalse);

      await tester.tap(find.text('Change avatar'));
      await tester.pump();
      expect(seedShown(tester), isNot('seedAsha1'));
      expect(canSave(tester), isTrue);
    });

    testWidgets('a member without an avatar keeps their initials until given one',
        (tester) async {
      await pump(tester, EditMemberView(member: carol));

      expect(find.text('C'), findsOneWidget);
      expect(find.byType(SeedAvatar), findsNothing);
      expect(canSave(tester), isFalse);

      await tester.tap(find.text('Change avatar'));
      await tester.pump();

      expect(find.byType(SeedAvatar), findsOneWidget);
      expect(canSave(tester), isTrue);
    });

    testWidgets('a blank name is refused before any request', (tester) async {
      await pump(tester, EditMemberView(member: asha));

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pump();

      expect(find.text('This field cannot be empty.'), findsOneWidget);
      expect(find.text(cantReach), findsNothing);
    });

    testWidgets("another member's name, in any case, is refused before any "
        'request', (tester) async {
      await pump(tester, EditMemberView(member: asha));

      await tester.enterText(find.byType(TextFormField), ' bEN ');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pump();

      expect(find.text('Someone in this group already has this name.'),
          findsOneWidget);
      expect(find.text(cantReach), findsNothing);
    });

    testWidgets('changing the case of their own name is allowed',
        (tester) async {
      await pump(tester, EditMemberView(member: asha));

      await tester.enterText(find.byType(TextFormField), 'ASHA');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pump();

      expect(find.text('Someone in this group already has this name.'),
          findsNothing);
      expect(find.text(cantReach), findsOneWidget);
    });
  });

  group('UserView', () {
    testWidgets('Edit opens the form filled in with the member',
        (tester) async {
      await pump(tester, UserView(userBalance: asha));

      await tester.tap(find.byTooltip('Edit person'));
      await tester.pumpAndSettle();

      expect(find.byType(EditMemberView), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Asha'), findsOneWidget);
      expect(seedShown(tester), 'seedAsha1');
    });

    testWidgets('shows what the overview now says, not the page it was '
        'opened with', (tester) async {
      final renamed = member(1, 'Asha Rao', avatar: 'seedNew99');
      await pump(tester, UserView(userBalance: asha), members: [renamed, ben]);

      expect(find.text('Asha'), findsNothing);
      expect(find.text('Asha Rao'), findsNWidgets(2)); // app bar and tile
      expect(seedShown(tester), 'seedNew99');
    });
  });
}
