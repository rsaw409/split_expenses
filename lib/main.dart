import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/cache_service.dart';
import 'src/services/push.dart';
import 'src/notify_controllers/backend_reachability.dart';
import 'src/notify_controllers/groups_controller.dart';
import 'src/notify_controllers/settings_controller.dart';
import 'src/notify_controllers/userbalances_controller.dart';
import 'src/notify_controllers/allexpense_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // OneSignal: the native SDK in the apps, its Web SDK in the browser.
  initializePush();

  // Unawaited: the current cache never reads the old entries, so this only
  // reclaims space.
  dropStaleCaches();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BackendReachability()),
        ChangeNotifierProvider<SettingsController>(
          create: (context) {
            final settingsController = SettingsController();
            settingsController.loadSettings();
            return settingsController;
          },
        ),
        ChangeNotifierProvider<GroupsController>(
          create: (context) {
            final groupsController = GroupsController();
            groupsController.loadGroups();
            return groupsController;
          },
        ),
        ChangeNotifierProxyProvider2<GroupsController,
            BackendReachability, AllExpenseController>(
          create: (context) => AllExpenseController(
            context.read<GroupsController>().selectedGroup["id"],
          ),
          update: (context, groupsController, reachability, previous) {
            final int? groupId =
                groupsController.selectedGroup["id"] as int?;
            if (previous != null && previous.groupId == groupId) {
              previous.onReachabilityChanged(reachability.isReachable);
              return previous;
            }
            return AllExpenseController(groupId);
          },
        ),
        ChangeNotifierProxyProvider2<GroupsController,
            BackendReachability, UserBalanceController>(
          create: (context) => UserBalanceController(
            context.read<GroupsController>().selectedGroup["id"],
          ),
          update: (context, groupsController, reachability, previous) {
            final int? groupId =
                groupsController.selectedGroup["id"] as int?;
            if (previous != null && previous.groupId == groupId) {
              previous.onReachabilityChanged(reachability.isReachable);
              return previous;
            }
            return UserBalanceController(groupId);
          },
        ),
      ],
      child: MyApp(),
    ),
  );
}
