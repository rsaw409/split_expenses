import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/groups_controller.dart';
import '../services/api_exception.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/invite_link.dart';
import '../utils/reachability.dart';

/// Joins a group from an invite code — or the invite link itself, which is
/// what people are usually sent, so either can be pasted.
///
/// Joining needs no idempotency key: joining a group you are already in just
/// returns it again, so a retry after a timeout is harmless.
class JoinGroupView extends StatefulWidget {
  const JoinGroupView({super.key});

  @override
  State<JoinGroupView> createState() => _JoinGroupViewState();
}

class _JoinGroupViewState extends State<JoinGroupView> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    _controller.text = text;
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!requireReachable(context)) return;

    final inviteId = inviteIdFromInput(_controller.text)!;
    final groupsController = context.read<GroupsController>();
    setState(() => _isSaving = true);

    try {
      final group = await joinGroupFromInviteId(inviteId);
      final alreadyIn =
          groupsController.groups.any((g) => g['id'] == group.id);
      await groupsController.saveGroups(group);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(alreadyIn
              ? "You're already in ${group.name}."
              : 'Joined ${group.name}.'),
        ));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join group')),
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
                child: const Icon(Icons.qr_code_outlined, size: 32),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Paste the invite link or code someone shared with you.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _controller,
              autofocus: true,
              enabled: !_isSaving,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Invite link or code',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste_outlined),
                  onPressed: _isSaving ? null : _paste,
                ),
              ),
              validator: (value) => inviteIdFromInput(value ?? '') == null
                  ? 'Enter an invite link or code.'
                  : null,
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
                : const Text('Join group'),
          ),
        ),
      ),
    );
  }
}
