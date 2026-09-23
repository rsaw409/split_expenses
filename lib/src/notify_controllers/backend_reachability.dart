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
  final Duration checkInterval;

  BackendReachability(
      {this.checkInterval = const Duration(seconds: 10)}) {
    WidgetsBinding.instance.addObserver(this);
    _startChecking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startChecking();
    } else {
      _probeTimer?.cancel();
    }
  }

  void _startChecking() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(checkInterval, (timer) {
      _refreshReachability();
    });
    _refreshReachability();
  }

  Future<void> _refreshReachability() async {
    final reachable = await _canReachBackend();
    if (_isReachable != reachable) {
      _isReachable = reachable;
      notifyListeners();
    }
  }

  /// Probes the app's own backend rather than a third party: what governs
  /// whether anything here works is reachability of Split's server, not of
  /// google.com — which fails on networks that block it, on captive-portal
  /// wifi, and whenever DNS is flaky, each time wrongly disabling every write.
  ///
  /// Any HTTP response counts, including the 404 the base URL returns: the
  /// status doesn't matter, only that something answered.
  Future<bool> _canReachBackend() async {
    try {
      await http.head(Uri.parse(server)).timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probeTimer?.cancel();
    super.dispose();
  }
}
