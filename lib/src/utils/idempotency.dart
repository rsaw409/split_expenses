import 'dart:convert';
import 'dart:math';

/// Shown when a write got no response at all. It may or may not have been
/// committed, so the user must not be invited to blindly retry.
const String unconfirmedWriteMessage =
    "Couldn't confirm whether this saved. Check the list before trying again.";

/// Holds the idempotency key for one logical write across retries.
///
/// The key stays stable while the payload is unchanged, so tapping Save again
/// after a write that timed out is de-duplicated server-side instead of
/// creating a second expense. It is reissued when the payload changes, so
/// editing the amount and resubmitting is treated as a genuinely new write
/// rather than being swallowed by the server returning the original.
///
/// Scope is deliberately the form session, not the HTTP call: a second, truly
/// identical expense entered later goes through a new form and so gets a new
/// key, which a payload hash alone could not distinguish.
class IdempotencyKey {
  String? _key;
  String? _payloadFingerprint;

  /// The key to send for [payload], issued fresh if this differs from the
  /// last attempt.
  String forPayload(Object? payload) {
    final fingerprint = jsonEncode(payload);
    if (_key == null || fingerprint != _payloadFingerprint) {
      _key = _generateKey();
      _payloadFingerprint = fingerprint;
    }
    return _key!;
  }

  /// Call once a write succeeds, so the next submission is a new write.
  /// Deliberately not called on failure — that is what makes a retry safe.
  void reset() {
    _key = null;
    _payloadFingerprint = null;
  }
}

/// Mints a stable key per item in a batch, keyed on each item's identity.
///
/// Per-item keys rather than one key for the request, so that a retry after a
/// *partial* failure re-applies only the items that did not land. One key for
/// the whole batch would only be safe if the server applied the batch
/// atomically, which it is not known to do.
///
/// Callers must pass an identity that is unique within a batch. For settle-up
/// that holds: the settlement walk advances both indices monotonically, so a
/// given debtor pays a given creditor at most once per batch.
class IdempotencyKeySet {
  final Map<String, String> _keys = {};

  /// The key for the item identified by [identity], minted once and reused for
  /// every later attempt at that same item.
  String forPayload(Object? identity) =>
      _keys.putIfAbsent(jsonEncode(identity), _generateKey);

  /// Call once the batch succeeds. Not called on failure, so a retry reuses
  /// the same per-item keys.
  void reset() => _keys.clear();
}

String _generateKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
