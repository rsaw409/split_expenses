import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_exception.dart';

/// Shared cache-first load behaviour for the group-scoped list controllers.
///
/// Cold start serves the cache immediately (no spinner) and then refetches. A
/// failed refetch keeps whatever is already on screen and reports [isStale]
/// instead of [isError], so losing the backend degrades to last-known data
/// rather than an error screen.
abstract class CachedListController<T> extends ChangeNotifier {
  CachedListController(this.groupId) {
    _load();
  }

  final int? groupId;

  @protected
  Future<List<T>> fetchFromNetwork(int id);

  @protected
  Future<List<T>?> readFromCache(int id);

  @protected
  Future<void> writeToCache(int id, List<T> items);

  @protected
  String get fetchFailureMessage;

  List<T> _items = [];
  List<T> get items => _items;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isError = false;
  bool get isError => _isError;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Showing data that hasn't been confirmed against the server.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// Whether [items] reflects a real result. Distinct from `items.isNotEmpty`:
  /// a group with genuinely zero expenses has loaded successfully, so a later
  /// failed refetch should keep showing "nothing yet", not an error.
  bool _hasData = false;

  /// Only the most recently started load may publish its result; earlier ones
  /// abandon theirs. Dart futures can't be cancelled, and responses can arrive
  /// out of order when a pull-to-refresh overlaps an automatic one.
  int _requestId = 0;

  bool _disposed = false;

  bool? _wasReachable;

  /// A fetch issued the instant the backend becomes reachable can still fail
  /// while the radio settles, and no further transition follows to trigger
  /// another try. One delayed retry covers that; it is not re-armed until the
  /// next success or reachability edge, so a failing backend is never hammered.
  static const _retryDelay = Duration(seconds: 3);
  Timer? _retryTimer;
  bool _retriedSinceLastSuccess = false;

  Future<void> refresh() => _load();

  /// Refetches on a real unreachable→reachable edge. Keyed off the transition
  /// rather than [isStale] because losing the backend without attempting a
  /// fetch leaves data un-stale yet still potentially outdated.
  void onReachabilityChanged(bool isReachable) {
    final wasReachable = _wasReachable;
    _wasReachable = isReachable;
    if (isReachable && wasReachable == false && groupId != null) {
      _retriedSinceLastSuccess = false;
      scheduleMicrotask(refresh);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }

  /// The single choke point for the "never notify after dispose" rule: an
  /// in-flight load can always outlive the controller, since the provider
  /// disposes it as soon as the selected group changes.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool _isSuperseded(int requestId) => requestId != _requestId;

  Future<void> _load() async {
    final int requestId = ++_requestId;
    final int? id = groupId;

    // Having no group selected is an empty state, not a failure — views render
    // their own onboarding copy for it rather than an error.
    if (id == null) {
      _isLoading = false;
      _isError = false;
      _notify();
      return;
    }

    if (!_hasData) {
      final cached = await _readCache(id);
      if (_isSuperseded(requestId)) return;

      if (cached != null) {
        _items = cached;
        _hasData = true;
        _isStale = true;
        _isLoading = false;
        _isError = false;
      } else {
        _isLoading = true;
        _isError = false;
      }
      _notify();
    }

    try {
      final fetched = await fetchFromNetwork(id);
      if (_isSuperseded(requestId)) return;

      _items = fetched;
      _hasData = true;
      _isLoading = false;
      _isError = false;
      _isStale = false;
      _retriedSinceLastSuccess = false;
      _notify();

      try {
        await writeToCache(id, fetched);
      } catch (_) {
        // Failing to persist must not surface as an app-level error.
      }
    } catch (e) {
      if (_isSuperseded(requestId)) return;

      _isLoading = false;
      if (_hasData) {
        _isStale = true;
      } else {
        _isError = true;
        _errorMessage = e is ApiException ? e.message : fetchFailureMessage;
      }
      _notify();
      _scheduleRetryIfReachable();
    }
  }

  void _scheduleRetryIfReachable() {
    if (_wasReachable != true || _retriedSinceLastSuccess) return;
    _retriedSinceLastSuccess = true;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (!_disposed) refresh();
    });
  }

  Future<List<T>?> _readCache(int id) async {
    try {
      return await readFromCache(id);
    } catch (_) {
      return null;
    }
  }

}
