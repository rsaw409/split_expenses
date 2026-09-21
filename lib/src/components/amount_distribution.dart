import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_expense/src/components/customchip.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

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

/// Splits [totalCents] into [count] shares that sum to exactly [totalCents].
/// Cents that don't divide evenly are handed one-by-one to the first few
/// shares, so at most a few participants carry an extra paisa/rupee instead
/// of the split silently failing to add up.
List<int> _splitCentsEqually(int totalCents, int count) {
  if (count <= 0) return const [];
  if (totalCents <= 0) return List.filled(count, 0);
  final base = totalCents ~/ count;
  final remainder = totalCents % count;
  return List.generate(count, (i) => base + (i < remainder ? 1 : 0));
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
      user['controller'].text =
          paiseToText(amountToPaise(user['amount'] as num));
    }
  }

  @override
  void dispose() {
    for (var user in selectedUsers) {
      user['controller']?.dispose();
    }
    super.dispose();
  }

  void onAmountChange(TextEditingController controller) {
    final editedCents = amountToPaise(double.tryParse(controller.text) ?? 0);
    controller.text = paiseToText(editedCents);

    final others = selectedUsers
        .where((each) => each['controller'] != controller)
        .toList();
    if (others.isEmpty) return;

    final remainingCents = amountToPaise(widget.totalAmount) - editedCents;
    final shares = _splitCentsEqually(remainingCents, others.length);

    for (var i = 0; i < others.length; i++) {
      others[i]['controller'].text = paiseToText(shares[i]);
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
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Split amount',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: selectedUsers.map((user) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user["name"],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  controller: user['controller'],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.end,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d+')),
                                  ],
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
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
              const SizedBox(height: AppSpacing.md),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final totalCents = amountToPaise(widget.totalAmount);
                    final enteredCents = [
                      for (final each in selectedUsers)
                        amountToPaise(double.parse(each['controller'].text)),
                    ];
                    final sumCents =
                        enteredCents.fold<int>(0, (a, b) => a + b);

                    if (sumCents == totalCents) {
                      for (var i = 0; i < selectedUsers.length; i++) {
                        selectedUsers[i]['amount'] = enteredCents[i] / 100;
                      }
                      widget.onSubmitSelectedUser(selectedUsers);
                      Navigator.pop(context);
                    } else {
                      final diffCents = totalCents - sumCents;
                      setState(() {
                        _errorMessage = diffCents > 0
                            ? '${paiseToText(diffCents)} left to distribute.'
                            : '${paiseToText(-diffCents)} over the total amount.';
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
                      final shares = _splitCentsEqually(
                        amountToPaise(widget.totalAmount),
                        selectedUsers.length,
                      );
                      for (var i = 0; i < selectedUsers.length; i++) {
                        final user = selectedUsers[i];
                        user['controller'] ??= TextEditingController();
                        user['controller'].text = paiseToText(shares[i]);
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
