import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';

import '../models/user_balance.dart';
import '../components/async_state.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../theme/app_theme.dart';
import '../utils/reachability.dart';
import '../utils/group_currency.dart';
import '../utils/idempotency.dart';
import '../utils/settlement.dart';

const _unreachableMessage =
    "Can't reach Split — these payments weren't recorded.";

class SettleView extends StatefulWidget {
  const SettleView({super.key, required this.userBalances});

  final List<UserBalance> userBalances;

  @override
  State<SettleView> createState() => _SettleViewState();
}

class _SettleViewState extends State<SettleView> {
  late final List<SuggestedPayment> _payments =
      suggestPayments(widget.userBalances);
  final Set<int> _selected = {};
  bool _isSaving = false;
  final _idempotency = IdempotencyKeySet();

  List<SuggestedPayment> get _selectedPayments =>
      [for (final i in _selected.toList()..sort()) _payments[i]];

  int _totalOf(Iterable<SuggestedPayment> payments) =>
      payments.fold(0, (sum, p) => sum + p.amount);

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _payments.length) {
        _selected.clear();
      } else {
        _selected.addAll(List.generate(_payments.length, (i) => i));
      }
    });
  }

  Future<void> _confirmAndSave(BuildContext context) async {
    // Checked before asking too, so nobody confirms a write that cannot go
    // out; _savePayments checks again because the dialog may sit open.
    if (!requireReachable(context, message: _unreachableMessage)) return;

    final confirmed = await showRecordPaymentsDialog(
      context,
      payments: _selectedPayments,
      groupName: context.read<GroupsController>().selectedGroup['name'],
    );
    if (!confirmed || !context.mounted) return;

    _savePayments(context);
  }

  void _savePayments(BuildContext context) {
    if (!requireReachable(context, message: _unreachableMessage)) return;

    // A key per payment, identified by who pays whom and how much, so a retry
    // after a partial failure re-applies only what did not land. The
    // settlement walk never pays the same creditor twice from one debtor, so
    // these identities cannot collide within a batch.
    final selected = _selectedPayments
        .map((payment) => {
              ...payment.toMap(),
              'idempotency_key': _idempotency.forPayload({
                'from': payment.from,
                'to': payment.to,
                'amount': payment.amount,
              }),
            })
        .toList();
    setState(() => _isSaving = true);

    savePayments(selected).then((val) {
      if (!context.mounted) return;
      _idempotency.reset();
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(selected.length == 1
                ? 'Payment recorded.'
                : '${selected.length} payments recorded.'),
          ),
        );

      context.read<UserBalanceController>().refresh();
      context.read<AllExpenseController>().refresh();

      Navigator.pop(context);
    }).catchError((error) {
      if (!context.mounted) return;
      setState(() => _isSaving = false);

      // See new_expense.dart. This one matters most: a replayed settle-up
      // could double-record several payments at once.
      final serverAnswered = error is ApiException;
      if (!serverAnswered) {
        context.read<UserBalanceController>().refresh();
        context.read<AllExpenseController>().refresh();
      }

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              serverAnswered ? error.message : unconfirmedWriteMessage,
            ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settle up')),
      body: _payments.isEmpty
          ? const EmptyStateView(
              icon: Icons.task_alt_rounded,
              title: 'All settled up',
              subtitle: 'Nobody owes anyone in this group.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              children: [
                _SummaryHeader(
                  count: _payments.length,
                  total: _totalOf(_payments),
                ),
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  tristate: true,
                  value: _selected.isEmpty
                      ? false
                      : _selected.length == _payments.length
                          ? true
                          : null,
                  onChanged: _isSaving ? null : (_) => _toggleAll(),
                  title: const Text('Select all'),
                ),
                const Divider(height: 1),
                for (var i = 0; i < _payments.length; i++)
                  _PaymentTile(
                    payment: _payments[i],
                    selected: _selected.contains(i),
                    onChanged: _isSaving ? null : () => _toggle(i),
                  ),
              ],
            ),
      bottomNavigationBar: _payments.isEmpty
          ? null
          : _RecordBar(
              count: _selected.length,
              total: _totalOf(_selectedPayments),
              isSaving: _isSaving,
              onPressed: () => _confirmAndSave(context),
            ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.handshake_outlined,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 payment settles everyone'
                        : '$count payments settle everyone',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${context.groupCurrency.format(total)} in total. Select the ones that '
                    'have been paid to record them.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.selected,
    required this.onChanged,
  });

  final SuggestedPayment payment;
  final bool selected;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final nameStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      title: Text.rich(
        TextSpan(children: [
          TextSpan(text: payment.fromName, style: nameStyle),
          TextSpan(
            text: ' pays ',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          TextSpan(text: payment.toName, style: nameStyle),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      secondary: Text(
        context.groupCurrency.format(payment.amount),
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RecordBar extends StatelessWidget {
  const _RecordBar({
    required this.count,
    required this.total,
    required this.isSaving,
    required this.onPressed,
  });

  final int count;
  final int total;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (count) {
      0 => 'Select payments to record',
      1 => 'Record 1 payment · ${context.groupCurrency.format(total)}',
      _ => 'Record $count payments · ${context.groupCurrency.format(total)}',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: count == 0 || isSaving ? null : onPressed,
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    );
  }
}

/// Asks before recording [payments], since payments cannot be edited or
/// deleted once saved — there is no endpoint for either.
Future<bool> showRecordPaymentsDialog(
  BuildContext context, {
  required List<SuggestedPayment> payments,
  required String? groupName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      final total = payments.fold(0, (sum, p) => sum + p.amount);
      final noun = payments.length == 1 ? 'payment' : 'payments';

      return AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: const Icon(Icons.handshake_outlined),
        ),
        title: Text(
          'Record ${payments.length} $noun?',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in payments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p.fromName} → ${p.toName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(context.groupCurrency.format(p.amount)),
                    ],
                  ),
                ),
              if (payments.length > 1) ...[
                const Divider(),
                Row(
                  children: [
                    Expanded(child: Text('Total', style: textTheme.titleSmall)),
                    Text(context.groupCurrency.format(total), style: textTheme.titleSmall),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                '${payments.length == 1 ? 'It' : 'They'}\'ll be added to '
                '${groupName == null ? 'this group' : '"$groupName"'} and '
                'can\'t be edited or deleted afterwards.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RECORD'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
