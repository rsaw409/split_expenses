import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/components/member_avatar.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/utils/avatar.dart';
import 'package:split_expense/src/utils/members.dart';
import 'package:split_expense/src/views/create_group_view.dart';
import 'package:split_expense/src/views/new_form.dart';

Map<String, dynamic> _row({String? avatar, bool withKey = true}) => {
      'name': 'Carol',
      'user_id': 230,
      if (withKey) 'avatar': avatar,
      'balances': 0,
      'number_of_transactions': 0,
      'number_of_payments': 0,
      'number_of_benefits': 0,
    };

String _seedOf(WidgetTester tester, Finder finder) =>
    tester.widget<SeedAvatar>(finder).seed;

void main() {
  group('UserBalance.avatar', () {
    // Shape taken from the live getOverviewDataInGroup response.
    test('reads a saved avatar', () {
      final balance = UserBalance.fromMap(_row(avatar: 'seedCarol9'));
      expect(balance.avatar, 'seedCarol9');
      expect(UserBalance.fromMap(balance.toMap()), balance);
    });

    test('reads null for members added before avatars existed', () {
      expect(UserBalance.fromMap(_row(avatar: null)).avatar, isNull);
    });

    test('reads a cache entry written before the field existed', () {
      expect(UserBalance.fromMap(_row(withKey: false)).avatar, isNull);
    });

    test('is carried into the member pickers', () {
      final members =
          membersFromBalances([UserBalance.fromMap(_row(avatar: 'seedCarol9'))]);
      expect(members.single.avatar, 'seedCarol9');
    });
  });

  group('avatar seeds', () {
    test('new seeds fit what the backend accepts and differ each time', () {
      final seeds = List.generate(50, (_) => newAvatarSeed());
      for (final seed in seeds) {
        expect(seed.trim(), isNotEmpty);
        expect(seed.length, lessThanOrEqualTo(64));
      }
      expect(seeds.toSet(), hasLength(seeds.length));
    });
  });

  testWidgets('a member without an avatar keeps their initials',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          MemberAvatar(name: 'Bob Stone'),
          MemberAvatar(name: 'Carol Doe', avatar: 'seedCarol9'),
        ]),
      ),
    ));

    expect(find.text('BS'), findsOneWidget);
    expect(find.text('CD'), findsNothing);
    expect(find.byType(SeedAvatar), findsOneWidget);
  });

  testWidgets('the add-person form shuffles the avatar it will save',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NewForm(saveButtonText: 'Save person', textFieldLabel: 'Name'),
    ));

    final avatar = find.byType(SeedAvatar);
    final before = _seedOf(tester, avatar);
    await tester.tap(find.text('Change avatar'));
    await tester.pump();

    expect(_seedOf(tester, avatar), isNot(before));
  });

  testWidgets('tapping a person in a new group shuffles only their avatar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => GroupsController(),
      child: const MaterialApp(home: CreateGroupView()),
    ));

    for (final name in ['Asha', 'Ben']) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Add a person'), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    Finder avatarOf(String name) => find.descendant(
          of: find.widgetWithText(InputChip, name),
          matching: find.byType(SeedAvatar),
        );
    final asha = _seedOf(tester, avatarOf('Asha'));
    final ben = _seedOf(tester, avatarOf('Ben'));

    await tester.tap(find.text('Asha'));
    await tester.pump();

    expect(_seedOf(tester, avatarOf('Asha')), isNot(asha));
    expect(_seedOf(tester, avatarOf('Ben')), ben);
  });
}
