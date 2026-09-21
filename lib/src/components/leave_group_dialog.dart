import 'package:flutter/material.dart';

Future<bool> showLeaveGroupDialog(
  BuildContext context,
  String groupName,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
          child: const Icon(Icons.logout_outlined),
        ),
        title: const Text(
          'Leave group',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'You will be removed from "$groupName" and will no longer see its expenses. You can only rejoin with an invite.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LEAVE'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
