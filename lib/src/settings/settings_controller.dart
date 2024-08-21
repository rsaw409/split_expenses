import 'package:flutter/material.dart';

import 'settings_service.dart';

class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService);

  final SettingsService _settingsService;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> get groups => _groups;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _groups = await _settingsService.loadGroups();
    // Important! Inform listeners a change has occurred.
    notifyListeners();
  }

  /// Update and persist the ThemeMode based on the user's selection.
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;

    // Do not perform any work if new and old ThemeMode are identical
    if (newThemeMode == _themeMode) return;

    // Otherwise, store the new ThemeMode in memory
    _themeMode = newThemeMode;

    // Important! Inform listeners a change has occurred.
    notifyListeners();

    // Persist the changes to a local database or the internet using the
    // SettingService.
    await _settingsService.updateThemeMode(newThemeMode);
  }

  // Update and persist the groups in sharedpreference
  Future<void> saveGroups(Map<String, dynamic> group) async {
    bool? isNotPresent =
        _groups.where((oldElement) => oldElement['id'] == group['id']).isEmpty;

    if (isNotPresent == true) {
      _groups.add(group);
    }

    // Important! Inform listeners a change has occurred.
    notifyListeners();

    return _settingsService.saveGroups(_groups);
  }

  Future<void> removeGroup(groupid) async {
    _groups.removeWhere((oldElement) => oldElement['id'] == groupid);

    // Important! Inform listeners a change has occurred.
    notifyListeners();

    return _settingsService.saveGroups(_groups);
  }
}
