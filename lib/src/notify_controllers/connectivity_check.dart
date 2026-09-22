import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../services/server.dart';

class InternetConnectivityHelper extends ChangeNotifier
    with WidgetsBindingObserver {
  /// Null until the first probe resolves. "Not checked yet" must not read as
  /// offline, or every cold start briefly claims to be offline before it has
  /// looked — which is the first thing a new user would see.
  bool? _isConnectedToInternet;
  bool get isConnectedToInternet => _isConnectedToInternet ?? true;
  Timer? _internetCheckTimer;
  final Duration checkInterval;

  InternetConnectivityHelper(
      {this.checkInterval = const Duration(seconds: 10)}) {
    WidgetsBinding.instance.addObserver(this);
    _startChecking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startChecking();
    } else {
      _internetCheckTimer?.cancel();
    }
  }

  // Start periodic checking
  void _startChecking() {
    _internetCheckTimer?.cancel();
    _internetCheckTimer = Timer.periodic(checkInterval, (timer) {
      _updateConnectionStatus();
    });
    _updateConnectionStatus();
  }

  // Function to update the connection status
  Future<void> _updateConnectionStatus() async {
    bool isConnected = await _canReachBackend();
    if (_isConnectedToInternet != isConnected) {
      _isConnectedToInternet = isConnected;
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

  // Stop periodic checking
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _internetCheckTimer?.cancel();
    super.dispose();
  }
}
