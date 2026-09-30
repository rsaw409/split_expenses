import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/components/drawer.dart';
import 'package:split_expense/src/services/push.dart';

void main() {
  Future<void> pumpAction(
    WidgetTester tester, {
    required Future<PushPermission> Function() permission,
    Future<void> Function()? requestPermission,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsAction(
            permission: permission,
            requestPermission: requestPermission ?? () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('turns notifications on from a tap, then hides', (tester) async {
    var current = PushPermission.canRequest;
    var requests = 0;
    await pumpAction(
      tester,
      permission: () async => current,
      requestPermission: () async {
        requests++;
        current = PushPermission.granted;
      },
    );

    expect(find.text('Turn on notifications'), findsOneWidget);
    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('a dismissed prompt keeps offering', (tester) async {
    await pumpAction(tester, permission: () async => PushPermission.canRequest);

    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on notifications'), findsOneWidget);
  });

  testWidgets('explains how to unblock, without asking again',
      (tester) async {
    var requests = 0;
    await pumpAction(
      tester,
      permission: () async => PushPermission.denied,
      requestPermission: () async => requests++,
    );

    await tester.tap(find.text('Notifications blocked'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications are blocked'), findsOneWidget);
    expect(find.textContaining('site settings'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('in an iPhone browser tab, explains the Home Screen',
      (tester) async {
    var requests = 0;
    await pumpAction(
      tester,
      permission: () async => PushPermission.needsHomeScreen,
      requestPermission: () async => requests++,
    );

    await tester.tap(find.text('Get notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Add Split to your Home Screen'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('shows nothing where there is nothing to offer',
      (tester) async {
    for (final permission in [
      PushPermission.unavailable,
      PushPermission.granted,
    ]) {
      await pumpAction(tester, permission: () async => permission);
      expect(find.byType(ListTile), findsNothing, reason: '$permission');
    }
  });

  test('the native apps ask at launch, so offer nothing', () async {
    expect(await pushPermission(), PushPermission.unavailable);
  });
}
