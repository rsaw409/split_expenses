import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/async_state.dart';
import '../components/expense_tile.dart';
import '../models/expense/expense.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../theme/app_theme.dart';

class AllExpensesView extends StatelessWidget {
  const AllExpensesView({super.key});

  @override
  Widget build(BuildContext context) {
    AllExpenseController allExpenseController =
        context.watch<AllExpenseController>();

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
        message:
            allExpenseController.errorMessage ?? 'Something went wrong.',
        onRetry: allExpenseController.refresh,
      );
    }

    final List<Expense> expenses = allExpenseController.expenses;

    if (expenses.isEmpty) {
      return const EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
        subtitle: 'Expenses and payments you record will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: allExpenseController.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.fabClearance),
        itemCount: expenses.length,
        itemBuilder: (context, index) => ExpenseTile(expense: expenses[index]),
        separatorBuilder: (context, index) => const Divider(indent: 72),
      ),
    );
  }
}
