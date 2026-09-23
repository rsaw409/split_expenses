import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';

import '../models/user_balance.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../theme/app_theme.dart';
import '../utils/reachability.dart';
import '../utils/currency.dart';
import '../utils/idempotency.dart';

class SettleView extends StatefulWidget {
  const SettleView({super.key, required this.userBalances});

  final List<UserBalance> userBalances;

  @override
  State<SettleView> createState() => _SettleViewState();
}

class _SettleViewState extends State<SettleView> {
  List<Map<String, dynamic>> payments = [];
  bool _isSaving = false;
  final _idempotency = IdempotencyKeySet();

  @override
  void initState() {
    super.initState();

    // Match in paise, not rupee doubles — balances can now carry fractional
    // rupees (e.g. -1800.33), and float subtraction across this loop can
    // drift away from exact zero, leaving a phantom paisa-sized "balance".
    final userBalances = widget.userBalances.map(
      (e) => {...e.toMap(), 'balances': amountToPaise(e.balances)},
    );

    List<Map<String, dynamic>> positive =
        userBalances.where((e) => (e['balances'] as int) > 0).toList();
    positive.sort((a, b) => (b['balances'] as int).compareTo(a['balances'] as int));

    List<Map<String, dynamic>> negative =
        userBalances.where((e) => (e['balances'] as int) < 0).toList();
    negative.sort((a, b) => (a['balances'] as int).compareTo(b['balances'] as int));

    int i = 0;
    int j = 0;

    while (i < negative.length) {
      if ((negative[i]['balances'] as int) < 0) {
        while (j < positive.length) {
          int maximumPaymentPaise = min(
            positive[j]['balances'] as int,
            -(negative[i]['balances'] as int),
          );

          payments.add({
            'from': negative[i]['user_id'],
            'fromName': negative[i]['name'],
            'to': positive[j]['user_id'],
            'toName': positive[j]['name'],
            'amount': maximumPaymentPaise / 100,
            'selected': false,
            'groupName': context.read<GroupsController>().selectedGroup["name"]
          });

          negative[i]['balances'] =
              (negative[i]['balances'] as int) + maximumPaymentPaise;
          positive[j]['balances'] =
              (positive[j]['balances'] as int) - maximumPaymentPaise;

          if (negative[i]['balances'] == 0) break;
          if (positive[j]['balances'] == 0) {
            j += 1;
            continue;
          }

          j += 1;
        }
      }

      i += 1;
    }
  }

  void _savePayments(BuildContext context) {
    if (!requireReachable(context,
        message: "Can't reach Split — these payments weren't recorded.")) {
      return;
    }

    // A key per payment, identified by who pays whom and how much, so a retry
    // after a partial failure re-applies only what did not land. The
    // settlement walk never pays the same creditor twice from one debtor, so
    // these identities cannot collide within a batch.
    final selected = payments
        .where((e) => e['selected'])
        .map((payment) => {
              ...payment,
              'idempotency_key': _idempotency.forPayload({
                'from': payment['from'],
                'to': payment['to'],
                'amount': payment['amount'],
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
          const SnackBar(content: Text('Payments recorded.')),
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
    final hasSelection = payments.any((e) => e['selected']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle up'),
        actions: [
          if (hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton(
                onPressed: _isSaving ? null : () => _savePayments(context),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
        ],
      ),
      body: payments.isEmpty
          ? Center(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Image.asset(
                    "assets/images/allSettle.webp",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              separatorBuilder: (context, index) => const Divider(indent: 16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '${payment['fromName']} → ${payment['toName']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(formatCurrency(payment['amount'] as num)),
                  onChanged: (val) {
                    setState(() {
                      payment['selected'] = !payment['selected'];
                    });
                  },
                  value: payment['selected'],
                );
              },
            ),
    );
  }
}
