import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings/groups_controller.dart';
import 'src/settings/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = SettingsController();
  final groupsController = GroupsController();

  await settingsController.loadSettings();
  await groupsController.loadGroups();

  runApp(
    MyApp(
      settingsController: settingsController,
      groupsController: groupsController,
    ),
  );
}
