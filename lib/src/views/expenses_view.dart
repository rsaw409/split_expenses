import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/services/api_exception.dart';
import 'package:split_expense/src/services/backend.dart';

import '../components/async_state.dart';
import '../components/expense_tile.dart';
import '../models/expense/expense.dart';
import '../notify_controllers/groups_controller.dart';

class ExpensesView extends StatelessWidget {
  const ExpensesView({super.key, this.userId, this.byId, this.isPayments});

  final int? userId, byId;

  final bool? isPayments;

  @override
  Widget build(BuildContext context) {
    final groupId = context.watch<GroupsController>().selectedGroup["id"];

    return FutureBuilder<List<Expense>>(
      future: groupId == null
          ? Future.error(const ApiException('Create or join a group first.'))
          : fetchExpenses(groupId, userId, byId, isPayments),
      builder: (context, AsyncSnapshot<List<Expense>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is ApiException
                ? error.message
                : 'Could not load expenses. Check your connection and try again.',
          );
        }

        final expenses = snapshot.data ?? [];

        if (expenses.isEmpty) {
          return const EmptyStateView(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses yet',
          );
        }

        return ListView.separated(
          itemCount: expenses.length,
          itemBuilder: (context, index) => ExpenseTile(expense: expenses[index]),
          separatorBuilder: (context, index) => const Divider(indent: 72),
        );
      },
    );
  }
}
