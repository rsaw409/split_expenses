import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/views/create_group_view.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GroupsController(),
        child: const MaterialApp(home: CreateGroupView()),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> addPerson(WidgetTester tester, String name) async {
    await tester.enterText(field('Add a person'), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('requires a name and enough people before sending anything',
      (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Create group'));
    await tester.pump();

    expect(find.text('Give the group a name.'), findsOneWidget);
    expect(
      find.text('Add at least $minimumPeople people to split with.'),
      findsOneWidget,
    );
    // Validation failed, so no request went out and nothing is saving.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('adds people as chips, skipping case-insensitive duplicates',
      (tester) async {
    await pumpForm(tester);

    await addPerson(tester, 'Asha');
    await addPerson(tester, 'Ben');
    await addPerson(tester, 'asha');

    expect(find.widgetWithText(InputChip, 'Asha'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Ben'), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('asha is already in the list.'), findsOneWidget);
  });

  testWidgets('a chip can be removed before the group is created',
      (tester) async {
    await pumpForm(tester);

    await addPerson(tester, 'Asha');
    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();

    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('currency is fixed to rupees for now', (tester) async {
    await pumpForm(tester);

    expect(find.text('Indian Rupee (₹)'), findsOneWidget);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);
  });
}
