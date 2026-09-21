import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/amount_distribution.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../theme/app_theme.dart';

class NewExpense extends StatefulWidget {
  const NewExpense({super.key});

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {
  final _formKey = GlobalKey<FormState>();

  int? by;
  String? title;
  double? totalAmount;

  List<User> userOptions = [];
  List<Map<String, dynamic>> selectedUsers = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    loadUser();
  }

  Future<void> loadUser() async {
    final groupId = context.read<GroupsController>().selectedGroup["id"];
    List<User> tmp = await getUsersInGroup(groupId);
    if (!mounted) return;
    setState(() {
      userOptions = tmp;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
    // Compare in paise; summing rupee doubles can drift by a fraction of a
    // cent even when the underlying paise amounts add up exactly.
    if ((total - (totalAmount ?? 0)).abs() > 0.005) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Please distribute total expense correctly')),
        );
      return;
    }

    Map<String, dynamic> transaction = {};
    transaction['groupName'] =
        context.read<GroupsController>().selectedGroup["name"];
    transaction['by'] = by;
    transaction['title'] = title;
    transaction['totalAmount'] = totalAmount;
    transaction['transactionParts'] = selectedUsers.map((each) {
      return {'user_id': each['id'], 'amount': each['amount']};
    }).toList();

    setState(() => _isSaving = true);

    try {
      await saveTransaction(transaction);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Expense saved.')),
        );

      context.read<UserBalanceController>().refresh();
      context.read<AllExpenseController>().refresh();

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Could not save expense. Check your connection and try again.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New expense'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SAVE'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                onChanged: (value) => setState(() => title = value),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What was this expense for?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Expense title cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                onChanged: (value) => setState(() {
                  totalAmount = double.tryParse(value);
                }),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter expense amount.';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Enter a valid amount.';
                  }
                  return null;
                },
              ),
              if (userOptions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (newValue != null) by = int.tryParse(newValue);
                    });
                  },
                  items: userOptions.map((user) {
                    return DropdownMenuItem(
                      value: "${user.id}",
                      child: Text(user.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  validator: (_) =>
                      by == null ? 'Please select who paid.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: ListTile(
                    title: const Text('Split between'),
                    subtitle: Text(
                      '${selectedUsers.isEmpty ? userOptions.length : selectedUsers.length} people',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showAmountDistributionModal(context, totalAmount ?? 0,
                          userOptions, selectedUsers, (val) {
                        setState(() {
                          selectedUsers = val;
                        });
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
