import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/groups_controller.dart';
import '../theme/app_theme.dart';
import '../views/new_expense.dart';
import '../views/new_form.dart';
import '../views/new_payment.dart';

const _heroTag = 'add-menu-fab';

/// The home screen's "+" button, which opens a menu of things to add.
///
/// The FAB itself is an ordinary, regular-size button and the menu is a
/// separate see-through route. This replaces flutter_expandable_fab, which
/// laid the closed FAB out full-screen so it could draw its own overlay:
/// Scaffold then placed floating snackbars above that "FAB", off the top of
/// the screen, so no snackbar on the home screen was ever visible.
class ExpandableFloatingActionButton extends StatelessWidget {
  const ExpandableFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: _heroTag,
      tooltip: 'Add',
      shape: const CircleBorder(),
      onPressed: () => Navigator.of(context).push(_AddMenuRoute()),
      child: const Icon(Icons.add),
    );
  }
}

class _AddMenuRoute extends PageRouteBuilder<void> {
  _AddMenuRoute()
      : super(
          opaque: false,
          barrierLabel: 'Close menu',
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (context, animation, _) =>
              _AddMenu(animation: animation),
        );
}

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.animation});

  final Animation<double> animation;

  /// Closes the menu first, so returning from the form lands on the home
  /// screen rather than back on the open menu.
  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (context.read<GroupsController>().selectedGroup['id'] == null) return;
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // A route has no Material of its own: without one the rows' InkWells
    // assert and the labels fall back to the unstyled red-underlined text.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: FadeTransition(
                opacity: animation,
                // Blur, not just a color scrim: `scrim` is a fixed near-black,
                // which barely darkens an already-dark background in dark mode,
                // so the list behind stays distractingly legible under the
                // menu. Blurring works the same regardless of theme brightness.
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: ColoredBox(
                    color: colorScheme.scrim.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          // Same margin as Scaffold's default endFloat location, so the close
          // button lands where the "+" was (the shared hero covers any gap).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _FabAction(
                              label: 'New expense',
                              subtitle: 'A purchase made for the group',
                              icon: Icons.shopping_bag_outlined,
                              onTap: () => _open(context, const NewExpense()),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _FabAction(
                              label: 'New payment',
                              subtitle: 'A payment made within the group',
                              icon: Icons.arrow_forward,
                              onTap: () => _open(context, const NewPayment()),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _FabAction(
                              label: 'New person',
                              subtitle: 'Somebody to split costs with',
                              icon: Icons.person_2_outlined,
                              onTap: () => _open(
                                context,
                                const NewForm(
                                  saveButtonText: 'Save person',
                                  textFieldLabel: 'Person Name',
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: _heroTag,
                      tooltip: 'Close menu',
                      shape: const CircleBorder(),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible so large system font sizes wrap instead of overflowing.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.end,
                    style: textTheme.bodyLarge,
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.end,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Aligns under the close button's centre: a small FAB (40) in a
            // regular FAB's column (56) is inset by 8 on each side.
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: onTap,
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: Icon(icon),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
