import 'package:flutter/material.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/views/expenses_view.dart';

import '../components/detail_row.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

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

    final transactions = int.tryParse(userBalance.numberOfTransactions) ?? 0;
    final payments = int.tryParse(userBalance.numberOfPayments) ?? 0;
    final benefits = int.tryParse(userBalance.numberOfBenefits) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userBalance.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: const Icon(Icons.person_2_outlined),
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
              formatCurrency(userBalance.balances.abs()),
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
