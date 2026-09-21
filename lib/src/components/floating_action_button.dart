import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/groups_controller.dart';
import '../theme/app_theme.dart';
import '../views/new_expense.dart';
import '../views/new_form.dart';
import '../views/new_payment.dart';

class ExpandableFloatingActionButton extends StatelessWidget {
  ExpandableFloatingActionButton({
    super.key,
  });

  final _key = GlobalKey<ExpandableFabState>();

  void _push(BuildContext context, Widget page) {
    if (context.read<GroupsController>().selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => page),
    ).then((_) {
      _key.currentState?.toggle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpandableFab(
      key: _key,
      openButtonBuilder: RotateFloatingActionButtonBuilder(
        child: const Icon(Icons.add),
        fabSize: ExpandableFabSize.regular,
        shape: const CircleBorder(),
      ),
      type: ExpandableFabType.up,
      childrenAnimation: ExpandableFabAnimation.none,
      distance: 70,
      overlayStyle: ExpandableFabOverlayStyle(
        // Blur, not just a color scrim: `scrim` is a fixed near-black, which
        // barely darkens an already-dark background in dark mode, so the
        // list content behind stays distractingly legible under the menu.
        // Blurring works the same regardless of theme brightness.
        color: colorScheme.scrim.withValues(alpha: 0.3),
        blur: 4,
      ),
      children: [
        _FabAction(
          label: 'New person',
          subtitle: 'Somebody to split costs with',
          icon: Icons.person_2_outlined,
          onTap: () => _push(
            context,
            const NewForm(
              saveButtonText: 'Save person',
              textFieldLabel: 'Person Name',
            ),
          ),
        ),
        _FabAction(
          label: 'New payment',
          subtitle: 'A payment made within the group',
          icon: Icons.arrow_forward,
          onTap: () => _push(context, const NewPayment()),
        ),
        _FabAction(
          label: 'New expense',
          subtitle: 'A purchase made for the group',
          icon: Icons.shopping_bag_outlined,
          onTap: () => _push(context, const NewExpense()),
        ),
      ],
    );
  }
}

class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: textTheme.bodyLarge),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            FloatingActionButton.small(
              heroTag: null,
              onPressed: null,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }
}
