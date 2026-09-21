import 'package:flutter/material.dart';
import 'package:split_expense/src/models/expense/expense.dart';

import '../services/api_exception.dart';
import '../services/backend.dart';

class AllExpenseController extends ChangeNotifier {
  final int? groupId;
  List<Expense> _expenses = [];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isError = false;
  bool get isError => _isError;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Expense> get expenses => _expenses;

  AllExpenseController(this.groupId) {
    _load();
  }

  void refresh() => _load();

  void _load() {
    if (groupId == null) {
      _isLoading = false;
      _isError = true;
      _errorMessage = 'Create or join a group to see expenses.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _isError = false;
    notifyListeners();

    fetchExpenses(groupId, null, null, null).then((expenses) {
      _expenses = expenses;
      _isLoading = false;
      _isError = false;
      notifyListeners();
    }).catchError((e) {
      _isLoading = false;
      _isError = true;
      _errorMessage = e is ApiException
          ? e.message
          : 'Could not load expenses. Check your connection and try again.';
      notifyListeners();
    });
  }
}
