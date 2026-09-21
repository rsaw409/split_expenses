import 'package:flutter/material.dart';

/// Uses the classic Material glow overscroll indicator everywhere instead of
/// Material 3's default [StretchingOverscrollIndicator], which visibly warps
/// scrollable content — including text — when a user drags past a scroll
/// edge. The glow indicator only paints an overlay; it never transforms the
/// child, so it can't distort content the way stretch does.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return child;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return GlowingOverscrollIndicator(
          axisDirection: details.direction,
          color: Theme.of(context).colorScheme.primary,
          child: child,
        );
    }
  }
}
