import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

void showInviteDialog(
  BuildContext context,
  String groupName,
  String inviteId,
) {
  const url =
      'https://play.google.com/store/apps/details?id=developer.rohitsaw.split';
  final userJoinLink = 'https://portfolio.rsaw409.me/joinGroup/$inviteId';

  final msg =
      'Join our group "$groupName".\n\n1. Download Split: $url\n2. Open this link on your smartphone: $userJoinLink\n\nEnter the following code: $inviteId';

  showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Padding(
        padding:
            const EdgeInsets.only(top: 8.0, bottom: 8, left: 20, right: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(
                  left: 10.0, right: 10, top: 5, bottom: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                inviteId, // Your text
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24.0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Others can access your group using this code.')
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, 'OK'),
          child: const Text('LATER'),
        ),
        OutlinedButton(
          onPressed: () async {
            final result = await Share.share(msg, subject: 'Look what I made!');
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
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black, width: 2.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          ),
          child: const Text(
            'INVITE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
