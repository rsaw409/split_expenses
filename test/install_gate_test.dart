import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/services/api_exception.dart';
import 'package:split_expense/src/services/push_registration.dart';
import 'package:split_expense/src/utils/install_method.dart';
import 'package:split_expense/src/utils/invite_link.dart';
import 'package:split_expense/src/views/install_gate_view.dart';

/// OneSignal and the backend have no implementation in tests.
class FakePushRegistration implements PushRegistration {
  @override
  Future<String?> subscriptionId() async => null;
  @override
  void Function() onSubscriptionChanged(void Function() onChanged) => () {};
  @override
  Future<void> register(String subscriptionId, List<int> groupIds) async {}
  @override
  Future<void> removeGroupTags() async {}
}

void main() {
  late GroupsController groups;
  late ValueNotifier<bool> promptAvailable;
  late List<Uri> opened;
  late List<String> joins;
  late int prompts;
  late bool accept;
  late Object? joinError;
  String? copied;

  setUp(() {
    promptAvailable = ValueNotifier(false);
    opened = [];
    joins = [];
    prompts = 0;
    accept = true;
    joinError = null;
    copied = null;
  });

  Future<void> pumpGate(
    WidgetTester tester,
    InstallMethod method, {
    String? inviteId,
    Map<String, Object> saved = const {},
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    SharedPreferences.setMockInitialValues(saved);
    groups = GroupsController(
      push: FakePushRegistration(),
      fetchGroups: (_) async => [],
    );
    await groups.loadGroups();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: groups,
        child: MaterialApp(
          home: InstallGateView(
            method: method,
            inviteId: inviteId,
            promptAvailable: promptAvailable,
            promptInstall: () async {
              prompts++;
              promptAvailable.value = false;
              return accept;
            },
            openUrl: (url) async => opened.add(url),
            joinGroup: (id) async {
              joins.add(id);
              if (joinError != null) throw joinError!;
              return Group(
                name: 'Goa trip',
                id: 7,
                inviteId: id,
                currency: 'INR',
                currencyDecimals: 2,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('there is no way past it', (tester) async {
    for (final method in InstallMethod.values) {
      await pumpGate(tester, method);
      expect(find.text('Install Split'), findsOneWidget);
      for (final dismiss in ['NOT NOW', 'OK', 'LATER', 'CONTINUE']) {
        expect(find.text(dismiss), findsNothing, reason: '$method: $dismiss');
      }
    }
  });

  group('iPhone', () {
    testWidgets('explains Add to Home Screen', (tester) async {
      await pumpGate(tester, InstallMethod.iosHomeScreen);
      expect(find.text('Tap Add to Home Screen.'), findsOneWidget);
      expect(find.text('COPY INVITE'), findsNothing);
    });

    testWidgets("copies the link's invite rather than joining in Safari",
        (tester) async {
      await pumpGate(tester, InstallMethod.iosHomeScreen, inviteId: 'a/b+c=');

      // The Home Screen app wouldn't see a group joined here.
      expect(joins, isEmpty);
      await tester.tap(find.text('COPY INVITE'));
      await tester.pumpAndSettle();
      expect(copied, inviteLink('a/b+c=').toString());
      expect(find.text('COPIED'), findsOneWidget);
    });

    testWidgets('offers the group this browser already had', (tester) async {
      await pumpGate(tester, InstallMethod.iosHomeScreen, saved: {
        'groups': jsonEncode([
          {'id': 3, 'name': 'Flat', 'inviteId': 'flat-invite'},
        ]),
        'selectedGroupId': 3,
      });

      await tester.tap(find.text('COPY INVITE'));
      await tester.pumpAndSettle();
      expect(copied, inviteLink('flat-invite').toString());
    });
  });

  testWidgets('Mac Safari: Add to Dock, and the invite to copy',
      (tester) async {
    await pumpGate(tester, InstallMethod.macSafari, inviteId: 'mac');
    expect(find.text('Choose Add to Dock.'), findsOneWidget);
    expect(find.text('COPY INVITE'), findsOneWidget);
    expect(joins, isEmpty);
  });

  group('Android', () {
    testWidgets("joins the link's group for the web app, which shares storage",
        (tester) async {
      await pumpGate(tester, InstallMethod.android, inviteId: 'a/b+c=');

      expect(joins, ['a/b+c=']);
      expect(groups.selectedGroup['id'], 7);
      expect(find.textContaining("You've joined Goa trip"), findsOneWidget);
    });

    testWidgets('Google Play carries the invite into the Android app',
        (tester) async {
      await pumpGate(tester, InstallMethod.android, inviteId: 'a/b+c=');
      await tester.tap(find.text('Get the Android app'));
      expect(opened, [playStoreLink(inviteId: 'a/b+c=')]);
    });

    testWidgets('installs the web app once the browser allows it',
        (tester) async {
      await pumpGate(tester, InstallMethod.android);
      expect(find.textContaining('In the browser menu'), findsOneWidget);
      await tester.tap(find.text('Install the web app'));
      expect(prompts, 0);

      promptAvailable.value = true;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install the web app'));
      await tester.pumpAndSettle();

      expect(prompts, 1);
      expect(find.text('Web app installed'), findsOneWidget);
      // Still no way into the app from the tab.
      expect(find.text('Install Split'), findsOneWidget);
    });

    testWidgets('says so when the invite fails', (tester) async {
      joinError = ApiException('Invalid or expired invite code.');
      await pumpGate(tester, InstallMethod.android, inviteId: 'bad');
      expect(find.text('Invalid or expired invite code.'), findsOneWidget);
    });
  });

  group('computer', () {
    testWidgets('INSTALL when the browser allows it, else its menu',
        (tester) async {
      await pumpGate(tester, InstallMethod.desktop, inviteId: 'desk');
      expect(joins, ['desk']);
      expect(find.text('INSTALL'), findsNothing);
      expect(find.textContaining('install button in the address bar'),
          findsOneWidget);

      promptAvailable.value = true;
      await tester.pumpAndSettle();
      accept = false;
      await tester.tap(find.text('INSTALL'));
      await tester.pumpAndSettle();
      expect(prompts, 1);
      expect(find.textContaining('install button in the address bar'),
          findsOneWidget);
    });

    testWidgets('confirms once installed', (tester) async {
      promptAvailable.value = true;
      await pumpGate(tester, InstallMethod.desktop);
      await tester.tap(find.text('INSTALL'));
      await tester.pumpAndSettle();
      expect(find.text('Split is installed. Open it from your apps.'),
          findsOneWidget);
    });
  });

  testWidgets("where installing is impossible, points to another browser",
      (tester) async {
    await pumpGate(tester, InstallMethod.none, inviteId: 'ff');
    expect(find.textContaining("this browser can't install it"),
        findsOneWidget);
    expect(joins, isEmpty);

    await tester.tap(find.text('COPY LINK'));
    await tester.pumpAndSettle();
    expect(copied, inviteLink('ff').toString());
  });

  testWidgets('without an invite, copies the app\'s address', (tester) async {
    await pumpGate(tester, InstallMethod.none);
    await tester.tap(find.text('COPY LINK'));
    await tester.pumpAndSettle();
    expect(copied, 'https://$inviteLinkHost/');
  });
}
