import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../services/api_exception.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/idempotency.dart';
import '../utils/initials.dart';
import '../utils/reachability.dart';

/// Currencies a group can be created in. Only rupees for now: every amount
/// in the app is paise, and formatting assumes ₹. The backend accepts any
/// three-letter code, so this list is what actually restricts the choice.
const _currencies = [(code: 'INR', label: 'Indian Rupee (₹)')];

/// A split needs someone to split with.
const minimumPeople = 2;

/// Creates a group together with its first members, in one request the
/// server applies atomically. The request carries an idempotency key scoped
/// to this form, so retrying after a timeout returns the group already made
/// instead of creating a second one.
class CreateGroupView extends StatefulWidget {
  const CreateGroupView({super.key});

  @override
  State<CreateGroupView> createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<CreateGroupView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _personController = TextEditingController();
  final _personFocus = FocusNode();

  final List<String> _people = [];
  String _currency = _currencies.first.code;
  String? _peopleError;
  bool _isSaving = false;
  final _idempotency = IdempotencyKey();

  @override
  void dispose() {
    _nameController.dispose();
    _personController.dispose();
    _personFocus.dispose();
    super.dispose();
  }

  void _addPerson() {
    final name = _personController.text.trim();
    if (name.isEmpty) return;

    final duplicate =
        _people.any((p) => p.toLowerCase() == name.toLowerCase());
    setState(() {
      if (duplicate) {
        _peopleError = '$name is already in the list.';
      } else {
        _people.add(name);
        _peopleError = null;
        _personController.clear();
      }
    });
    // Keep the keyboard up so several names can be typed in a row.
    _personFocus.requestFocus();
  }

  void _removePerson(String name) {
    setState(() => _people.remove(name));
  }

  bool _validate() {
    // A name still sitting in the field is almost certainly meant to count.
    if (_personController.text.trim().isNotEmpty) {
      _addPerson();
      // Still there means it was refused (a duplicate); stop so the error is
      // seen rather than the name silently dropped.
      if (_personController.text.trim().isNotEmpty) return false;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    final enoughPeople = _people.length >= minimumPeople;
    setState(() {
      _peopleError = enoughPeople
          ? null
          : 'Add at least $minimumPeople people to split with.';
    });
    return formValid && enoughPeople;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    if (!requireReachable(context)) return;

    final groupsController = context.read<GroupsController>();
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final members = List.of(_people);
      final group = await createGroup(
        name: name,
        currency: _currency,
        members: members,
        idempotencyKey: _idempotency.forPayload(
          {'name': name, 'currency': _currency, 'members': members},
        ),
      );
      _idempotency.reset();

      await groupsController.saveGroups(group);
      if (!mounted) return;

      context.read<UserBalanceController>().refresh();
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Created ${group.name}.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // No response means it may have been created; the key makes tapping
      // Create again safe, as long as nothing is edited first.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.message
              : "Couldn't reach Split. Try again — it won't create the "
                  'group twice.'),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
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
                child: const Icon(Icons.group_add_outlined, size: 32),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. Goa Trip',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the group a name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Currency',
                prefixIcon: Icon(Icons.currency_rupee),
                helperText: 'More currencies coming soon.',
              ),
              items: [
                for (final c in _currencies)
                  DropdownMenuItem(
                    value: c.code,
                    child: Text(c.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _currencies.length < 2
                  ? null
                  : (value) => setState(() => _currency = value!),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('People', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Everyone who will share costs, including you.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _personController,
              focusNode: _personFocus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addPerson(),
              onChanged: (_) {
                if (_peopleError != null) setState(() => _peopleError = null);
              },
              decoration: InputDecoration(
                labelText: 'Add a person',
                prefixIcon: const Icon(Icons.person_add_alt_outlined),
                errorText: _peopleError,
                suffixIcon: IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addPerson,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in _people)
                  InputChip(
                    avatar: CircleAvatar(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      child: Text(
                        initialsOf(name),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    label: Text(name),
                    onDeleted: _isSaving ? null : () => _removePerson(name),
                  ),
              ],
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
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create group'),
          ),
        ),
      ),
    );
  }
}
