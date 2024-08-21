import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/amount_distribution.dart';
import '../services/backend.dart';

class NewExpense extends StatefulWidget {
  final int? groupId;

  const NewExpense({super.key, required this.groupId});

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {
  List<Map<String, dynamic>> userOptions = [];

  int? by;
  String? title;
  double? totalAmount;
  List<Map<String, dynamic>>? transactionParts;

  List<Map<String, dynamic>> selectedUsers = [];

  @override
  void initState() {
    super.initState();

    loadUser();
  }

  loadUser() async {
    List<Map<String, dynamic>>? tmp = await getUsersInGroup(widget.groupId);
    setState(() {
      userOptions = tmp;
    });
  }

  formIsValid() async {
    if (title == null || title!.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Expense title cannot be empty.')),
        );
      return;
    }
    if (by == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select who paid.')),
        );
      return;
    }

    if (totalAmount == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter expense amount.')),
        );
      return;
    }

    if (selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Please select persons to distribute expense.')),
        );
      return;
    }

    double total = 0;
    for (var user in selectedUsers) {
      total += user['amount'];
    }
    if (total != totalAmount) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Please distribute total expense correctly')),
        );
      return;
    }

    Map<String, dynamic> transaction = {};
    transaction['by'] = by;
    transaction['title'] = title;
    transaction['totalAmount'] = totalAmount;
    transaction['transactionParts'] = selectedUsers.map((each) {
      return {'user_id': each['id'], 'amount': each['amount']};
    }).toList();

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Saving Expense')),
      );

    saveTransaction(transaction).then((val) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Expense Saved.')),
        );
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
                const Text('Title'),
                const SizedBox(
                  width: 100,
                ),
                Expanded(
                  child: TextFormField(
                    onChanged: (value) => setState(() {
                      title = value;
                    }),
                    autofocus: true,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Expense Title',
                    ),
                  ),
                ),
              ],
            ),
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
                        totalAmount = double.tryParse(value);
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
            if (userOptions.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('By'),
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
                          if (newValue != null) by = int.tryParse(newValue);
                        });
                      },
                      focusColor: Colors.transparent,
                      // dropdownColor: Colors.white,
                      items: userOptions.map((user) {
                        return DropdownMenuItem(
                          value: "${user['id']}",
                          child: Container(
                            color: Colors.transparent,
                            child: Text(user['name']),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            if (userOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('For'),
                    const Expanded(
                      child: SizedBox(),
                    ),
                    TextButton(
                      onPressed: () {
                        showAmountDistributionModal(context, totalAmount ?? 0,
                            userOptions, selectedUsers, (val) {
                          setState(() {
                            selectedUsers = val;
                          });
                        });
                      },
                      child: Text(
                          '${selectedUsers.isEmpty ? userOptions.length : selectedUsers.length} persons'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
