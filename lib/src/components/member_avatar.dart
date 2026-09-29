import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

import '../utils/initials.dart';

/// A member's saved avatar, or their initials for members added before
/// avatars existed (the backend sends `avatar: null` for them).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.initialsStyle,
  });

  final String name;
  final String? avatar;
  final double radius;

  /// Styling for the initials; unused when there is an avatar.
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? initialsStyle;

  @override
  Widget build(BuildContext context) {
    final seed = avatar;
    if (seed != null) {
      return SeedAvatar(seed: seed, radius: radius, semanticsLabel: name);
    }
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colorScheme.secondaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onSecondaryContainer,
      child: Text(
        initialsOf(name),
        style: initialsStyle,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The face drawn from [seed], clipped to a circle.
class SeedAvatar extends StatelessWidget {
  const SeedAvatar({
    super.key,
    required this.seed,
    this.radius = 20,
    this.semanticsLabel,
  });

  final String seed;
  final double radius;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: RandomAvatar(
        seed,
        width: radius * 2,
        height: radius * 2,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
