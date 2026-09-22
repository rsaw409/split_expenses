import '../models/user_balance.dart';
import '../services/backend.dart';
import '../services/cache_service.dart';
import 'cached_list_controller.dart';

class UserBalanceController extends CachedListController<UserBalance> {
  UserBalanceController(super.groupId);

  List<UserBalance> get userBalances => items;

  @override
  Future<List<UserBalance>> fetchFromNetwork(int id) => fetchUserBalances(id);

  @override
  Future<List<UserBalance>?> readFromCache(int id) => getCachedBalances(id);

  @override
  Future<void> writeToCache(int id, List<UserBalance> items) =>
      setCachedBalances(id, items);

  @override
  String get fetchFailureMessage =>
      'Could not load balances. Check your connection and try again.';
}
