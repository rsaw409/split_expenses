import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'src/app.dart';
import 'src/notify_controllers/connectivity_check.dart';
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
        ChangeNotifierProvider(create: (_) => InternetConnectivityHelper()),
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
        ChangeNotifierProxyProvider<GroupsController, AllExpenseController>(
          create: (context) => AllExpenseController(
            context.read<GroupsController>().selectedGroup["id"],
          ),
          update: (context, groupsController, previousUserBalanceController) {
            return AllExpenseController(groupsController.selectedGroup["id"]);
          },
        ),
        ChangeNotifierProxyProvider<GroupsController, UserBalanceController>(
          create: (context) => UserBalanceController(
            context.read<GroupsController>().selectedGroup["id"],
          ),
          update: (context, groupsController, previousUserBalanceController) {
            return UserBalanceController(groupsController.selectedGroup["id"]);
          },
        ),
      ],
      child: MyApp(),
    ),
  );
}
