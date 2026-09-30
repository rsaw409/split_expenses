import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/userbalances_controller.dart';

/// Refreshes everything shown for the selected group: its transactions and
/// its balances, which come from separate requests. Every pull-to-refresh
/// uses it, whichever screen it is on: refreshing only that screen's list
/// left the other stale (pulling on the overview kept an old transaction
/// list). Completes once both have, so a RefreshIndicator holds its spinner
/// for the real duration.
Future<void> refreshGroupData(BuildContext context) async {
  await Future.wait([
    context.read<AllExpenseController>().refresh(),
    context.read<UserBalanceController>().refresh(),
  ]);
}
