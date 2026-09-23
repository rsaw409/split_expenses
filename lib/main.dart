import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'src/app.dart';
import 'src/notify_controllers/backend_reachability.dart';
import 'src/notify_controllers/groups_controller.dart';
import 'src/notify_controllers/settings_controller.dart';
import 'src/notify_controllers/userbalances_controller.dart';
import 'src/notify_controllers/allexpense_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("e6cdb8fb-192b-4a0e-81e1-5762f7e0b630");
  OneSignal.Notifications.requestPermission(true);

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
