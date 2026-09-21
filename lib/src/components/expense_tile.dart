import 'package:flutter/material.dart';

import '../models/expense/expense.dart';
import '../utils/currency.dart';
import '../views/single_expense_view.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPayment = expense.transactionTitle == 'payment';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Icon(
          isPayment ? Icons.sync_alt_rounded : Icons.shopping_bag_outlined,
        ),
      ),
      title: Text(
        isPayment ? 'From ${expense.userName}' : expense.transactionTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isPayment
            ? 'To ${expense.distributions[0].userName}'
            : expense.userName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatCurrency(expense.transactionAmount),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => SingleExpense(
              expense: expense,
              isPayment: isPayment,
            ),
          ),
        );
      },
    );
  }
}
