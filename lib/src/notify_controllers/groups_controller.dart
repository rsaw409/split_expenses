import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group.dart';

class GroupsController extends ChangeNotifier {
  List<Map<String, dynamic>> _groups = [];

  List<Map<String, dynamic>> get groups => _groups;

  Map<String, dynamic> _selectedGroup = {};

  Map<String, dynamic> get selectedGroup => _selectedGroup;

  set selectedGroup(Map<String, dynamic> g) {
    _selectedGroup = g;
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('selectedGroup', jsonEncode(g));
    });
  }

  Future<void> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    String? groups = prefs.getString('groups');
    if (groups != null) {
      _groups = jsonDecode(groups).cast<Map<String, dynamic>>();
    }

    String? storedSelectedGroup = prefs.getString('selectedGroup');
    if (storedSelectedGroup != null) {
      _selectedGroup = jsonDecode(storedSelectedGroup);
    }

    notifyListeners();
  }

  Future<void> saveGroups(Group group) async {
    bool? isNotPresent =
        _groups.where((oldElement) => oldElement['id'] == group.id).isEmpty;

    if (isNotPresent == true) {
      // OneSignal.login("externalUserId");
      OneSignal.User.addTagWithKey('group: ${group.name}', "true");
      _groups.add(group.toMap());
    }

    _selectedGroup = group.toMap();

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('groups', jsonEncode(_groups));
    await prefs.setString('selectedGroup', jsonEncode(_selectedGroup));
  }

  Future<void> removeCurrentGroup() async {
    final groupid = _selectedGroup['id'];
    final groupName = _selectedGroup["name"];

    OneSignal.User.removeTag('group: $groupName');
    _groups.removeWhere((oldElement) => oldElement['id'] == groupid);

    _selectedGroup = (_groups.isNotEmpty) ? groups.first : {};

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('groups', jsonEncode(_groups));
    await prefs.setString('selectedGroup', jsonEncode(_selectedGroup));
  }
}
