import 'package:flutter/material.dart';

import 'member_avatar.dart';

class CustomChip extends StatelessWidget {
  const CustomChip({
    super.key,
    required this.label,
    this.avatar,
    required this.radius,
    required this.selected,
    required this.onSelect,
    this.margin = const EdgeInsets.all(8.0),
  });

  final String label;
  final String? avatar;
  final double radius;
  final bool selected;
  final Function onSelect;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onSelect(!selected),
      child: Container(
        margin: margin,
        constraints: BoxConstraints(maxWidth: radius * 2.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: colorScheme.primary, width: 2.5)
                    : null,
              ),
              // Unselected faces are faded so the selection reads at a
              // glance; initials show it with their colours instead.
              child: Opacity(
                opacity: selected || avatar == null ? 1 : 0.45,
                child: MemberAvatar(
                  name: label,
                  avatar: avatar,
                  radius: radius,
                  backgroundColor: selected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  initialsStyle: TextStyle(
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? colorScheme.primary : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
