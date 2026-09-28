import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/currency_field.dart';
import '../models/group.dart';
import '../notify_controllers/groups_controller.dart';
import '../services/api_exception.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/reachability.dart';

/// Longest group name the form accepts. The backend sets no limit, but a
/// name longer than this no longer fits in the app bar or the drawer.
const maxGroupNameLength = 50;

/// Renames a group or changes its currency. Other members' apps pick the
/// change up the next time they start.
class EditGroupView extends StatefulWidget {
  const EditGroupView({super.key, required this.group});

  final Group group;

  @override
  State<EditGroupView> createState() => _EditGroupViewState();
}

class _EditGroupViewState extends State<EditGroupView> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.group.name);
  late String _currency = widget.group.currency;
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
  bool get _nameChanged => _name != widget.group.name;
  bool get _currencyChanged => _currency != widget.group.currency;
  bool get _hasChanges => _nameChanged || _currencyChanged;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!requireReachable(context)) return;

    final groupsController = context.read<GroupsController>();
    setState(() => _isSaving = true);

    try {
      // Only what changed: the backend refuses a request with neither.
      final updated = await updateGroup(
        widget.group.id,
        name: _nameChanged ? _name : null,
        currency: _currencyChanged ? _currency : null,
      );
      groupsController.applyServerGroups([updated]);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Group updated.')));
      Navigator.pop(context);
    } catch (error) {
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.edit_outlined, size: 32),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              enabled: !_isSaving,
              maxLength: maxGroupNameLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_hasChanges) _save();
              },
              decoration: const InputDecoration(
                labelText: 'Group name',
                prefixIcon: Icon(Icons.group_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the group a name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            CurrencyField(
              value: _currency,
              enabled: !_isSaving,
              onChanged: (code) => setState(() => _currency = code),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _isSaving || !_hasChanges ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ),
      ),
    );
  }
}
