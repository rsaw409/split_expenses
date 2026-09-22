import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';

import '../components/async_state.dart';
import '../models/user_balance.dart';
import '../theme/app_theme.dart';
import '../utils/connectivity.dart';
import '../utils/currency.dart';
import '../utils/initials.dart';
import 'settle_view.dart';
import 'user_view.dart';

class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    UserBalanceController userBalancesController =
        context.watch<UserBalanceController>();

    if (userBalancesController.groupId == null) {
      return const EmptyStateView(
        icon: Icons.group_add_outlined,
        title: 'No group yet',
        subtitle: 'Join or create a group from the menu to get started.',
      );
    }

    if (userBalancesController.isLoading) {
      return const LoadingView();
    }

    if (userBalancesController.isError) {
      return ErrorView(
        message:
            userBalancesController.errorMessage ?? 'Something went wrong.',
        onRetry: userBalancesController.refresh,
      );
    }

    final List<UserBalance> userBalances = userBalancesController.userBalances;

    if (userBalances.isEmpty) {
      return const EmptyStateView(
        icon: Icons.groups_outlined,
        title: 'No balances yet',
        subtitle: 'Add an expense or payment to see who owes what.',
      );
    }

    return RefreshIndicator(
      onRefresh: userBalancesController.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.fabClearance,
        ),
        separatorBuilder: (context, index) => const Divider(indent: 72),
        itemCount: userBalances.length + 1,
        itemBuilder: (context, index) {
          if (index == userBalances.length) {
            return Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Center(
                child: FilledButton.tonalIcon(
                  // Disabled offline: settling up is a write, and selecting
                  // who pays whom only to fail at Save wastes real work.
                  onPressed: !watchIsOnline(context)
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  SettleView(userBalances: userBalances),
                            ),
                          );
                        },
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Settle up'),
                ),
              ),
            );
          }

          return _BalanceTile(balance: userBalances[index]);
        },
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance});

  final UserBalance balance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSettled = balance.balances == 0;
    final isOwed = balance.balances > 0;
    final amountColor = isSettled
        ? colorScheme.onSurfaceVariant
        : isOwed
            ? colorScheme.positive
            : colorScheme.error;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Text(initialsOf(balance.name)),
      ),
      title: Text(
        balance.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isSettled ? 'Settled up' : (isOwed ? 'Gets back' : 'Owes'),
      ),
      trailing: Text(
        formatCurrency(balance.balances.abs()),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => UserView(userBalance: balance),
          ),
        );
      },
    );
  }
}
