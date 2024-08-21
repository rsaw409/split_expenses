import 'package:flutter/material.dart';
import 'package:split_expense/src/models/user_balance.dart';
import 'package:split_expense/src/views/expenses_view.dart';

class UserView extends StatelessWidget {
  const UserView({super.key, required this.groupId, required this.userBalance});

  final UserBalance userBalance;
  final int? groupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.person_2_outlined),
            title: Text(userBalance.name ?? ""),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Text("Balance"),
            trailing: Text('INR ${userBalance.balances ?? 0}'),
            onTap: () {},
          ),
          ListTile(
            leading: const Text("Expenses"),
            trailing: Text(userBalance.numberOfTransactions ?? ""),
            onTap: () {
              if (int.parse(userBalance.numberOfTransactions!) > 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => Scaffold(
                      appBar: AppBar(),
                      body: ExpensesView(
                        groupId: groupId,
                        byId: userBalance.userId,
                        isPayments: false,
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Text("Payments"),
            trailing: Text(userBalance.numberOfPayments ?? ""),
            onTap: () {
              if (int.parse(userBalance.numberOfPayments!) > 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => Scaffold(
                      appBar: AppBar(),
                      body: ExpensesView(
                        groupId: groupId,
                        byId: userBalance.userId,
                        isPayments: true,
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
              leading: const Text("Benefits from"),
              trailing: Text('${userBalance.numberOfBenefits}'),
              onTap: () => {
                    if (int.parse(userBalance.numberOfBenefits!) > 0)
                      {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => Scaffold(
                              appBar: AppBar(),
                              body: ExpensesView(
                                groupId: groupId,
                                userId: userBalance.userId,
                              ),
                            ),
                          ),
                        )
                      }
                  }),
        ],
      ),
    );
  }
}
