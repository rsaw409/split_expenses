import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class InternetConnectivityHelper extends ChangeNotifier {
  bool _isConnectedToInternet = false;
  bool get isConnectedToInternet => _isConnectedToInternet;
  Timer? _internetCheckTimer;
  final Duration checkInterval;

  InternetConnectivityHelper(
      {this.checkInterval = const Duration(seconds: 10)}) {
    _startChecking();
  }

  // Start periodic checking
  void _startChecking() {
    _internetCheckTimer = Timer.periodic(checkInterval, (timer) {
      _updateConnectionStatus();
    });
    _updateConnectionStatus();
  }

  // Function to update the connection status
  Future<void> _updateConnectionStatus() async {
    bool isConnected = await _hasInternetConnection();
    if (_isConnectedToInternet != isConnected) {
      _isConnectedToInternet = isConnected;
      notifyListeners();
    }
  }

  // Function to check actual internet connection
  Future<bool> _hasInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Stop periodic checking
  @override
  void dispose() {
    _internetCheckTimer?.cancel();
    super.dispose();
  }
}
