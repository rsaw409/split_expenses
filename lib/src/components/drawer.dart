import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/settings_controller.dart';
import '../services/push.dart';
import 'notifications_prompt.dart';
import '../theme/app_theme.dart';
import '../utils/group_icon.dart';
import 'group_icon.dart';
import '../views/create_group_view.dart';
import '../views/join_group_view.dart';

const _themeLabels = {
  ThemeMode.system: 'System default',
  ThemeMode.light: 'Light',
  ThemeMode.dark: 'Dark',
};

class MyDrawer extends StatelessWidget {
  const MyDrawer({
    super.key,
  });

  void _showAboutDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.asset(
            'assets/images/split.webp',
            width: 56,
            height: 56,
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(packageInfo.appName),
            Text(
              'Version ${packageInfo.version}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KEY FEATURES',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _FeatureRow(
                icon: Icons.group_add_outlined,
                text: 'Join or create a group',
              ),
              const _FeatureRow(
                icon: Icons.shopping_bag_outlined,
                text: 'Record and split expenses in groups',
              ),
              const _FeatureRow(
                icon: Icons.sync_alt_rounded,
                text: 'Record payments made within groups',
              ),
              const _FeatureRow(
                icon: Icons.handshake_outlined,
                text: 'Settle up easily from the overview',
              ),
              const Divider(height: AppSpacing.xl),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: 'Made with '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.favorite,
                          size: 14,
                          color: colorScheme.error,
                        ),
                      ),
                      const TextSpan(text: ' by rsaw409'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Android's own choice-dialog convention: picking an option applies it
  /// immediately and closes the dialog, so there is no OK button.
  void _showThemeDialog(BuildContext context, ThemeMode current) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Theme'),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (mode) {
            context.read<SettingsController>().updateThemeMode(mode);
            Navigator.pop(dialogContext);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in _themeLabels.keys)
                RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(_themeLabels[mode]!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Asks whether to create or join, then opens that form. Neither option is
  /// gated on reachability: each form checks on submit and keeps what was
  /// typed, so it can be retried once Split is reachable again.
  Future<void> _showAddGroupDialog(BuildContext context) async {
    final choice = await showDialog<Widget>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a group'),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddGroupOption(
              icon: Icons.group_add_outlined,
              title: 'New group',
              subtitle: 'Start a group and add people to it',
              onTap: () =>
                  Navigator.pop(dialogContext, const CreateGroupView()),
            ),
            _AddGroupOption(
              icon: Icons.qr_code_outlined,
              title: 'Join group',
              subtitle: 'Use an invite link or code someone shared',
              onTap: () => Navigator.pop(dialogContext, const JoinGroupView()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    // Close the drawer first: the form's result snackbar is shown on the
    // home screen, and Scaffold paints an open drawer over snackbars.
    final navigator = Navigator.of(context)..pop();
    navigator.push(MaterialPageRoute(builder: (_) => choice));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.asset(
                      'assets/images/split.webp',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Split',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Selector<
                  GroupsController,
                  ({
                    List<Map<String, dynamic>> groups,
                    Map<String, dynamic> selectedGroup,
                  })>(
                selector: (_, controller) => (
                  groups: controller.groups,
                  selectedGroup: controller.selectedGroup,
                ),
                builder: (context, data, __) {
                  if (data.groups.isEmpty) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('GROUPS'),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          child: Text('Tap + below to create or join one.'),
                        ),
                      ],
                    );
                  }

                  final selectedId = data.selectedGroup['id'];
                  final selected = data.groups
                      .where((group) => group['id'] == selectedId)
                      .firstOrNull;
                  final others = data.groups
                      .where((group) => group['id'] != selectedId)
                      .toList();

                  // The selected group is pinned outside the scrollable list,
                  // so it stays visible however many groups the user has.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selected != null) ...[
                        const _SectionLabel('CURRENT GROUP'),
                        _GroupTile(group: selected, isSelected: true),
                      ],
                      if (others.isNotEmpty) ...[
                        _SectionLabel(
                          selected != null ? 'OTHER GROUPS' : 'GROUPS',
                        ),
                        Expanded(child: _GroupList(groups: others)),
                      ],
                    ],
                  );
                },
              ),
            ),
            // The add button sits on the right end of the divider between
            // the groups and the footer, so it reads as belonging to the list
            // above without taking a row of its own.
            SizedBox(
              // Tall enough for the 56dp button, so it straddles the line
              // without crowding the footer row below.
              height: 68,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: IconButton.filledTonal(
                      tooltip: 'Add group',
                      iconSize: 30,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(56),
                      ),
                      icon: const Icon(Icons.add),
                      onPressed: () => _showAddGroupDialog(context),
                    ),
                  ),
                ],
              ),
            ),
            // Every footer item is a compact ListTile sharing the same icon
            // column, so the theme and links read as one menu.
            const NotificationsAction(),
            _DrawerAction(
              icon: Icons.palette_outlined,
              label: 'Theme',
              onTap: () => _showThemeDialog(
                context,
                context.read<SettingsController>().themeMode,
              ),
            ),
            // Opens the Play listing: the Play Store app on Android, its web
            // page in a browser. Hidden on iPhone and iPad, native or web,
            // where there is no listing to review.
            if (defaultTargetPlatform == TargetPlatform.android ||
                (kIsWeb && defaultTargetPlatform != TargetPlatform.iOS))
              _DrawerAction(
                icon: Icons.feedback_outlined,
                label: 'Feedback',
                onTap: () {
                  final url = Uri.parse(kIsWeb
                      ? 'https://play.google.com/store/apps/details?id=developer.rohitsaw.split'
                      : 'market://details?id=developer.rohitsaw.split');
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
            _DrawerAction(
              icon: Icons.info_outline,
              label: 'About',
              onTap: () => _showAboutDialog(context),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// Turns notifications on in the installed web app after the startup prompt
/// ([askForNotificationsOnce]) was answered NOT NOW or its browser prompt
/// dismissed, since that prompt only asks once. Shows nothing once they are
/// on, in a browser tab (which asks to install instead), or in the native
/// apps, which ask at launch.
class NotificationsAction extends StatefulWidget {
  const NotificationsAction({
    super.key,
    this.permission = pushPermission,
    this.requestPermission = requestPushPermission,
  });

  final Future<PushPermission> Function() permission;
  final Future<void> Function() requestPermission;

  @override
  State<NotificationsAction> createState() => _NotificationsActionState();
}

class _NotificationsActionState extends State<NotificationsAction> {
  PushPermission _permission = PushPermission.unavailable;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final permission = await widget.permission();
    if (mounted) setState(() => _permission = permission);
  }

  Future<void> _turnOn() async {
    await widget.requestPermission();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_permission) {
      PushPermission.unavailable ||
      PushPermission.granted =>
        const SizedBox.shrink(),
      PushPermission.canRequest => _DrawerAction(
          icon: Icons.notifications_outlined,
          label: 'Turn on notifications',
          onTap: _turnOn,
        ),
      PushPermission.denied => _DrawerAction(
          icon: Icons.notifications_off_outlined,
          label: 'Notifications blocked',
          onTap: () => showBlockedHelp(context),
        ),
    };
  }
}

/// A compact footer row; every footer item uses the same tile shape.
class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// Scrollable list of the non-selected groups. Owns its [ScrollController] so
/// the scrollbar tracks only this list's viewport, not the whole drawer.
class _GroupList extends StatefulWidget {
  const _GroupList({required this.groups});

  final List<Map<String, dynamic>> groups;

  @override
  State<_GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<_GroupList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        itemCount: widget.groups.length,
        itemBuilder: (context, index) =>
            _GroupTile(group: widget.groups[index], isSelected: false),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.isSelected});

  final Map<String, dynamic> group;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: isSelected,
      selectedTileColor: colorScheme.secondaryContainer,
      leading: GroupIconAvatar(
        name: group['name'],
        icon: groupIconFromMap(group),
        initialsBackground: isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        initialsForeground:
            isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        group['name'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? colorScheme.onSecondaryContainer : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : null,
      onTap: () {
        context.read<GroupsController>().selectedGroup = group;
        Navigator.pop(context);
      },
    );
  }
}

class _AddGroupOption extends StatelessWidget {
  const _AddGroupOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
