import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/group_icon.dart';
import '../utils/initials.dart';

/// A group's emoji on its colour, or its initials for groups from before
/// icons existed.
class GroupIconAvatar extends StatelessWidget {
  const GroupIconAvatar({
    super.key,
    required this.name,
    this.icon,
    this.radius = 20,
    this.initialsBackground,
    this.initialsForeground,
  });

  final String name;
  final GroupIcon? icon;
  final double radius;

  /// Colours for the initials; unused when there is an icon.
  final Color? initialsBackground;
  final Color? initialsForeground;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) {
      final colorScheme = Theme.of(context).colorScheme;
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            initialsBackground ?? colorScheme.surfaceContainerHighest,
        foregroundColor: initialsForeground ?? colorScheme.onSurfaceVariant,
        child: Text(initialsOf(name)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          groupIconColorFor(icon.color).resolve(Theme.of(context).brightness),
      child: Text(
        icon.emoji,
        style: TextStyle(fontSize: radius, height: 1.15),
        semanticsLabel: '$name icon',
      ),
    );
  }
}

/// The large icon at the top of the create and edit forms, with a button to
/// change it. Tapping either opens [showGroupIconPicker].
class GroupIconField extends StatelessWidget {
  const GroupIconField({
    super.key,
    required this.name,
    required this.icon,
    required this.onChanged,
    this.enabled = true,
  });

  final String name;
  final GroupIcon? icon;
  final ValueChanged<GroupIcon> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final picked = await showGroupIconPicker(context, current: icon);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkResponse(
          onTap: enabled ? () => _pick(context) : null,
          radius: 44,
          child: GroupIconAvatar(name: name, icon: icon, radius: 40),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: enabled ? () => _pick(context) : null,
          icon: const Icon(Icons.autorenew),
          label: Text(icon == null ? 'Add icon' : 'Change icon'),
        ),
      ],
    );
  }
}

/// Lets the user choose an emoji and a colour. Returns null if dismissed.
Future<GroupIcon?> showGroupIconPicker(
  BuildContext context, {
  GroupIcon? current,
}) {
  return showModalBottomSheet<GroupIcon>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GroupIconPicker(initial: current ?? randomGroupIcon()),
  );
}

class _GroupIconPicker extends StatefulWidget {
  const _GroupIconPicker({required this.initial});

  final GroupIcon initial;

  @override
  State<_GroupIconPicker> createState() => _GroupIconPickerState();
}

class _GroupIconPickerState extends State<_GroupIconPicker> {
  late GroupIcon _icon = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final background = groupIconColorFor(_icon.color).resolve(brightness);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: GroupIconAvatar(name: '', icon: _icon, radius: 36)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final color in groupIconColors)
                  _Swatch(
                    color: color.resolve(brightness),
                    label: color.key,
                    selected: color.key == _icon.color,
                    onTap: () => setState(
                      () => _icon = (emoji: _icon.emoji, color: color.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final emoji in groupIconEmoji)
                  InkResponse(
                    onTap: () => setState(
                      () => _icon = (emoji: emoji, color: _icon.color),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: emoji == _icon.emoji ? background : null,
                        border: emoji == _icon.emoji
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  // Returns null, so the form keeps the icon it had.
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _icon),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected ? colorScheme.primary : colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
