import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/member_avatar.dart';
import '../models/user_balance.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../utils/reachability.dart';

/// Renames a member or changes their avatar: the add-person form, filled in
/// with what they have now. Other members' apps pick the change up the next
/// time they load the group.
class EditMemberView extends StatefulWidget {
  const EditMemberView({super.key, required this.member});

  final UserBalance member;

  @override
  State<EditMemberView> createState() => _EditMemberViewState();
}

class _EditMemberViewState extends State<EditMemberView> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.member.name);

  /// Null until shuffled for a member added before avatars existed, who keeps
  /// their initials unless given one here.
  late String? _avatar = widget.member.avatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Rebuild on typing, so Save enables only once something has changed.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();
  bool get _nameChanged => _name != widget.member.name;
  bool get _avatarChanged => _avatar != widget.member.avatar;
  bool get _hasChanges => _nameChanged || _avatarChanged;

  /// The backend refuses a name another member of the group already has, in
  /// any case; checking here saves the round trip.
  bool _isTakenByAnother(String name) => context
      .read<UserBalanceController>()
      .userBalances
      .any((b) =>
          b.userId != widget.member.userId &&
          b.name.toLowerCase() == name.toLowerCase());

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!requireReachable(context)) return;

    // Expenses carry names too, so a rename needs both lists refreshed.
    final expenses = context.read<AllExpenseController>();
    final balances = context.read<UserBalanceController>();
    Future<void> refreshBoth() =>
        Future.wait([expenses.refresh(), balances.refresh()]);

    setState(() => _isSaving = true);

    try {
      // Only what changed: the backend refuses a request with neither.
      await updateUser(
        widget.member.userId,
        name: _nameChanged ? _name : null,
        avatar: _avatarChanged ? _avatar : null,
      );
      // Waits, so the member's page shows the change as soon as it is back.
      await refreshBoth();
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Person updated.')));
      Navigator.pop(context);
    } catch (error) {
      // With no response the change may still have landed; show it if so.
      if (error is! ApiException) refreshBoth();
      if (!mounted) return;
      setState(() => _isSaving = false);
      // Retrying is safe even if this did land: it sets the same values.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.message
              : "Couldn't reach Split. Check your connection and try again."),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit person'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: _isSaving || !_hasChanges ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
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
                  child: MemberAvatar(
                    name: _name.isEmpty ? widget.member.name : _name,
                    avatar: _avatar,
                    radius: 48,
                    initialsStyle: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
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
                  controller: _nameController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_hasChanges) _save();
                  },
                  decoration: const InputDecoration(labelText: 'Person Name'),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'This field cannot be empty.';
                    if (_isTakenByAnother(name)) {
                      return 'Someone in this group already has this name.';
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
