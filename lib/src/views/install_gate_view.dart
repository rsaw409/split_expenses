import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group.dart';
import '../notify_controllers/groups_controller.dart';
import '../services/api_exception.dart';
import '../services/group_service.dart';
import '../services/web_app.dart' as web_app;
import '../theme/app_theme.dart';
import '../utils/install_method.dart';
import '../utils/invite_link.dart';

/// Whether this launch is a browser tab, which gets [InstallGateView] instead
/// of the app: Split only runs installed. Release builds only, since
/// `flutter run` serves the app in a tab.
bool get blockedInBrowserTab => kReleaseMode && web_app.runningInBrowserTab;

/// How this browser can install the app.
InstallMethod browserInstallMethod() =>
    installMethodFor(web_app.browserUserAgent, defaultTargetPlatform);

/// What a browser tab shows instead of the app: how to install Split, with no
/// way past it.
///
/// An invite link that lands here still counts. Where the installed app
/// shares this tab's storage (Chrome's and other Android browsers' installed
/// web apps, and Chromium's on a computer), the group is joined here, so it is
/// waiting in the app. Safari's installed apps (iPhone, iPad, Mac) keep their
/// own storage, so there the invite is offered to copy and paste into Join
/// group; on Android, Google Play carries it into the Android app.
class InstallGateView extends StatefulWidget {
  const InstallGateView({
    super.key,
    required this.method,
    this.inviteId,
    this.promptAvailable,
    this.promptInstall = web_app.promptInstall,
    this.openUrl = _openExternally,
    this.joinGroup = joinGroupFromInviteId,
  });

  final InstallMethod method;

  /// The invite in the link that opened this tab, if any.
  final String? inviteId;

  /// Whether the browser's own install prompt is available; defaults to
  /// [web_app.installPromptAvailable].
  final ValueListenable<bool>? promptAvailable;
  final Future<bool> Function() promptInstall;
  final Future<void> Function(Uri url) openUrl;
  final Future<Group> Function(String inviteId) joinGroup;

  @override
  State<InstallGateView> createState() => _InstallGateViewState();
}

Future<void> _openExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

class _InstallGateViewState extends State<InstallGateView> {
  Group? _joined;
  String? _joinError;
  bool _installed = false;

  /// Whether the installed app will see what this tab saves.
  bool get _sharesStorage =>
      widget.method == InstallMethod.android ||
      widget.method == InstallMethod.desktop;

  @override
  void initState() {
    super.initState();
    _joinHere(widget.inviteId);
  }

  @override
  void didUpdateWidget(InstallGateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A link followed while this tab is open.
    if (widget.inviteId != oldWidget.inviteId) _joinHere(widget.inviteId);
  }

  void _joinHere(String? inviteId) {
    if (inviteId == null || !_sharesStorage) return;
    final groups = context.read<GroupsController>();
    widget.joinGroup(inviteId).then((group) async {
      await groups.saveGroups(group);
      if (mounted) {
        setState(() {
          _joined = group;
          _joinError = null;
        });
      }
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() => _joinError = error is ApiException
          ? error.message
          : "Couldn't reach Split to join the group. Open the invite link "
              'again once Split is installed.');
    });
  }

  /// Starts the browser's install prompt inside the tap.
  void _install() {
    widget.promptInstall().then((accepted) {
      if (accepted && mounted) setState(() => _installed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // The link's invite, or else the group this browser had selected before
    // tabs were blocked, to carry into the installed app.
    final selectedInvite = context.select<GroupsController, String?>(
      (groups) => groups.selectedGroup['inviteId'] as String?,
    );
    final invite = widget.inviteId ?? selectedInvite;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ValueListenableBuilder<bool>(
                valueListenable:
                    widget.promptAvailable ?? web_app.installPromptAvailable,
                builder: (context, canPrompt, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Image.asset(
                        'assets/images/split.webp',
                        width: 72,
                        height: 72,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Install Split',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.method == InstallMethod.none
                          ? "Split only runs as an installed app, and this "
                              "browser can't install it."
                          : 'Split runs as an installed app, not in a browser '
                              'tab. Install it to continue.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_joined != null)
                      _Notice(
                        icon: Icons.check_circle_outline,
                        text: "You've joined ${_joined!.name}. It's waiting "
                            'for you in the app.',
                      ),
                    if (_joinError != null)
                      _Notice(icon: Icons.error_outline, text: _joinError!),
                    const SizedBox(height: AppSpacing.lg),
                    ..._instructions(context, canPrompt, invite),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _instructions(
    BuildContext context,
    bool canPrompt,
    String? invite,
  ) {
    // Safari's installed apps keep their own groups: carry the invite over.
    List<Widget> copyInvite() => invite == null
        ? const []
        : [
            const _Hint('The installed app keeps its own groups. To join this '
                'group there, copy its invite and paste it in Join group.'),
            const SizedBox(height: AppSpacing.md),
            _CopyButton(
              label: 'COPY INVITE',
              text: inviteLink(invite).toString(),
            ),
          ];

    switch (widget.method) {
      case InstallMethod.iosHomeScreen:
        return [
          const _Steps([
            'Tap Share in the browser.',
            'Tap Add to Home Screen.',
            'Open Split from your Home Screen.',
          ]),
          ...copyInvite(),
        ];
      case InstallMethod.macSafari:
        return [
          const _Steps([
            'In the menu bar, choose File.',
            'Choose Add to Dock.',
            'Open Split from the Dock.',
          ]),
          ...copyInvite(),
        ];
      case InstallMethod.android:
        return [
          _InstallOption(
            icon: Icons.shop_outlined,
            title: 'Get the Android app',
            subtitle: 'From Google Play',
            onTap: () => widget.openUrl(playStoreLink(inviteId: invite)),
          ),
          _InstallOption(
            icon: _installed
                ? Icons.check_circle_outline
                : Icons.install_mobile_outlined,
            title: _installed ? 'Web app installed' : 'Install the web app',
            subtitle: _installed
                ? 'Open Split from your home screen'
                : canPrompt
                    ? 'Adds Split to your home screen'
                    : 'In the browser menu, tap Install app or Add to Home '
                        'screen',
            onTap: !_installed && canPrompt ? _install : null,
          ),
          const _Hint('Already installed? Open Split from your home screen.'),
        ];
      case InstallMethod.desktop:
        return [
          if (_installed)
            const _Hint('Split is installed. Open it from your apps.')
          else if (canPrompt)
            FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.install_desktop_outlined),
              label: const Text('INSTALL'),
            )
          else ...[
            const _Steps([
              'Click the install button in the address bar, or Install '
                  'Split in the browser menu.',
              'Open Split from your apps.',
            ]),
          ],
          if (!_installed)
            const _Hint('Already installed? Open Split from your apps.'),
        ];
      case InstallMethod.none:
        return [
          const _Steps([
            'Open this page in Chrome, Edge or Safari. In an app\'s built-in '
                'browser, use its Open in browser option.',
            'Install Split from there.',
          ]),
          const SizedBox(height: AppSpacing.md),
          _CopyButton(
            label: 'COPY LINK',
            text: invite == null
                ? 'https://$inviteLinkHost/'
                : inviteLink(invite).toString(),
          ),
        ];
    }
  }
}

/// Numbered steps.
class _Steps extends StatelessWidget {
  const _Steps(this.steps);

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(steps[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copies [text], confirming in its own label.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.label, required this.text});

  final String label;
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (mounted) setState(() => _copied = true);
      },
      icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
      label: Text(_copied ? 'COPIED' : widget.label),
    );
  }
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
