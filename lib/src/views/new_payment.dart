import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/models/user.dart';

import '../services/backend.dart';
import '../settings/groups_controller.dart';

class NewPayment extends StatefulWidget {
  const NewPayment({super.key});

  @override
  State<NewPayment> createState() => _NewPaymentState();
}

class _NewPaymentState extends State<NewPayment> {
  List<User> userOptions = [];
  int? from;
  int? to;
  double? amount;

  void formIsValid() {
    if (amount == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter amount.')),
        );
      return;
    }
    if (from == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select who paid.')),
        );
      return;
    }

    if (to == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a receiver.')),
        );
      return;
    }

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Saving Payment.')),
      );

    Map<String, dynamic> payment = {"amount": amount, "from": from, "to": to};
    savePayment(payment).then((val) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Expense Saved.')),
        );

      context.watch<GroupsController>().refresh();
      Navigator.pop(context);
    }).catchError((error) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Something went wrong.')),
        );
    });
  }

  @override
  void initState() {
    super.initState();

    loadUser();
  }

  loadUser() async {
    final groupId = context.read<GroupsController>().selectedGroup['id'];
    List<User> tmp = await getUsersInGroup(groupId);
    setState(() {
      userOptions = tmp;
    });
  }

  List<User> getUserOptions({fromOption = false, toOptions = false}) {
    var copy = [...userOptions];

    if (fromOption) copy.removeWhere((each) => each.id == to);
    if (toOptions) copy.removeWhere((each) => each.id == from);

    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
              onPressed: formIsValid,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Text('SAVE'),
              ))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 50, right: 50),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount'),
                const SizedBox(
                  width: 100,
                ),
                Expanded(
                  child: TextFormField(
                    onChanged: (value) => {
                      setState(() {
                        amount = double.tryParse(value);
                      })
                    },
                    autofocus: true,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Expense Amount',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('From'),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                  child: DropdownButtonFormField(
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_downward),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        if (newValue != null) from = int.tryParse(newValue);
                      });
                    },
                    focusColor: Colors.transparent,
                    // dropdownColor: Colors.white,
                    items: getUserOptions(fromOption: true).map((user) {
                      return DropdownMenuItem(
                        value: "${user.id}",
                        child: Container(
                          color: Colors.transparent,
                          child: Text(user.name),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('To'),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                  child: DropdownButtonFormField(
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_downward),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        if (newValue != null) to = int.tryParse(newValue);
                      });
                    },
                    focusColor: Colors.transparent,
                    items: getUserOptions(toOptions: true).map((user) {
                      return DropdownMenuItem(
                        value: "${user.id}",
                        child: Container(
                          color: Colors.transparent,
                          child: Text(user.name),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
