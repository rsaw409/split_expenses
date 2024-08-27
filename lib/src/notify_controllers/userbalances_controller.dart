import 'package:flutter/material.dart';

import '../models/user_balance.dart';
import '../services/backend.dart';

class UserBalanceController extends ChangeNotifier {
  final int? groupId;
  List<UserBalance> _userBalances = [];

  bool _isError = false;
  get isError => _isError;

  get userBalances => _userBalances;

  UserBalanceController(this.groupId) {
    fetchUserBalances(groupId).then((userbalances) {
      _userBalances = userbalances;
      _isError = false;
      notifyListeners();
    }).catchError((e) {
      _isError = true;
      notifyListeners();
    });
  }

  void refresh() {
    fetchUserBalances(groupId).then((userbalances) {
      _userBalances = userbalances;
      _isError = false;
      notifyListeners();
    }).catchError((e) {
      _isError = true;
      notifyListeners();
    });
  }
}
