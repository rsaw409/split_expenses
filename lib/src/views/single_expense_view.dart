import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/detail_row.dart';
import '../components/member_avatar.dart';
import '../models/expense/expense.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/group_currency.dart';

class SingleExpense extends StatelessWidget {
  const SingleExpense(
      {super.key, required this.expense, required this.isPayment});

  final Expense expense;
  final bool isPayment;

  String _percentageOf(int amount) {
    final percentage = (amount * 100) / expense.transactionAmount;
    return '${percentage.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = context.groupCurrency;

    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: Icon(
                isPayment
                    ? Icons.sync_alt_rounded
                    : Icons.shopping_bag_outlined,
              ),
            ),
            title: Text(
              expense.transactionTitle,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                DetailRow(
                  label: 'Amount',
                  value: currency.format(expense.transactionAmount),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                DetailRow(
                  label: isPayment ? 'From' : 'Paid by',
                  value: expense.userName,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                DetailRow(
                  label: isPayment ? 'To' : 'Split between',
                  value: isPayment
                      ? (expense.distributions[0].userName ?? 'Unknown')
                      : '${expense.distributions.length} people',
                  onTap: isPayment
                      ? null
                      : () => _showDistributionDialog(context, currency),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                DetailRow(
                  label: isPayment ? 'Paid on' : 'Purchased on',
                  value: DateFormat('dd MMM yyyy, hh:mm a').format(
                    expense.transactionDate.toLocal(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Takes the currency rather than reading `context.groupCurrency` in the
  // list's itemBuilder: that is a `context.select`, which provider asserts
  // against inside a SliverList item.
  void _showDistributionDialog(BuildContext context, Currency currency) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Expenses don't carry avatars; the member list does.
    final avatars = {
      for (final b in context.read<UserBalanceController>().userBalances)
        b.userId: b.avatar,
    };

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Split between'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: expense.distributions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final each = expense.distributions[index];
              final name = each.userName ?? 'Unknown';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MemberAvatar(
                  name: name,
                  avatar: avatars[each.userId],
                  radius: 18,
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_percentageOf(each.amount ?? 0)} of total',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  currency.format(each.amount ?? 0),
                  style: textTheme.titleMedium,
                ),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
