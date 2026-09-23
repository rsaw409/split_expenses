import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/async_state.dart';
import '../components/expense_tile.dart';
import '../models/expense/expense.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../utils/expense_filters.dart';

/// A per-user slice of the group's transactions, filtered from the cached list
/// the group already loaded — no request of its own, so it works offline.
class ExpensesView extends StatelessWidget {
  const ExpensesView({super.key, this.userId, this.byId, this.isPayments});

  final int? userId, byId;

  final bool? isPayments;

  @override
  Widget build(BuildContext context) {
    final allExpenseController = context.watch<AllExpenseController>();

    if (allExpenseController.groupId == null) {
      return const EmptyStateView(
        icon: Icons.group_add_outlined,
        title: 'No group yet',
        subtitle: 'Join or create a group from the menu to get started.',
      );
    }

    if (allExpenseController.isLoading) {
      return const LoadingView();
    }

    if (allExpenseController.isError) {
      return ErrorView(
        message: allExpenseController.errorMessage ?? 'Something went wrong.',
        onRetry: allExpenseController.refresh,
      );
    }

    final List<Expense> expenses = filterExpenses(
      allExpenseController.expenses,
      userId: userId,
      byId: byId,
      isPayments: isPayments,
    );

    if (expenses.isEmpty) {
      return const EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
      );
    }

    return RefreshIndicator(
      onRefresh: allExpenseController.refresh,
      child: ListView.separated(
        itemCount: expenses.length,
        itemBuilder: (context, index) => ExpenseTile(expense: expenses[index]),
        separatorBuilder: (context, index) => const Divider(indent: 72),
      ),
    );
  }
}
