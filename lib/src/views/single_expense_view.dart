import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense/expense.dart';

class SingleExpense extends StatelessWidget {
  const SingleExpense(
      {super.key, required this.expense, required this.isPayment});

  final Expense expense;
  final bool isPayment;

  getPercentage(int? amount) {
    double percentage = (amount! * 100) / expense.transactionAmount;
    return '${percentage.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ListTile(
            leading: Icon(
                isPayment ? Icons.arrow_forward : Icons.shopping_bag_outlined),
            title: Text(expense.transactionTitle),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Text("Amount"),
            trailing: Text('INR ${expense.transactionAmount}'),
            onTap: () {},
          ),
          ListTile(
            leading: Text(isPayment ? 'From' : "By"),
            trailing: Text(expense.userName),
            onTap: () {},
          ),
          ListTile(
            leading: Text(isPayment ? 'To' : "For"),
            trailing: Text(isPayment
                ? '${expense.distributions[0].userName}'
                : '${expense.distributions.length} persons'),
            onTap: () => isPayment
                ? null
                : showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...expense.distributions.map(
                            (each) => ListTile(
                                title: Text('${each.userName}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(getPercentage(each.amount)),
                                    const Text("  "),
                                    Text('INR ${each.amount}')
                                  ],
                                )),
                          )
                        ],
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'OK'),
                          child: const Text('DONE'),
                        ),
                      ],
                    ),
                  ),
          ),
          const Divider(),
          ListTile(
            leading: Text(isPayment ? 'Payment on' : "Purchases on"),
            trailing: Text(DateFormat('dd-MMM-yyyy hh:mm a').format(
              expense.transactionDate.toLocal(),
            )),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
