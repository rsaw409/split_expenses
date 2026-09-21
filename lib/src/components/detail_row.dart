import 'package:flutter/material.dart';

/// A label/value row for detail screens — semantically a label+value pair,
/// unlike the app's previous misuse of [ListTile.leading] for labels.
///
/// Built on a plain [Row] rather than [ListTile] so [value] can take an
/// [Expanded] share of the width: [ListTile.trailing] sizes to its own
/// intrinsic width instead of being bounded by the row, so a long value (a
/// long name) would overflow rather than truncate. A fixed pixel cap isn't
/// right either — it would clip legitimately long-but-fixed-length values
/// like a formatted date. [value] allows up to two lines before ellipsizing,
/// since even the `Expanded` space runs out for a full date at very large
/// accessibility text-scale settings.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  style: textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
