import 'package:flutter/material.dart';
import 'package:split_expense/src/models/expense/expense.dart';

import '../services/backend.dart';

class AllExpenseController extends ChangeNotifier {
  final int? groupId;
  List<Expense> _expenses = [];

  bool _isError = false;
  get isError => _isError;

  get expenses => _expenses;

  AllExpenseController(this.groupId) {
    fetchExpenses(groupId, null, null, null).then((expenses) {
      _expenses = expenses;
      _isError = false;
      notifyListeners();
    }).catchError((e) {
      _isError = true;
      notifyListeners();
    });
  }

  void refresh() {
    fetchExpenses(groupId, null, null, null).then((expenses) {
      _expenses = expenses;
      _isError = false;
      notifyListeners();
    }).catchError((e) {
      _isError = true;
      notifyListeners();
    });
  }
}
