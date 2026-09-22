import 'package:split_expense/src/models/expense/expense.dart';

import '../services/backend.dart';
import '../services/cache_service.dart';
import 'cached_list_controller.dart';

class AllExpenseController extends CachedListController<Expense> {
  AllExpenseController(super.groupId);

  List<Expense> get expenses => items;

  @override
  Future<List<Expense>> fetchFromNetwork(int id) =>
      fetchExpenses(id, null, null, null);

  @override
  Future<List<Expense>?> readFromCache(int id) => getCachedExpenses(id);

  @override
  Future<void> writeToCache(int id, List<Expense> items) =>
      setCachedExpenses(id, items);

  @override
  String get fetchFailureMessage =>
      'Could not load expenses. Check your connection and try again.';
}
