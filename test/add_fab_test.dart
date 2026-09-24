import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/components/floating_action_button.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GroupsController(),
        child: MaterialApp(
          theme: ThemeData(
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hello')),
                ),
                child: const Text('snack'),
              ),
            ),
            floatingActionButton: const ExpandableFloatingActionButton(),
          ),
        ),
      ),
    );
  }

  testWidgets('the + button opens and closes the add menu', (tester) async {
    await pumpHome(tester);
    expect(find.text('New expense'), findsNothing);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New expense'), findsOneWidget);
    expect(find.text('New payment'), findsOneWidget);
    expect(find.text('New person'), findsOneWidget);

    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();
    expect(find.text('New expense'), findsNothing);
  });

  testWidgets('tapping outside the menu closes it', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(40, 200));
    await tester.pumpAndSettle();
    expect(find.text('New expense'), findsNothing);
  });

  testWidgets('a floating snackbar sits on screen, above the + button',
      (tester) async {
    // The old flutter_expandable_fab laid the closed FAB out full-screen, so
    // Scaffold put floating snackbars above the top of the screen.
    await pumpHome(tester);
    await tester.tap(find.text('snack'));
    await tester.pumpAndSettle();

    final snackBar = tester.getRect(find.byType(SnackBar));
    final fab = tester.getRect(find.byTooltip('Add'));
    expect(snackBar.top, greaterThanOrEqualTo(0));
    expect(snackBar.bottom, lessThanOrEqualTo(fab.top));
  });
}
