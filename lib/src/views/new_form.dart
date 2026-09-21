import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/connectivity_check.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';

import '../models/group.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';
import '../services/group_service.dart';
import '../notify_controllers/groups_controller.dart';
import '../theme/app_theme.dart';

class NewForm extends StatefulWidget {
  const NewForm({
    super.key,
    required this.saveButtonText,
    required this.textFieldLabel,
    this.inviteId,
  });

  final String saveButtonText;
  final String textFieldLabel;

  final String? inviteId;

  @override
  State<NewForm> createState() => _NewFormState();
}

class _NewFormState extends State<NewForm> {
  late final TextEditingController myController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    myController = TextEditingController(text: widget.inviteId);
  }

  @override
  void dispose() {
    myController.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.saveButtonText) {
        'Join Group' => Icons.qr_code_outlined,
        'Create Group' => Icons.group_add_outlined,
        _ => Icons.person_add_alt_outlined,
      };

  Future<bool> _saveTextFieldValue(
    BuildContext context,
    GroupsController groupsController,
    UserBalanceController userBalanceController,
  ) async {
    try {
      SnackBar snackBar = const SnackBar(content: Text('No action performed.'));

      if (widget.saveButtonText == 'Save person') {
        final groupId = groupsController.selectedGroup['id'];
        final name = myController.text.trim();
        await addUserInGroup(groupId, name);

        userBalanceController.refresh();
        snackBar = SnackBar(
          content: Text('$name added in group.'),
        );
      } else if (widget.saveButtonText == 'Join Group') {
        Group group = await joinGroupFromInviteId(myController.text.trim());
        await groupsController.saveGroups(group);
        snackBar = SnackBar(
          content: Text(
              'Successfully joined ${groupsController.selectedGroup["name"]}.'),
        );
      } else if (widget.saveButtonText == 'Create Group') {
        Group group = await createGroup(myController.text.trim());
        await groupsController.saveGroups(group);
        snackBar = SnackBar(
          content: Text(
              'Successfully create group: ${groupsController.selectedGroup["name"]}.'),
        );
      }

      if (!context.mounted) return false;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(snackBar);

      return true;
    } catch (error) {
      final snackBar = SnackBar(
        content: Text(
          error is ApiException
              ? error.message
              : 'Could not complete this. Check your connection and try again.',
        ),
      );

      if (!context.mounted) return false;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(snackBar);
      return false;
    }
  }

  void _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isConnectedToInternet =
        context.read<InternetConnectivityHelper>().isConnectedToInternet;
    if (!isConnectedToInternet) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No Internet')),
        );
      return;
    }

    final groupsController = context.read<GroupsController>();
    final userBalanceController = context.read<UserBalanceController>();

    setState(() => _isSaving = true);

    final isSuccess = await _saveTextFieldValue(
      context,
      groupsController,
      userBalanceController,
    );

    if (!context.mounted) return;
    if (isSuccess) {
      Navigator.pop(context);
    } else {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: _isSaving ? null : () => _submit(context),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.saveButtonText),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    child: Icon(_icon, size: 32),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: myController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(context),
                  decoration: InputDecoration(
                    labelText: widget.textFieldLabel,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field cannot be empty.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
