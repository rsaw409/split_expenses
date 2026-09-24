import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/components/drawer.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/notify_controllers/settings_controller.dart';

void main() {
  final groups = [
    for (var i = 0; i < 30; i++) {'id': i, 'name': 'Group $i'},
  ];

  late SettingsController settings;

  Future<void> pumpDrawer(WidgetTester tester, {required int selected}) async {
    // A typical phone viewport.
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode(groups),
      'selectedGroup': jsonEncode(groups[selected]),
    });
    settings = SettingsController();
    final groupsController = GroupsController();
    await groupsController.loadGroups();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: groupsController),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(
          home: Scaffold(drawer: MyDrawer()),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
  }

  bool isHittable(WidgetTester tester, Finder finder) {
    final center = tester.getCenter(finder);
    final result = HitTestResult();
    tester.binding.hitTestInView(result, center, tester.view.viewId);
    final target = tester.renderObject(finder);
    return result.path.any((entry) => entry.target == target);
  }

  testWidgets('pins the selected group above the scrollable list',
      (tester) async {
    await pumpDrawer(tester, selected: 29);

    expect(find.text('CURRENT GROUP'), findsOneWidget);
    expect(find.text('Group 29'), findsOneWidget);
    expect(isHittable(tester, find.text('Group 29')), isTrue);

    // Scrolling the other groups does not move the pinned tile.
    final before = tester.getTopLeft(find.text('Group 29'));
    await tester.drag(find.text('Group 3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Group 29')), before);
  });

  testWidgets('the last group scrolls fully clear of the footer',
      (tester) async {
    await pumpDrawer(tester, selected: 0);

    await tester.scrollUntilVisible(
      find.text('Group 29'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final tileBottom = tester.getBottomLeft(find.text('Group 29')).dy;
    final footerTop = tester.getTopLeft(find.text('Join group')).dy;
    expect(tileBottom, lessThan(footerTop));
    expect(isHittable(tester, find.text('Group 29')), isTrue);
  });

  testWidgets('theme is chosen from a dialog and shown on its row',
      (tester) async {
    await pumpDrawer(tester, selected: 0);

    expect(find.text('System default'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Dark'), findsOneWidget);
  });
}
