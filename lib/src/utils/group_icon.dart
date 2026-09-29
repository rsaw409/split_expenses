import 'dart:math';

import 'package:flutter/material.dart';

/// A group's icon: an emoji on a coloured circle. Saved by the backend as
/// `icon` and `icon_color`, always together; groups from before icons have
/// neither and show their initials.
typedef GroupIcon = ({String emoji, String color});

/// The emoji offered for a group. All are from Emoji 11 or earlier, so none
/// render as an empty box on older Android versions; the backend accepts any
/// emoji, so this list can grow without a server change.
const groupIconEmoji = [
  '✈️', '🏖️', '🏔️', '⛺', '🚗', '🚆', '🗺️', '🌍', //
  '🏠', '🏡', '🛋️', '🏨', '💡', '🛒', '🐶', '🐱', //
  '🍕', '🍔', '🍜', '🍣', '☕', '🍻', '🍷', '🎂', //
  '🎉', '🎁', '🎄', '🎬', '🎮', '🎵', '🎭', '📸', //
  '⚽', '🏏', '🏸', '🚴', '💼', '🎓', '📚', '💰', //
];

/// A background colour for group icons, stored by [key] rather than value so
/// each theme can use its own shade.
class GroupIconColor {
  const GroupIconColor(this.key, this.light, this.dark);

  final String key;
  final Color light;
  final Color dark;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Soft backgrounds, so the emoji's own colours stay readable on top.
const groupIconColors = [
  GroupIconColor('purple', Color(0xFFE9DDFF), Color(0xFF4A3A70)),
  GroupIconColor('blue', Color(0xFFD6E3FF), Color(0xFF2B4677)),
  GroupIconColor('teal', Color(0xFFC8F0EA), Color(0xFF1F5750)),
  GroupIconColor('green', Color(0xFFD5EDC8), Color(0xFF34542A)),
  GroupIconColor('amber', Color(0xFFFFE8B3), Color(0xFF6B5117)),
  GroupIconColor('orange', Color(0xFFFFDCC6), Color(0xFF703C1E)),
  GroupIconColor('red', Color(0xFFFFD9D6), Color(0xFF73312D)),
  GroupIconColor('pink', Color(0xFFFFD8EC), Color(0xFF6E2F52)),
  GroupIconColor('grey', Color(0xFFE3E2E6), Color(0xFF46464F)),
];

/// The colour saved as [key], or the first one for a key this build doesn't
/// know (one added by a newer app version).
GroupIconColor groupIconColorFor(String? key) => groupIconColors.firstWhere(
      (c) => c.key == key,
      orElse: () => groupIconColors.first,
    );

/// The icon in a group's JSON (as the API sends it and the app saves it), or
/// null if it has none. The backend only stores the two fields together.
GroupIcon? groupIconFromMap(Map<String, dynamic> data) {
  final emoji = data['icon'] as String?;
  final color = data['icon_color'] as String?;
  return emoji != null && color != null ? (emoji: emoji, color: color) : null;
}

final _random = Random();

GroupIcon randomGroupIcon() => (
      emoji: groupIconEmoji[_random.nextInt(groupIconEmoji.length)],
      color: groupIconColors[_random.nextInt(groupIconColors.length)].key,
    );
