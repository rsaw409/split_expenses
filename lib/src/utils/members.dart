import '../models/user.dart';
import '../models/user_balance.dart';

/// The group's members, taken from the balances the group already has cached
/// rather than a dedicated `getUsersInGroup` round trip.
///
/// Verified against the live backend: `getOverviewDataInGroup` returns a
/// *complete* member list, including someone just added who has no
/// transactions yet (they come back with a zero balance and zero counts). That
/// is what makes it a safe substitute — otherwise a newly added member would
/// silently be missing from the pickers used to record expenses.
List<User> membersFromBalances(List<UserBalance> balances) => balances
    .map((balance) => User(name: balance.name, id: balance.userId))
    .toList();
