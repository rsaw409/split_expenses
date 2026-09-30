import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/push.dart';
import '../services/web_app.dart';
import '../utils/install_method.dart';

/// Set once the startup prompt has been shown in this browser, whatever the
/// answer: the drawer's Turn on notifications row covers a later change of
/// mind, so the prompt never nags.
const _promptShownKey = 'notificationsPromptShown';

/// Asks once, at the installed web app's first launch, whether to turn on
/// notifications, like Android asking at launch. Installing doesn't grant
/// permission, on iPhone either. The browser's own prompt appears only after
/// TURN ON is tapped, for two reasons:
/// - Firefox and Safari (every iPhone browser) ignore a permission request
///   that no tap led to, and Chrome may quietly hide one shown on load.
/// - A Block in the browser is permanent unless undone in its site settings,
///   so the browser should only ask someone who has already said yes.
///
/// Shows nothing in a browser tab (it asks to install instead, see
/// install_prompt.dart), in the native apps (they ask at launch), once
/// allowed or blocked, or where push is unavailable, and those launches don't
/// count as asking.
Future<void> askForNotificationsOnce(
  BuildContext context, {
  Future<PushPermission> Function() permission = pushPermission,
  Future<void> Function() requestPermission = requestPushPermission,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_promptShownKey) ?? false) return;

  // On web this waits for OneSignal's SDK, which can take a few seconds.
  final current = await permission();
  if (current != PushPermission.canRequest) return;
  // Don't cover a form or dialog opened while the SDK loaded; the next
  // launch asks instead.
  if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
    return;
  }

  unawaited(prefs.setBool(_promptShownKey, true));

  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  unawaited(showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: const Icon(Icons.notifications_outlined),
      ),
      title: const Text(
        'Turn on notifications?',
        textAlign: TextAlign.center,
      ),
      content: Text(
        'Get notified about activity in your groups, like new expenses and '
        'payments.',
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('NOT NOW'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            // Called right here, inside the tap, not after awaiting the
            // dialog: the browser only prompts in response to a user action.
            requestPermission();
          },
          child: const Text('TURN ON'),
        ),
      ],
    ),
  ));
}

/// How to unblock notifications once they are blocked, which neither the
/// app nor the browser can prompt for again. Notifications are only offered
/// in the installed app, whose setting usually lives outside the browser, so
/// the steps depend on how it was installed: the same categories as the
/// install dialog's, from [installMethodFor]. [method] is for tests.
void showBlockedHelp(BuildContext context, {InstallMethod? method}) {
  final how =
      method ?? installMethodFor(browserUserAgent, defaultTargetPlatform);
  final steps = switch (how) {
    InstallMethod.iosHomeScreen => 'Open the Settings app, tap Notifications, '
        'then Split, and turn on Allow Notifications.',
    InstallMethod.android => 'Touch and hold the Split icon on your home '
        'screen, tap App info, then Notifications, and turn them on.',
    InstallMethod.desktop => 'In Split\'s window, open the menu at the top, '
        'choose App info or App settings, and allow notifications.',
    InstallMethod.macSafari => 'Open System Settings, click Notifications, '
        'then Split, and turn on Allow notifications.',
    InstallMethod.none =>
      'Allow notifications for Split in your device or browser settings.',
  };
  _explain(
    context,
    'Notifications are blocked',
    'Split can\'t ask again once notifications are blocked. $steps Then '
        'reopen Split.',
  );
}

void _explain(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
