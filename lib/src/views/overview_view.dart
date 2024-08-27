import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';
import '../models/user_balance.dart';
import 'settle_view.dart';
import 'user_view.dart';

class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    UserBalanceController userBalancesController =
        context.watch<UserBalanceController>();

    List<UserBalance> userBalances = userBalancesController.userBalances;
    bool isError = userBalancesController.isError;

    return isError
        ? const Center(child: Text('Please create or join group.'))
        : userBalances.isNotEmpty
            ? ListView.separated(
                separatorBuilder: (context, index) {
                  return const Divider(
                    indent: 50,
                  );
                },
                itemCount: userBalances.length + 1,
                itemBuilder: (context, index) {
                  if (index == userBalances.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Center(
                        child: Transform.scale(
                          scale: 1.2,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      SettleView(userBalances: userBalances),
                                ),
                              );
                            },
                            child: const Text('Settle up'),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return ListTile(
                      leading: const Icon(Icons.person_2_outlined),
                      title: Text(userBalances[index].name),
                      trailing: Text('INR ${userBalances[index].balances}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                UserView(userBalance: userBalances[index]),
                          ),
                        );
                      },
                    );
                  }
                },
              )
            : const SizedBox.shrink();
  }
}
