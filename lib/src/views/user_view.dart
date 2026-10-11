import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/views/expenses_view.dart';

import '../components/detail_row.dart';
import '../components/member_avatar.dart';
import '../components/share_statement_sheet.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../theme/app_theme.dart';
import '../utils/group_currency.dart';

class UserView extends StatelessWidget {
  const UserView({super.key, required this.userBalance});

  final UserBalance userBalance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSettled = userBalance.balances == 0;
    final isOwed = userBalance.balances > 0;
    final amountColor = isSettled
        ? colorScheme.onSurfaceVariant
        : isOwed
            ? colorScheme.positive
            : colorScheme.error;

    final transactions = userBalance.numberOfTransactions;
    final payments = userBalance.numberOfPayments;
    final benefits = userBalance.numberOfBenefits;

    // The statement is built from the group's transaction list, so it waits
    // for that to load; a cached list counts, so it works offline.
    final canShare = context.select<AllExpenseController, bool>(
        (c) => !c.isLoading && !c.isError);
    final shareStatement = canShare
        ? () => showShareStatementSheet(context, userBalance)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userBalance.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: shareStatement,
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share statement',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: userBalance.avatar == null
                ? CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    child: const Icon(Icons.person_2_outlined),
                  )
                : MemberAvatar(
                    name: userBalance.name,
                    avatar: userBalance.avatar,
                  ),
            title: Text(
              userBalance.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isSettled ? 'Settled up' : (isOwed ? 'Gets back' : 'Owes'),
            ),
            trailing: Text(
              context.groupCurrency.format(userBalance.balances.abs()),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                DetailRow(
                  label: 'Expenses',
                  value: '$transactions',
                  onTap: transactions > 0
                      ? () => _openExpenses(
                            context,
                            ExpensesView(
                              byId: userBalance.userId,
                              isPayments: false,
                            ),
                          )
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                DetailRow(
                  label: 'Payments',
                  value: '$payments',
                  onTap: payments > 0
                      ? () => _openExpenses(
                            context,
                            ExpensesView(
                              byId: userBalance.userId,
                              isPayments: true,
                            ),
                          )
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                DetailRow(
                  label: 'Benefits from',
                  value: '$benefits',
                  onTap: benefits > 0
                      ? () => _openExpenses(
                            context,
                            ExpensesView(userId: userBalance.userId),
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: shareStatement,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Share statement'),
            ),
          ),
        ],
      ),
    );
  }

  void _openExpenses(BuildContext context, Widget expensesView) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(
              userBalance.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: expensesView,
        ),
      ),
    );
  }
}
