import 'package:flutter/material.dart';

import '../models/user_balance.dart';
import '../services/api_exception.dart';
import '../services/backend.dart';

class UserBalanceController extends ChangeNotifier {
  final int? groupId;
  List<UserBalance> _userBalances = [];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isError = false;
  bool get isError => _isError;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<UserBalance> get userBalances => _userBalances;

  UserBalanceController(this.groupId) {
    _load();
  }

  void refresh() => _load();

  void _load() {
    if (groupId == null) {
      _isLoading = false;
      _isError = true;
      _errorMessage = 'Create or join a group to see balances.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _isError = false;
    notifyListeners();

    fetchUserBalances(groupId).then((userbalances) {
      _userBalances = userbalances;
      _isLoading = false;
      _isError = false;
      notifyListeners();
    }).catchError((e) {
      _isLoading = false;
      _isError = true;
      _errorMessage = e is ApiException
          ? e.message
          : 'Could not load balances. Check your connection and try again.';
      notifyListeners();
    });
  }
}
