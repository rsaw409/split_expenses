import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/notify_controllers/userbalances_controller.dart';

import '../components/member_avatar.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';
import '../notify_controllers/groups_controller.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../utils/reachability.dart';

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

  /// The face the new person gets. Shuffled freely until saved; the backend
  /// has no way to change it after that.
  String _avatar = newAvatarSeed();

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
        await addUserInGroup(groupId, name, avatar: _avatar);

        userBalanceController.refresh();
        snackBar = SnackBar(
          content: Text('$name added in group.'),
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

    if (!requireReachable(context)) return;

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
                Center(child: SeedAvatar(seed: _avatar, radius: 48)),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() => _avatar = newAvatarSeed()),
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Change avatar'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
