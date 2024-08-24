import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_expense/src/components/customchip.dart';

import '../models/user.dart';

void showAmountDistributionModal(
    BuildContext context,
    double totalAmount,
    List<User> userOptions,
    List<Map<String, dynamic>> selectedUsers,
    Function onSubmit) {
  List<Map<String, dynamic>> allUsers =
      userOptions.map((e) => e.toMap()).toList();

  showModalBottomSheet(
    isDismissible: true,
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return AmountDistributionModal(
        totalAmount: totalAmount,
        users: allUsers,
        selectedUsers: selectedUsers,
        onSubmitSelectedUser: onSubmit,
      );
    },
  );
}

class AmountDistributionModal extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> selectedUsers;
  final Function onSubmitSelectedUser;

  const AmountDistributionModal({
    super.key,
    required this.totalAmount,
    required this.users,
    required this.selectedUsers,
    required this.onSubmitSelectedUser,
  });

  @override
  State<AmountDistributionModal> createState() =>
      _AmountDistributionModalState();
}

class _AmountDistributionModalState extends State<AmountDistributionModal> {
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  List<Map<String, dynamic>> selectedUsers = [];

  @override
  void initState() {
    super.initState();
    selectedUsers = widget.selectedUsers;
    for (var user in selectedUsers) {
      user['controller'] = TextEditingController();
      user['controller'].text = user['amount'].round().toString();
    }
  }

  @override
  void dispose() {
    for (var user in selectedUsers) {
      user['controller']?.dispose();
    }
    super.dispose();
  }

  void onAmountChange(controller) {
    double totalAmount = widget.totalAmount;

    double totalClaimAmount = 0.0;
    for (var each in selectedUsers) {
      totalClaimAmount += double.tryParse(each['controller'].text) ?? 0;
    }

    if (totalClaimAmount > totalAmount) {
      double diff = totalClaimAmount - totalAmount;

      diff = (diff / (selectedUsers.length - 1));

      for (var each in selectedUsers) {
        if (each['controller'] != controller) {
          var oldValue = double.tryParse(each['controller'].text) ?? 0;

          each['controller'].text = (oldValue - diff).round().toString();
        }
      }
    } else if (totalClaimAmount < totalAmount) {
      double diff = totalAmount - totalClaimAmount;

      diff = (diff / (selectedUsers.length - 1));
      for (var each in selectedUsers) {
        if (each['controller'] != controller) {
          var oldValue = double.tryParse(each['controller'].text) ?? 0;
          each['controller'].text = (oldValue + diff).round().toString();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Distribute Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 16),
                    Column(
                      children: selectedUsers.map((user) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(user["name"]),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: user['controller'],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d+')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'INR',
                                    border: OutlineInputBorder(),
                                  ),
                                  onEditingComplete: () {
                                    onAmountChange(user['controller']);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter amount';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid number';
                                    }
                                    if (double.tryParse(value)! <= 0) {
                                      return 'Must be greater than zero';
                                    }
                                    if (double.tryParse(value)! >
                                        widget.totalAmount) {
                                      return 'Must be less the total amount';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    double total = 0;
                    for (var each in selectedUsers) {
                      total += double.tryParse(each['controller'].text)!;
                    }

                    if (total == widget.totalAmount) {
                      for (var each in selectedUsers) {
                        each['amount'] =
                            double.tryParse(each['controller'].text);

                        // each['controller']?.dispose();
                        // each.remove('controller');
                      }
                      widget.onSubmitSelectedUser(selectedUsers);
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        _errorMessage =
                            'Total distribution is ${total.round().toString()}. It must equal be ${widget.totalAmount}';
                      });
                    }
                  }
                },
                child: const Text('Done'),
              ),
              if (widget.users.isNotEmpty)
                ChipsChoice<Map<String, dynamic>>.multiple(
                  value: selectedUsers,
                  onChanged: (val) => setState(
                    () {
                      selectedUsers = val;
                      for (var user in selectedUsers) {
                        user['controller'] ??= TextEditingController();
                        user['controller'].text =
                            (widget.totalAmount / selectedUsers.length)
                                .round()
                                .toString();
                      }
                    },
                  ),
                  choiceItems: C2Choice.listFrom<Map<String, dynamic>,
                      Map<String, dynamic>>(
                    source: widget.users.map((e) => e).toList(),
                    value: (i, v) => v,
                    label: (i, v) => v['name'],
                  ),
                  choiceBuilder: (item, i) {
                    return CustomChip(
                      label: item.label,
                      radius: 35,
                      selected: item.selected,
                      onSelect: item.select!,
                    );
                  },
                )
            ],
          ),
        ),
      ),
    );
  }
}
