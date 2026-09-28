import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group.dart';
import '../services/cache_service.dart';
import '../services/push_registration.dart';

const _groupsKey = 'groups';
const _selectedGroupIdKey = 'selectedGroupId';


/// The joined groups, and which one is selected.
///
/// The selection is stored as an id and looked up in [groups], never as a
/// second copy of the group: a copy drifts from the list whenever one of them
/// is updated (a rejoin used to refresh the copy's invite id but not the
/// list's).
class GroupsController extends ChangeNotifier {
  GroupsController({PushRegistration push = const PushRegistration()})
      : _push = push {
    // A new install gets its subscription id only after launch; register
    // as soon as it arrives rather than waiting for the next launch.
    _stopWatchingSubscription =
        _push.onSubscriptionChanged(() => unawaited(registerDevice()));
  }

  final PushRegistration _push;
  late final void Function() _stopWatchingSubscription;

  /// The last registration queued; see [registerDevice].
  Future<void> _registration = Future.value();

  // Replaced, never mutated in place, so listeners comparing the previous
  // value by identity see every change.
  List<Map<String, dynamic>> _groups = [];
  int? _selectedGroupId;

  List<Map<String, dynamic>> get groups => _groups;

  /// The selected group, or the first group if the stored id no longer
  /// matches one (it was left, or a write was interrupted), or `{}` when
  /// there are no groups.
  Map<String, dynamic> get selectedGroup =>
      _groups.where((g) => g['id'] == _selectedGroupId).firstOrNull ??
      _groups.firstOrNull ??
      const {};

  set selectedGroup(Map<String, dynamic> group) {
    _selectedGroupId = group['id'] as int?;
    notifyListeners();
    _persist();
  }

  Future<void> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();

    final groups = prefs.getString(_groupsKey);
    if (groups != null) {
      _groups = (jsonDecode(groups) as List).cast<Map<String, dynamic>>();
    }
    // Null after upgrading from a build that stored a full copy under
    // 'selectedGroup'; [selectedGroup] then falls back to the first group.
    _selectedGroupId = prefs.getInt(_selectedGroupIdKey);

    notifyListeners();

    // Not awaited: the groups must show without waiting on the network.
    unawaited(registerDevice());
    unawaited(_quietly('Removing old notification tags',
        _push.removeGroupTags));
  }

  /// Adds [group], or refreshes it if already joined, and selects it.
  Future<void> saveGroups(Group group) async {
    final isNew = !_groups.any((g) => g['id'] == group.id);

    // Replacing the entry keeps what the server just sent.
    _groups = [
      for (final g in _groups) g['id'] == group.id ? group.toMap() : g,
      if (isNew) group.toMap(),
    ];
    _selectedGroupId = group.id;

    notifyListeners();
    await _persist();
    unawaited(registerDevice());
  }

  Future<void> removeCurrentGroup() async {
    final current = selectedGroup;
    final groupId = current['id'] as int?;
    if (groupId == null) return;

    _groups = _groups.where((g) => g['id'] != groupId).toList();
    await clearGroupCache(groupId);

    _selectedGroupId = _groups.firstOrNull?['id'] as int?;

    notifyListeners();
    await _persist();
    unawaited(registerDevice());
  }

  /// Tells the backend this device's full list of groups, so it sends each
  /// of them notifications. Run on launch, after joining or leaving, and when
  /// the subscription id changes.
  ///
  /// Queued behind the previous call: the server replaces the list each
  /// time, so two calls in flight could land out of order and leave an older
  /// list in place. Each call reads the groups when it runs, so the last one
  /// always sends the current list.
  Future<void> registerDevice() =>
      _registration = _registration.then((_) => _quietly(
            'Registering for notifications',
            () async {
              final subscriptionId = await _push.subscriptionId();
              if (subscriptionId == null) return;
              await _push.register(subscriptionId, [
                for (final g in _groups)
                  if (g['id'] is int) g['id'] as int,
              ]);
            },
          ));

  /// Notifications must never break joining, leaving or startup; whatever
  /// failed is retried on the next launch.
  Future<void> _quietly(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('$what failed: $error');
    }
  }

  @override
  void dispose() {
    _stopWatchingSubscription();
    super.dispose();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupsKey, jsonEncode(_groups));

    final id = _selectedGroupId;
    if (id == null) {
      await prefs.remove(_selectedGroupIdKey);
    } else {
      await prefs.setInt(_selectedGroupIdKey, id);
    }
  }
}
