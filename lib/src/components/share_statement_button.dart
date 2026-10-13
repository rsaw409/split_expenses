import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_balance.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../services/statement_pdf.dart';
import '../utils/statement.dart';

/// Shares [member]'s statement as a PDF, straight to the platform's share
/// sheet (WhatsApp, mail, and so on). On web, where a browser can't share
/// files, the PDF downloads instead.
///
/// Built from the cached transaction list, so it works offline; it waits for
/// that list to load.
class ShareStatementButton extends StatefulWidget {
  const ShareStatementButton({super.key, required this.member});

  final UserBalance member;

  @override
  State<ShareStatementButton> createState() => _ShareStatementButtonState();
}

class _ShareStatementButtonState extends State<ShareStatementButton> {
  bool _sharing = false;

  Future<void> _share() async {
    // The share sheet anchors to the button, which iPad requires.
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final messenger = ScaffoldMessenger.of(context);
    final groups = context.read<GroupsController>();
    // The page was opened with a snapshot; prefer what the overview now says.
    final member = context
            .read<UserBalanceController>()
            .userBalances
            .where((b) => b.userId == widget.member.userId)
            .firstOrNull ??
        widget.member;
    final statement = buildStatement(
      expenses: context.read<AllExpenseController>().expenses,
      userId: member.userId,
      memberName: member.name,
      groupName: groups.selectedGroup['name'] as String? ?? '',
      now: DateTime.now(),
    );

    setState(() => _sharing = true);
    try {
      final bytes = await statementPdf(statement, groups.selectedCurrency);
      final name = statementFileName(statement);
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
        fileNameOverrides: [name],
        subject:
            'Split statement: ${statement.memberName} (${statement.groupName})',
        sharePositionOrigin: origin,
      ));
      if (result.status == ShareResultStatus.success) {
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text("${statement.memberName}'s statement shared."),
          ));
      }
    } catch (_) {
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text("Couldn't create the statement. Try again."),
        ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = context
        .select<AllExpenseController, bool>((c) => !c.isLoading && !c.isError);

    return FilledButton.tonalIcon(
      onPressed: ready && !_sharing ? _share : null,
      icon: _sharing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share),
      label: const Text('Share statement'),
    );
  }
}
