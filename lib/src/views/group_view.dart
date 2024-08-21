import 'package:flutter/material.dart';
import 'package:split_expense/src/views/expenses_view.dart';
import 'package:split_expense/src/views/overview_view.dart';

class TabBarScreen extends StatelessWidget {
  const TabBarScreen({super.key, required this.groupId});

  final int? groupId;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: <Widget>[
        OverviewView(groupId: groupId),
        ExpensesView(groupId: groupId),
      ],
    );
  }
}
