import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/views/edit_group_view.dart';

void main() {
  const goa = Group(id: 1, name: 'Goa Trip', inviteId: 'x', currency: 'INR');

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GroupsController(),
        child: const MaterialApp(home: EditGroupView(group: goa)),
      ),
    );
  }

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
}
