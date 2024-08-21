import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// A service that stores and retrieves user settings.
///
/// By default, this class does not persist user settings. If you'd like to
/// persist the user settings locally, use the shared_preferences package. If
/// you'd like to store settings on a web server, use the http package.
class SettingsService {
  /// Loads the User's preferred ThemeMode from local or remote storage.
  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? theme = prefs.getString('theme');
    if (theme == 'dark') {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }

  /// Persists the user's preferred ThemeMode to local or remote storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', theme == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<List<Map<String, dynamic>>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();

    // prefs.remove('groups');
    String? groups = prefs.getString('groups');
    List<Map<String, dynamic>> groupList =
        jsonDecode(groups ?? '[]').cast<Map<String, dynamic>>();
    return groupList;
  }

  Future<void> saveGroups(List<Map<String, dynamic>> groups) async {
    final groupsInString = jsonEncode(groups);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groups', groupsInString);
  }
}
