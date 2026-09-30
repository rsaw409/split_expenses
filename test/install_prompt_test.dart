import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/components/install_prompt.dart';
import 'package:split_expense/src/utils/install_method.dart';
import 'package:split_expense/src/utils/invite_link.dart';

void main() {
  final home = GlobalKey();
  late ValueNotifier<bool> promptAvailable;
  late List<Uri> opened;
  late int prompts;
  late bool accept;

  setUp(() {
    promptAvailable = ValueNotifier(false);
    opened = [];
    prompts = 0;
    accept = true;
  });

  Future<void> pumpHome(WidgetTester tester) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(key: home)));

  Future<bool> launch(WidgetTester tester, InstallMethod method) async {
    final asked = askToInstall(
      home.currentContext!,
      method: method,
      promptAvailable: promptAvailable,
      promptInstall: () async {
        prompts++;
        promptAvailable.value = false;
        return accept;
      },
      openUrl: (url) async => opened.add(url),
      inviteId: () => 'a/b+c=',
    );
    await tester.pumpAndSettle();
    return asked;
  }

  testWidgets('asks on every launch in a tab', (tester) async {
    await pumpHome(tester);
    for (var launchCount = 0; launchCount < 2; launchCount++) {
      expect(await launch(tester, InstallMethod.iosHomeScreen), isTrue);
      expect(find.text('Install Split'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
  });

  testWidgets('says nothing where installing is impossible', (tester) async {
    await pumpHome(tester);
    expect(await launch(tester, InstallMethod.none), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('does not cover a screen opened meanwhile', (tester) async {
    await pumpHome(tester);
    Navigator.of(home.currentContext!).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('A form')),
    ));
    await tester.pumpAndSettle();

    expect(await launch(tester, InstallMethod.android), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('iPhone: explains Add to Home Screen and the separate storage',
      (tester) async {
    await pumpHome(tester);
    await launch(tester, InstallMethod.iosHomeScreen);

    expect(find.textContaining('Add to Home Screen'), findsOneWidget);
    expect(find.textContaining("don't carry over"), findsOneWidget);
  });

  testWidgets('Android: Google Play brings the current group along',
      (tester) async {
    await pumpHome(tester);
    await launch(tester, InstallMethod.android);

    await tester.tap(find.text('Get the Android app'));
    await tester.pumpAndSettle();

    expect(opened, [playStoreLink(inviteId: 'a/b+c=')]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Android: installs the web app once Chrome allows it',
      (tester) async {
    await pumpHome(tester);
    await launch(tester, InstallMethod.android);

    // No prompt from the browser (yet): explain its menu instead.
    expect(find.textContaining('In the browser menu'), findsOneWidget);
    await tester.tap(find.text('Install the web app'));
    await tester.pumpAndSettle();
    expect(prompts, 0);

    promptAvailable.value = true;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install the web app'));
    await tester.pumpAndSettle();

    expect(prompts, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('computer: INSTALL when the browser allows it, else its menu',
      (tester) async {
    await pumpHome(tester);
    await launch(tester, InstallMethod.desktop);
    expect(find.text('INSTALL'), findsNothing);
    expect(find.textContaining('install button in the address bar'),
        findsOneWidget);

    promptAvailable.value = true;
    await tester.pumpAndSettle();
    accept = false;
    await tester.tap(find.text('INSTALL'));
    await tester.pumpAndSettle();

    // Dismissed: the dialog stays, and falls back to the menu instructions.
    expect(prompts, 1);
    expect(find.text('Install Split'), findsOneWidget);
    expect(find.text('INSTALL'), findsNothing);
  });

  testWidgets('Safari on a Mac: Add to Dock', (tester) async {
    await pumpHome(tester);
    await launch(tester, InstallMethod.macSafari);
    expect(find.textContaining('Add to Dock'), findsOneWidget);
  });
}
