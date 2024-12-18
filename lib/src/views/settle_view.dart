import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';

import '../models/user_balance.dart';
import '../services/backend.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/userbalances_controller.dart';

class SettleView extends StatefulWidget {
  const SettleView({super.key, required this.userBalances});

  final List<UserBalance> userBalances;

  @override
  State<SettleView> createState() => _SettleViewState();
}

class _SettleViewState extends State<SettleView> {
  List<Map<String, dynamic>> payments = [];

  @override
  void initState() {
    super.initState();

    final userBalances = widget.userBalances.map((e) => e.toMap());

    List<Map<String, dynamic>> positive =
        userBalances.where((e) => e['balances'] > 0).toList();
    positive.sort((a, b) => b['balances'] - a['balances']);

    List<Map<String, dynamic>> negative =
        userBalances.where((e) => e['balances'] < 0).toList();
    negative.sort((a, b) => a['balances'] - b['balances']);

    int i = 0;
    int j = 0;

    while (i < negative.length) {
      if (negative[i]['balances'] < 0) {
        while (j < positive.length) {
          int maximumPayment =
              min(positive[j]['balances'], -negative[i]['balances']);

          payments.add({
            'from': negative[i]['user_id'],
            'fromName': negative[i]['name'],
            'to': positive[j]['user_id'],
            'toName': positive[j]['name'],
            'amount': maximumPayment,
            'selected': false,
            'groupName': context.read<GroupsController>().selectedGroup["name"]
          });

          negative[i]['balances'] += maximumPayment;
          positive[j]['balances'] -= maximumPayment;

          if (negative[i]['balances'] == 0) break;
          if (positive[j]['balances'] == 0) {
            j += 1;
            continue;
          }

          j += 1;
        }
      }

      i += 1;
    }
  }

  _savePayments(BuildContext context) {
    payments = payments.where((e) => e['selected']).toList();
    savePayments(payments).then((val) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Expense Saved.')),
        );

      context.read<UserBalanceController>().refresh();
      context.read<AllExpenseController>().refresh();

      Navigator.pop(context);
    }).catchError((error) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Failed to save expense.')),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (payments.any((e) => e['selected']))
            TextButton(
              onPressed: () => _savePayments(context),
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Text('Save payments'),
              ),
            )
        ],
      ),
      body: payments.isEmpty
          ? Center(
              child: FractionallySizedBox(
                widthFactor: 0.5, // 50% of the parent's width
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    "assets/images/allSettle.webp",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          : ListView.separated(
              separatorBuilder: (context, index) {
                return const Divider(
                  indent: 50,
                );
              },
              itemCount: payments.length,
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('From ${payments[index]['fromName']}'),
                  subtitle: Text('To ${payments[index]['toName']}'),
                  secondary: Text('INR ${payments[index]['amount']}'),
                  onChanged: (val) {
                    setState(() {
                      payments[index]['selected'] =
                          !payments[index]['selected'];
                    });
                  },
                  value: payments[index]['selected'],
                );
              },
            ),
    );
  }
}
