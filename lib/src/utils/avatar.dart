import 'dart:math';

/// A member's avatar is a seed for `random_avatar`, which draws the same face
/// from the same seed every time. The seed is chosen when the member is added
/// and saved by the backend (`avatar`, at most 64 characters, never blank);
/// there is no endpoint to change it afterwards.

/// A fresh seed for the Change avatar button.
String newAvatarSeed() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(12, (_) => alphabet[random.nextInt(alphabet.length)])
      .join();
}
