import 'package:flutter/material.dart';

import '../models/expense/expense.dart';
import '../utils/currency.dart';
import '../utils/expense_filters.dart';
import '../views/single_expense_view.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaymentTile = isPayment(expense);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Icon(
          isPaymentTile ? Icons.sync_alt_rounded : Icons.shopping_bag_outlined,
        ),
      ),
      title: Text(
        isPaymentTile ? 'From ${expense.userName}' : expense.transactionTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isPaymentTile
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
              isPayment: isPaymentTile,
            ),
          ),
        );
      },
    );
  }
}
