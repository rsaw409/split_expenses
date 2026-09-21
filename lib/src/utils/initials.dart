/// Up to two uppercase initials for an avatar, e.g. "Jane Doe" -> "JD".
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  final initials =
      words.where((word) => word.isNotEmpty).take(2).map((w) => w[0]).join();
  return initials.toUpperCase();
}
