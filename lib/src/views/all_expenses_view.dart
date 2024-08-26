import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/views/single_expense_view.dart';

import '../models/expense/expense.dart';
import '../settings/allexpense_controller.dart';

class AllExpensesView extends StatelessWidget {
  const AllExpensesView({super.key});

  @override
  Widget build(BuildContext context) {
    AllExpenseController allExpenseController =
        context.watch<AllExpenseController>();

    List<Expense> expenses = allExpenseController.expenses;
    bool isError = allExpenseController.isError;

    return isError
        ? const Center(child: Text('Please create or join group.'))
        : expenses.isNotEmpty
            ? ListView.separated(
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  Expense expense = expenses[index];

                  if (expense.transactionTitle == 'payment') {
                    return ListTile(
                      leading: const Icon(Icons.arrow_forward),
                      title: Text('From ${expense.userName}'),
                      subtitle: Text('To ${expense.distributions[0].userName}'),
                      trailing: Text('INR ${expense.transactionAmount}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => SingleExpense(
                              expense: expense,
                              isPayment: true,
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    return ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined),
                      title: Text(expense.transactionTitle),
                      subtitle: Text(expenses[index].userName),
                      trailing: Text('INR ${expense.transactionAmount}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => SingleExpense(
                              expense: expense,
                              isPayment: false,
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
                separatorBuilder: (context, index) {
                  return const Divider(
                    indent: 50,
                  );
                },
              )
            : const SizedBox.shrink();
  }
}
