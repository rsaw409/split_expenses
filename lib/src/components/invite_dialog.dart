import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

void showInviteDialog(
  BuildContext context,
  String groupName,
  String inviteId,
) {
  const url =
      'https://play.google.com/store/apps/details?id=developer.rohitsaw.split';
  final userJoinLink = 'https://portfolio.rsaw409.me/joinGroup/$inviteId';

  final msg =
      'Join our group "$groupName".\n\n1. Download Split: $url\n2. Open this link on your smartphone: $userJoinLink\n';

  showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: const Icon(Icons.group_add_outlined),
        ),
        title: const Text(
          'Invite to group',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share the invite below, or have them enter this code manually.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
                right: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteId,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copy code',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteId));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..removeCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Code copied.')),
                        );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'OK'),
            child: const Text('LATER'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final result = await SharePlus.instance.share(
                ShareParams(text: msg, subject: 'Look what I made!'),
              );
              if (result.status == ShareResultStatus.success) {
                var snackBar = SnackBar(
                  content: Text('Successfully share group: $groupName'),
                );
                if (!context.mounted) return;

                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(snackBar);
                Navigator.pop(context, 'OK');
              }
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('SHARE'),
          ),
        ],
      );
    },
  );
}
