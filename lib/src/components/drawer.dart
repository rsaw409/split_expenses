import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/initials.dart';
import '../views/new_form.dart';

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
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  const _SectionLabel('GROUPS'),
                  Selector<
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
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          child:
                              Text('Join or create one below to get started.'),
                        );
                      }

                      return Column(
                        children: data.groups.map(
                          (group) {
                            final isSelected =
                                group['id'] == data.selectedGroup['id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: colorScheme.secondaryContainer,
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                foregroundColor: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                child: Text(initialsOf(group['name'])),
                              ),
                              title: Text(
                                group['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? colorScheme.onSecondaryContainer
                                      : null,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                context.read<GroupsController>().selectedGroup =
                                    group;
                                Navigator.pop(context);
                              },
                            );
                          },
                        ).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_outlined, size: 18),
                      label: const Text(
                        'Join group',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const NewForm(
                              saveButtonText: 'Join Group',
                              textFieldLabel: 'Invite Id',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text(
                        'Create group',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const NewForm(
                              saveButtonText: 'Create Group',
                              textFieldLabel: 'Group Name',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const _SectionLabel('THEME'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Selector<SettingsController, ThemeMode>(
                selector: (_, SettingsController settingController) =>
                    settingController.themeMode,
                builder: (_, ThemeMode themeMode, __) =>
                    SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) {
                    context.read<SettingsController>().updateThemeMode(
                          selection.first,
                        );
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Feedback'),
                onTap: () {
                  final url = Uri.parse(
                    'market://details?id=developer.rohitsaw.split',
                  );
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
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
