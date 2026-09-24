import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../utils/invite_link.dart';

void showInviteDialog(
  BuildContext context,
  String groupName,
  String inviteId,
) {
  const url =
      'https://play.google.com/store/apps/details?id=developer.rohitsaw.split';
  final userJoinLink = inviteLink(inviteId).toString();

  final msg =
      'Join our group "$groupName".\n\n1. Download Split: $url\n2. Open this link on your smartphone: $userJoinLink\n';

  showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return AlertDialog(
        title: const Text(
          'Invite to group',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan with a phone camera to join "$groupName".',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Always dark-on-white, even in dark theme: many scanners cannot
              // read an inverted code, and the quiet zone needs a light margin.
              // The fixed SizedBox answers AlertDialog's intrinsic-size query
              // itself; QrImageView is a LayoutBuilder and asserts if asked.
              SizedBox.square(
                dimension: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: QrImageView(
                    data: userJoinLink,
                    size: 200,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    semanticsLabel: 'QR code to join $groupName',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Or have them enter this code:',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
