import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/models/user.dart';

import '../services/api_exception.dart';
import '../services/backend.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../theme/app_theme.dart';
import '../utils/connectivity.dart';
import '../utils/idempotency.dart';

class NewPayment extends StatefulWidget {
  const NewPayment({super.key});

  @override
  State<NewPayment> createState() => _NewPaymentState();
}

class _NewPaymentState extends State<NewPayment> {
  final _formKey = GlobalKey<FormState>();
  final _idempotency = IdempotencyKey();

  List<User> userOptions = [];
  int? from;
  int? to;
  double? amount;
  bool _isSaving = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!requireOnline(context,
        message: "You're offline — connect to save this payment.")) {
      return;
    }

    Map<String, dynamic> payment = {
      "amount": amount,
      "from": from,
      "to": to,
      "groupName": context.read<GroupsController>().selectedGroup["name"]
    };

    setState(() => _isSaving = true);

    try {
      await savePayment(
        payment,
        idempotencyKey: _idempotency.forPayload(payment),
      );
      if (!mounted) return;
      _idempotency.reset();
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Payment saved.')),
        );

      context.read<UserBalanceController>().refresh();
      context.read<AllExpenseController>().refresh();

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // See new_expense.dart: no response means it may have committed, so
      // refresh instead of reporting a clean failure, and keep the key.
      final serverAnswered = error is ApiException;
      if (!serverAnswered) {
        context.read<UserBalanceController>().refresh();
        context.read<AllExpenseController>().refresh();
      }

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              serverAnswered ? error.message : unconfirmedWriteMessage,
            ),
          ),
        );
    }
  }

  @override
  void initState() {
    super.initState();

    loadUser();
  }

  Future<void> loadUser() async {
    final groupId = context.read<GroupsController>().selectedGroup['id'];
    List<User> tmp = await getUsersInGroup(groupId);
    if (!mounted) return;
    setState(() {
      userOptions = tmp;
    });
  }

  List<User> getUserOptions({bool fromOption = false, bool toOptions = false}) {
    var copy = [...userOptions];

    if (fromOption) copy.removeWhere((each) => each.id == to);
    if (toOptions) copy.removeWhere((each) => each.id == from);

    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New payment'),
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
                onChanged: (value) => setState(() {
                  amount = double.tryParse(value);
                }),
                autofocus: true,
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
                    return 'Please enter amount.';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Enter a valid amount.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'From'),
                onChanged: (String? newValue) {
                  setState(() {
                    if (newValue != null) from = int.tryParse(newValue);
                  });
                },
                items: getUserOptions(fromOption: true).map((user) {
                  return DropdownMenuItem(
                    value: "${user.id}",
                    child: Text(user.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                validator: (_) =>
                    from == null ? 'Please select who paid.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'To'),
                onChanged: (String? newValue) {
                  setState(() {
                    if (newValue != null) to = int.tryParse(newValue);
                  });
                },
                items: getUserOptions(toOptions: true).map((user) {
                  return DropdownMenuItem(
                    value: "${user.id}",
                    child: Text(user.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                validator: (_) =>
                    to == null ? 'Please select a receiver.' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
