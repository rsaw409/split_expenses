import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/components/drawer.dart';
import 'package:split_expense/src/components/notifications_prompt.dart';
import 'package:split_expense/src/services/push.dart';
import 'package:split_expense/src/utils/install_method.dart';

void main() {
  group('startup prompt', startupPromptTests);
  group('drawer row', drawerRowTests);

  group('unblocking steps', blockedHelpTests);

  test('the native apps ask at launch, so offer nothing', () async {
    expect(await pushPermission(), PushPermission.unavailable);
  });
}

void startupPromptTests() {
  final home = GlobalKey();
  var requests = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = 0;
  });

  Future<void> launch(WidgetTester tester, PushPermission permission) async {
    await askForNotificationsOnce(
      home.currentContext!,
      permission: () async => permission,
      requestPermission: () async => requests++,
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(key: home)));
  }

  testWidgets('asks once, and TURN ON prompts the browser', (tester) async {
    await pumpHome(tester);
    await launch(tester, PushPermission.canRequest);

    expect(find.text('Turn on notifications?'), findsOneWidget);
    await tester.tap(find.text('TURN ON'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(AlertDialog), findsNothing);

    // Dismissing the browser's prompt leaves it askable; the drawer covers
    // that, not another startup prompt.
    await launch(tester, PushPermission.canRequest);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('NOT NOW leaves the browser alone and is not asked again',
      (tester) async {
    await pumpHome(tester);
    await launch(tester, PushPermission.canRequest);

    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(requests, 0);

    await launch(tester, PushPermission.canRequest);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('says nothing with nothing to ask, and keeps its one ask',
      (tester) async {
    await pumpHome(tester);
    for (final permission in [
      PushPermission.unavailable,
      PushPermission.granted,
      PushPermission.denied,
    ]) {
      await launch(tester, permission);
      expect(find.byType(AlertDialog), findsNothing, reason: '$permission');
    }

    await launch(tester, PushPermission.canRequest);
    expect(find.text('Turn on notifications?'), findsOneWidget);
  });

  testWidgets('does not cover a screen opened meanwhile', (tester) async {
    await pumpHome(tester);
    Navigator.of(home.currentContext!).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('A form')),
    ));
    await tester.pumpAndSettle();

    await launch(tester, PushPermission.canRequest);
    expect(find.byType(AlertDialog), findsNothing);

    Navigator.of(home.currentContext!).pop();
    await tester.pumpAndSettle();
    await launch(tester, PushPermission.canRequest);
    expect(find.text('Turn on notifications?'), findsOneWidget);
  });
}

void drawerRowTests() {
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
    expect(find.textContaining('reopen Split'), findsOneWidget);
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
}

void blockedHelpTests() {
  final home = GlobalKey();

  Future<void> explain(WidgetTester tester, InstallMethod method) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(key: home)));
    showBlockedHelp(home.currentContext!, method: method);
    await tester.pumpAndSettle();
  }

  // Notifications only exist in the installed app, whose setting usually
  // lives outside the browser.
  const steps = {
    InstallMethod.iosHomeScreen: 'tap Notifications, then Split',
    InstallMethod.android: 'tap App info, then Notifications',
    InstallMethod.desktop: "In Split's window",
    InstallMethod.macSafari: 'Open System Settings',
    InstallMethod.none: 'device or browser settings',
  };
  for (final MapEntry(key: method, value: step) in steps.entries) {
    testWidgets('points to where ${method.name} keeps the setting',
        (tester) async {
      await explain(tester, method);
      expect(find.textContaining(step), findsOneWidget);
      expect(find.textContaining('reopen Split'), findsOneWidget);
    });
  }
}
