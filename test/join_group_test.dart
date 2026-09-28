import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/utils/invite_link.dart';
import 'package:split_expense/src/views/join_group_view.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GroupsController(),
        child: const MaterialApp(home: JoinGroupView()),
      ),
    );
  }

  testWidgets('asks for a code before sending anything', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Join group'));
    await tester.pump();

    expect(find.text('Enter an invite link or code.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('pastes the clipboard into the field', (tester) async {
    final link = inviteLink('abc/def==').toString();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': '  $link  '}
          : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpForm(tester);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();

    expect(find.text(link), findsOneWidget);
    expect(find.text('Enter an invite link or code.'), findsNothing);
  });
}
