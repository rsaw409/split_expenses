import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../notify_controllers/groups_controller.dart';
import '../services/web_app.dart' as web_app;
import '../theme/app_theme.dart';
import '../utils/install_method.dart';
import '../utils/invite_link.dart';

/// How this launch can install the app: [InstallMethod.none] in the native
/// apps, in the installed web app, and in debug builds, where a `flutter run`
/// tab would ask on every restart.
InstallMethod currentInstallMethod() {
  if (!kReleaseMode || !web_app.runningInBrowserTab) return InstallMethod.none;
  return installMethodFor(web_app.browserUserAgent, defaultTargetPlatform);
}

/// Asks a browser tab to install the app, on every launch, since
/// notifications only work in the installed app (on iPhone, a tab can't get
/// them at all). The installed app asks about notifications instead (see
/// notifications_prompt.dart). Returns whether it asked: not where installing
/// is impossible, nor over a screen opened meanwhile.
bool askToInstall(
  BuildContext context, {
  InstallMethod? method,
  ValueListenable<bool>? promptAvailable,
  Future<bool> Function() promptInstall = web_app.promptInstall,
  Future<void> Function(Uri url) openUrl = _openExternally,
  String? Function()? inviteId,
}) {
  final how = method ?? currentInstallMethod();
  if (how == InstallMethod.none) return false;
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;

  showDialog<void>(
    context: context,
    builder: (_) => _InstallDialog(
      method: how,
      promptAvailable: promptAvailable ?? web_app.installPromptAvailable,
      promptInstall: promptInstall,
      openUrl: openUrl,
      // Read on tap: the saved groups may still be loading at launch.
      inviteId: inviteId ??
          () => context.read<GroupsController>().selectedGroup['inviteId']
              as String?,
    ),
  );
  return true;
}

Future<void> _openExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

class _InstallDialog extends StatelessWidget {
  const _InstallDialog({
    required this.method,
    required this.promptAvailable,
    required this.promptInstall,
    required this.openUrl,
    required this.inviteId,
  });

  final InstallMethod method;
  final ValueListenable<bool> promptAvailable;
  final Future<bool> Function() promptInstall;
  final Future<void> Function(Uri url) openUrl;
  final String? Function() inviteId;

  /// Starts the browser's install prompt inside the tap, and closes the
  /// dialog once it is accepted.
  void _install(BuildContext context) {
    final navigator = Navigator.of(context);
    promptInstall().then((accepted) {
      if (accepted && navigator.mounted) navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDesktop =
        method == InstallMethod.desktop || method == InstallMethod.macSafari;

    Widget hint(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
    Widget steps(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        );

    return ValueListenableBuilder<bool>(
      // Chrome's prompt can become available while the dialog is open.
      valueListenable: promptAvailable,
      builder: (context, canPrompt, _) {
        final List<Widget> body;
        final List<Widget> actions;
        switch (method) {
          case InstallMethod.iosHomeScreen:
            body = [
              steps('Tap Share, then Add to Home Screen, and open Split from '
                  'there.'),
              hint('Groups joined in the browser don\'t carry over to the '
                  'Home Screen app. Join them again there with their invite '
                  'codes.'),
            ];
            actions = [_close(context, 'OK')];
          case InstallMethod.android:
            body = [
              const SizedBox(height: AppSpacing.sm),
              _InstallOption(
                icon: Icons.shop_outlined,
                title: 'Get the Android app',
                subtitle: 'From Google Play',
                onTap: () {
                  openUrl(playStoreLink(inviteId: inviteId()));
                  Navigator.pop(context);
                },
              ),
              _InstallOption(
                icon: Icons.install_mobile_outlined,
                title: 'Install the web app',
                subtitle: canPrompt
                    ? 'Adds Split to your home screen'
                    : 'In the browser menu, tap Install app or Add to Home '
                        'screen',
                onTap: canPrompt ? () => _install(context) : null,
              ),
              hint('Already installed? Open Split from your home screen.'),
            ];
            actions = [_close(context, 'NOT NOW')];
          case InstallMethod.desktop:
            body = canPrompt
                ? const []
                : [
                    steps('Use the install button in the address bar, or '
                        'Install Split in the browser menu.'),
                    hint('Already installed? Open Split from your apps.'),
                  ];
            actions = canPrompt
                ? [
                    _close(context, 'NOT NOW'),
                    FilledButton(
                      onPressed: () => _install(context),
                      child: const Text('INSTALL'),
                    ),
                  ]
                : [_close(context, 'OK')];
          case InstallMethod.macSafari:
            body = [
              steps('In the menu bar, choose File, then Add to Dock.'),
              hint('Already added? Open Split from the Dock.'),
            ];
            actions = [_close(context, 'OK')];
          case InstallMethod.none:
            body = const [];
            actions = [_close(context, 'OK')];
        }

        return AlertDialog(
          icon: CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Icon(isDesktop
                ? Icons.install_desktop_outlined
                : Icons.install_mobile_outlined),
          ),
          title: const Text('Install Split', textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Split works best installed, and notifications only work '
                    'in the installed app.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  ...body,
                ],
              ),
            ),
          ),
          actions: actions,
        );
      },
    );
  }

  Widget _close(BuildContext context, String label) => TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(label),
      );
}

class _InstallOption extends StatelessWidget {
  const _InstallOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
