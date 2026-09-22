import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense/expense.dart';
import '../models/user_balance.dart';

String _expensesKey(int groupId) => 'cache_expenses_$groupId';
String _balancesKey(int groupId) => 'cache_balances_$groupId';

Future<List<Expense>?> getCachedExpenses(int groupId) =>
    _readList(_expensesKey(groupId), Expense.fromMap);

Future<void> setCachedExpenses(int groupId, List<Expense> expenses) =>
    _writeList(_expensesKey(groupId), expenses, (e) => e.toMap());

Future<List<UserBalance>?> getCachedBalances(int groupId) =>
    _readList(_balancesKey(groupId), UserBalance.fromMap);

Future<void> setCachedBalances(int groupId, List<UserBalance> balances) =>
    _writeList(_balancesKey(groupId), balances, (b) => b.toMap());

Future<void> clearGroupCache(int groupId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_expensesKey(groupId));
  await prefs.remove(_balancesKey(groupId));
}

Future<List<T>?> _readList<T>(
  String key,
  T Function(Map<String, dynamic>) fromMap,
) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(key);
  if (raw == null) return null;

  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => fromMap(e as Map<String, dynamic>)).toList();
  } catch (_) {
    // Corrupt, or written by a build whose model shape no longer parses. Drop
    // it rather than throwing on every load — a cache entry must never be able
    // to wedge the screen it was meant to speed up.
    await prefs.remove(key);
    return null;
  }
}

Future<void> _writeList<T>(
  String key,
  List<T> items,
  Map<String, dynamic> Function(T) toMap,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, jsonEncode(items.map(toMap).toList()));
}
