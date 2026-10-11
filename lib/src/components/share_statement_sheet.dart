import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_balance.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../services/statement_pdf.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/group_currency.dart';
import '../utils/refresh_group.dart';
import '../utils/statement.dart';
import '../utils/statement_text.dart';

enum StatementFormat { pdf, text }

/// Lets the user share [member]'s statement as a PDF or as text, through the
/// platform's share sheet (WhatsApp, mail, and so on).
///
/// Built from the cached transaction list, so it works offline; it says so
/// when that list may be behind the server.
Future<void> showShareStatementSheet(BuildContext context, UserBalance member) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ShareStatementSheet(member: member),
  );
}

class ShareStatementSheet extends StatefulWidget {
  const ShareStatementSheet({super.key, required this.member});

  final UserBalance member;

  @override
  State<ShareStatementSheet> createState() => _ShareStatementSheetState();
}

class _ShareStatementSheetState extends State<ShareStatementSheet> {
  StatementFormat _format = StatementFormat.pdf;
  bool _sharing = false;
  bool _refreshing = false;
  String? _error;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await refreshGroupData(context);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _share(
    Statement statement,
    Currency currency,
    Rect origin,
  ) async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final subject =
        'Split statement: ${statement.memberName} (${statement.groupName})';

    try {
      final ShareResult result;
      if (_format == StatementFormat.text) {
        final text = statementText(statement, currency);
        try {
          result = await SharePlus.instance.share(ShareParams(
            text: text,
            subject: subject,
            sharePositionOrigin: origin,
            // A browser without the Web Share API would otherwise open a
            // mail draft; copying lets it go to any chat instead.
            mailToFallbackEnabled: false,
          ));
        } on Exception {
          if (!kIsWeb) rethrow;
          await Clipboard.setData(ClipboardData(text: text));
          navigator.pop();
          messenger
            ..removeCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Statement copied. Paste it into any chat.'),
            ));
          return;
        }
      } else {
        final bytes = await statementPdf(statement, currency);
        final name = statementFileName(statement);
        result = await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: name)
          ],
          fileNameOverrides: [name],
          subject: subject,
          sharePositionOrigin: origin,
        ));
      }

      if (!mounted || result.status == ShareResultStatus.dismissed) return;
      navigator.pop();
      if (result.status == ShareResultStatus.success) {
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text("${statement.memberName}'s statement shared."),
          ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _format == StatementFormat.pdf
          ? "Couldn't create the PDF. Try sharing as text."
          : "Couldn't open the share sheet. Try again.");
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = context.groupCurrency;
    final expenses = context.watch<AllExpenseController>();
    final balances = context.watch<UserBalanceController>();
    final groupName = context.select<GroupsController, String>(
        (c) => c.selectedGroup['name'] as String? ?? '');

    // The page was opened with a snapshot; prefer what the overview now says.
    final member = balances.userBalances
            .where((b) => b.userId == widget.member.userId)
            .firstOrNull ??
        widget.member;

    final ready = !expenses.isLoading && !expenses.isError;
    final statement = buildStatement(
      expenses: expenses.expenses,
      userId: member.userId,
      memberName: member.name,
      groupName: groupName,
      now: DateTime.now(),
    );
    // Both lists are cached separately, so after a failed refresh one can be
    // behind the other; the statement balance then disagrees with the one
    // the overview shows.
    final maybeBehind = expenses.isStale ||
        balances.isStale ||
        (ready && !balances.isLoading && statement.balance != member.balances);

    final count = statement.lines.length;
    final hint = _format == StatementFormat.pdf
        ? 'A document with every transaction.'
        : count > statementTextLineLimit
            ? 'A message to paste in any chat, with the '
                '$statementTextLineLimit most recent transactions.'
            : 'A message to paste in any chat.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share statement', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ready
                  ? "${member.name}'s balance and "
                      '${count == 1 ? 'transaction' : 'all $count transactions'}'
                      ' in $groupName.'
                  : expenses.isError
                      ? "Couldn't load transactions."
                      : 'Loading transactions…',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<StatementFormat>(
              segments: const [
                ButtonSegment(
                  value: StatementFormat.pdf,
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: Text('PDF'),
                ),
                ButtonSegment(
                  value: StatementFormat.text,
                  icon: Icon(Icons.notes),
                  label: Text('Text'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: _sharing
                  ? null
                  : (selection) => setState(() {
                        _format = selection.first;
                        _error = null;
                      }),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (maybeBehind) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.sync_problem,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This may not include the latest transactions.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _refreshing ? null : _refresh,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Builder(
              // Its own context, so the share sheet can anchor to the button
              // (iPad requires an origin).
              builder: (buttonContext) => FilledButton.icon(
                onPressed: !ready || _sharing
                    ? null
                    : () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        _share(
                          statement,
                          currency,
                          box.localToGlobal(Offset.zero) & box.size,
                        );
                      },
                icon: _sharing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
