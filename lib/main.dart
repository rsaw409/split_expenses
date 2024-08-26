import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/connectivity_check.dart';
import 'src/settings/groups_controller.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/userbalances_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
