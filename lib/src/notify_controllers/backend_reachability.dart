import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../services/server.dart';

/// Whether the app can currently reach its own backend — which is what
/// actually governs whether anything works, and deliberately not the same
/// question as "is this device online".
///
/// A failed probe cannot distinguish a dropped connection from a server that
/// is down, so nothing here claims to know which it is; the UI says only that
/// Split is unreachable.
class BackendReachability extends ChangeNotifier with WidgetsBindingObserver {
  /// Null until the first probe resolves. "Not checked yet" must not read as
  /// unreachable, or every cold start briefly claims failure before it has
  /// looked — which is the first thing a new user would see.
  bool? _isReachable;
  bool get isReachable => _isReachable ?? true;
  Timer? _probeTimer;
  Timer? _confirmTimer;
  final Duration checkInterval;

  /// How soon a first failed probe is checked again before it is reported.
  final Duration confirmDelay;

  final Future<bool> Function() _probe;

  /// Failed probes in a row since the last success or resume.
  int _failures = 0;

  /// Only the most recently started probe may publish its result. A probe left
  /// in flight while the app was suspended resolves on resume, usually as a
  /// failure, and must not count against the fresh one.
  int _probeId = 0;

  bool _disposed = false;

  BackendReachability({
    this.checkInterval = const Duration(seconds: 10),
    this.confirmDelay = const Duration(seconds: 2),
    @visibleForTesting Future<bool> Function()? probe,
  }) : _probe = probe ?? _canReachBackend {
    WidgetsBinding.instance.addObserver(this);
    _startChecking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startChecking();
    } else {
      _probeTimer?.cancel();
      _confirmTimer?.cancel();
    }
  }

  void _startChecking() {
    _probeTimer?.cancel();
    _confirmTimer?.cancel();
    // A failure from before the app was suspended says nothing about now.
    _failures = 0;
    _probeTimer = Timer.periodic(checkInterval, (timer) {
      _refreshReachability();
    });
    _refreshReachability();
  }

  Future<void> _refreshReachability() async {
    final probeId = ++_probeId;
    final reachable = await _probe();
    if (_disposed || probeId != _probeId) return;

    if (reachable) {
      reportReachable();
    } else if (_isReachable == false || ++_failures >= 2) {
      _confirmTimer?.cancel();
      _setReachable(false);
    } else {
      // One failure isn't enough to say so. In the web app the first request
      // after a launch or resume can go out on a connection the browser kept
      // pooled while suspended, which is dead: it fails, or stalls past the
      // timeout, and the next request works. Reported at once, that showed
      // the banner for a full [checkInterval] on most web launches. So check
      // again shortly first.
      _confirmTimer?.cancel();
      _confirmTimer = Timer(confirmDelay, _refreshReachability);
    }
  }

  /// Records that the backend just answered. A list fetch succeeding counts
  /// as much as a probe, and clears the banner straight away rather than at
  /// the next probe.
  void reportReachable() {
    if (_disposed) return;
    _failures = 0;
    _confirmTimer?.cancel();
    _setReachable(true);
  }

  void _setReachable(bool reachable) {
    if (_isReachable == reachable) return;
    _isReachable = reachable;
    notifyListeners();
  }

  /// Probes the app's own backend rather than a third party: what governs
  /// whether anything here works is reachability of Split's server, not of
  /// google.com — which fails on networks that block it, on captive-portal
  /// wifi, and whenever DNS is flaky, each time wrongly disabling every write.
  ///
  /// Any HTTP response counts, including the 404 the base URL returns: the
  /// status doesn't matter, only that something answered.
  static Future<bool> _canReachBackend() async {
    try {
      await http.head(Uri.parse(server)).timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _probeTimer?.cancel();
    _confirmTimer?.cancel();
    super.dispose();
  }
}
