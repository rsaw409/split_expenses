import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/components/group_icon.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/notify_controllers/allexpense_controller.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/utils/group_icon.dart';
import 'package:split_expense/src/views/create_group_view.dart';
import 'package:split_expense/src/views/edit_group_view.dart';

import 'edit_group_test.dart' show FakeExpenses;

// Shape taken from the live getGroups response.
Map<String, dynamic> _groupJson({String? icon, String? color}) => {
      'id': 126,
      'name': 'avatar-api-test',
      'inviteId': 'w6MA',
      'currency': 'INR',
      'currency_decimals': 2,
      'icon': icon,
      'icon_color': color,
    };

void main() {
  group('Group.icon', () {
    test('reads an icon and writes it back', () {
      final group = Group.fromMap(_groupJson(icon: '🍕', color: 'orange'));
      expect(group.icon, (emoji: '🍕', color: 'orange'));
      expect(Group.fromMap(group.toMap()), group);
    });

    test('is null for a group without one, and adds no keys when saved', () {
      final group = Group.fromMap(_groupJson());
      expect(group.icon, isNull);
      // A group saved before icons existed must still compare equal to the
      // same group fetched now, or every launch rewrites it.
      expect(group.toMap().containsKey('icon'), isFalse);
      expect(group.toMap().containsKey('icon_color'), isFalse);
    });

    test('needs both fields, as the backend only stores them together', () {
      expect(Group.fromMap(_groupJson(icon: '🍕')).icon, isNull);
      expect(Group.fromMap(_groupJson(color: 'orange')).icon, isNull);
    });
  });

  group('catalogue', () {
    test('every emoji and colour fits what the backend accepts', () {
      for (final emoji in groupIconEmoji) {
        expect(emoji.trim(), isNotEmpty);
        expect(utf8.encode(emoji).length, lessThanOrEqualTo(32), reason: emoji);
      }
      for (final color in groupIconColors) {
        expect(color.key.length, lessThanOrEqualTo(20));
      }
      expect(groupIconEmoji.toSet(), hasLength(groupIconEmoji.length));
      expect(groupIconColors.map((c) => c.key).toSet(),
          hasLength(groupIconColors.length));
    });

    test('an unknown colour falls back instead of failing', () {
      expect(groupIconColorFor('ultraviolet'), groupIconColors.first);
      expect(groupIconColorFor('teal').key, 'teal');
    });
  });

  testWidgets('a group without an icon keeps its initials', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          GroupIconAvatar(name: 'Goa Trip'),
          GroupIconAvatar(name: 'Flat', icon: (emoji: '🏠', color: 'teal')),
        ]),
      ),
    ));

    expect(find.text('GT'), findsOneWidget);
    expect(find.text('🏠'), findsOneWidget);
    expect(find.text('F'), findsNothing);
  });

  group('forms', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> pickIcon(WidgetTester tester, String emoji) async {
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(emoji).last);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
    }

    testWidgets('a new group starts with an icon that can be changed',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => GroupsController(),
        child: const MaterialApp(home: CreateGroupView()),
      ));

      expect(find.text('Change icon'), findsOneWidget);
      final before =
          tester.widget<GroupIconAvatar>(find.byType(GroupIconAvatar)).icon!;
      final other = groupIconEmoji.firstWhere((e) => e != before.emoji);

      await pickIcon(tester, other);

      final after =
          tester.widget<GroupIconAvatar>(find.byType(GroupIconAvatar)).icon!;
      expect(after.emoji, other);
      expect(after.color, before.color);
    });

    testWidgets('an icon is a change the edit form can save', (tester) async {
      bigScreen(tester);
      const goa = Group(id: 1, name: 'Goa Trip', inviteId: 'x');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GroupsController()),
          ChangeNotifierProvider<AllExpenseController>(
              create: (_) => FakeExpenses(goa.id)),
        ],
        child: const MaterialApp(home: EditGroupView(group: goa)),
      ));
      await tester.pump();

      FilledButton save() =>
          tester.widget(find.widgetWithText(FilledButton, 'Save changes'));

      // No icon yet: initials, an "Add icon" button, nothing to save.
      expect(find.text('GT'), findsOneWidget);
      expect(find.text('Add icon'), findsOneWidget);
      expect(save().onPressed, isNull);

      await pickIcon(tester, '✈️');

      expect(find.text('✈️'), findsOneWidget);
      expect(save().onPressed, isNotNull);

      // Cancel keeps the icon picked before, even after trying another.
      await tester.tap(find.text('Change icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🏠').last);
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('✈️'), findsOneWidget);
      expect(find.text('🏠'), findsNothing);
    });
  });
}
