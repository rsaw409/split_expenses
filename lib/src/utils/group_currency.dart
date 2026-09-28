import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/groups_controller.dart';
import 'currency.dart';

extension GroupCurrency on BuildContext {
  /// The selected group's currency, for formatting and parsing amounts.
  /// Rebuilds the caller only when the currency itself changes.
  Currency get groupCurrency =>
      select<GroupsController, Currency>((c) => c.selectedCurrency);
}
