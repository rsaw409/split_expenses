import 'package:flutter/material.dart';
import 'package:split_expense/src/services/backend.dart';
import 'package:split_expense/src/views/single_expense_view.dart';

import '../models/expense/expense.dart';

class ExpensesView extends StatelessWidget {
  const ExpensesView(
      {super.key,
      required this.groupId,
      this.userId,
      this.byId,
      this.isPayments});

  final int? groupId;

  final int? userId, byId;

  final bool? isPayments;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: groupId == null
          ? Future.error(Exception('Please create or join a group'))
          : fetchExpenses(groupId, userId, byId, isPayments),
      builder: (context, snapshot) {
        // WHEN THE CALL IS DONE BUT HAPPENS TO HAVE AN ERROR
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        // WHILE THE CALL IS BEING MADE AKA LOADING
        if (!snapshot.hasData) {
          return const Center(child: Text('Loading'));
        }

        // IF IT WORKS IT GOES HERE!
        return ListView.separated(
          itemCount: snapshot.data?.length ?? 0,
          itemBuilder: (context, index) {
            Expense expense = snapshot.data![index];

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
                subtitle: Text(snapshot.data?[index].userName ?? ""),
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
        );
      },
    );
  }
}
