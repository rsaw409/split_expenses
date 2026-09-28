import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_expense/src/models/group.dart';
import 'package:split_expense/src/notify_controllers/groups_controller.dart';
import 'package:split_expense/src/services/push_registration.dart';

/// Records registrations instead of calling OneSignal and the backend.
class FakePushRegistration implements PushRegistration {
  FakePushRegistration({this.id = 'sub-1'});

  /// The subscription id OneSignal would report; null before it has one.
  String? id;

  /// Each registration sent, as `subscriptionId: group ids`.
  final registrations = <String>[];
  int groupTagCleanups = 0;
  bool failing = false;

  /// When set, a registration waits for it, to simulate a slow request.
  Completer<void>? gate;

  void Function()? _onChanged;

  /// Simulates OneSignal issuing a (new) subscription id.
  void issue(String newId) {
    id = newId;
    _onChanged?.call();
  }

  @override
  Future<String?> subscriptionId() async => id;

  @override
  void Function() onSubscriptionChanged(void Function() onChanged) {
    _onChanged = onChanged;
    return () => _onChanged = null;
  }

  /// The most registrations that were ever running at the same time.
  int maxInFlight = 0;
  int _inFlight = 0;

  @override
  Future<void> register(String subscriptionId, List<int> groupIds) async {
    if (failing) throw Exception('backend down');
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      final wait = gate;
      if (wait != null) await wait.future;
      registrations.add('$subscriptionId: ${groupIds.join(',')}');
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<void> removeGroupTags() async {
    if (failing) throw Exception('no OneSignal');
    groupTagCleanups++;
  }
}

void main() {
  final goa = {'id': 1, 'name': 'Goa Trip', 'inviteId': 'goa-invite'};
  final flat = {'id': 2, 'name': 'Flat', 'inviteId': 'flat-invite'};

  late FakePushRegistration push;

  GroupsController controller({String? subscriptionId = 'sub-1'}) {
    push = FakePushRegistration(id: subscriptionId);
    return GroupsController(push: push);
  }

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('no stored selection (an upgraded install) selects the first group',
      () async {
    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode([goa, flat]),
      'selectedGroup': jsonEncode(flat),
    });
    final c = controller();
    await c.loadGroups();

    expect(c.selectedGroup['id'], 1);
  });

  group('registering this device for notifications', () {
    test('launch registers every group by id, and clears old tags',
        () async {
      SharedPreferences.setMockInitialValues({
        'groups': jsonEncode([goa, flat]),
        'selectedGroupId': 1,
      });
      final c = controller();
      await c.loadGroups();
      await pumpEventQueue();

      expect(push.registrations, ['sub-1: 1,2']);
      expect(push.groupTagCleanups, 1);
    });

    test('joining and leaving each re-register the full list', () async {
      SharedPreferences.setMockInitialValues({
        'groups': jsonEncode([goa]),
        'selectedGroupId': 1,
      });
      final c = controller();
      await c.loadGroups();
      await pumpEventQueue();

      await c.saveGroups(
        const Group(id: 2, name: 'Flat', inviteId: 'flat-invite'),
      );
      await pumpEventQueue();
      await c.removeCurrentGroup();
      await pumpEventQueue();
      await c.removeCurrentGroup();
      await pumpEventQueue();

      expect(push.registrations, [
        'sub-1: 1',
        'sub-1: 1,2',
        'sub-1: 1',
        // Leaving the last group still registers, so the server drops it.
        'sub-1: ',
      ]);
    });

    test('waits for a subscription id, then registers when it arrives',
        () async {
      SharedPreferences.setMockInitialValues({
        'groups': jsonEncode([goa]),
        'selectedGroupId': 1,
      });
      final c = controller(subscriptionId: null);
      await c.loadGroups();
      await pumpEventQueue();
      expect(push.registrations, isEmpty);

      push.issue('sub-new');
      await pumpEventQueue();

      expect(push.registrations, ['sub-new: 1']);
    });

    test('calls run one at a time, in order, each with the current groups',
        () async {
      SharedPreferences.setMockInitialValues({
        'groups': jsonEncode([goa]),
        'selectedGroupId': 1,
      });
      final c = controller();
      push.gate = Completer();
      await c.loadGroups(); // the first registration now waits on the gate

      await c.saveGroups(
        const Group(id: 2, name: 'Flat', inviteId: 'flat-invite'),
      );
      await c.saveGroups(
        const Group(id: 3, name: 'Office', inviteId: 'office-invite'),
      );
      push.gate!.complete();
      push.gate = null;
      await pumpEventQueue();

      // Never two in flight, so an older list can never land after a newer
      // one; the last call sends the groups as they ended up.
      expect(push.maxInFlight, 1);
      expect(push.registrations, hasLength(3));
      expect(push.registrations.last, 'sub-1: 1,2,3');
    });

    test('a failure does not break loading, joining or leaving', () async {
      SharedPreferences.setMockInitialValues({
        'groups': jsonEncode([goa]),
        'selectedGroupId': 1,
      });
      final c = controller();
      push.failing = true;
      await c.loadGroups();
      await c.saveGroups(
        const Group(id: 2, name: 'Flat', inviteId: 'flat-invite'),
      );
      await c.removeCurrentGroup();
      await pumpEventQueue();

      expect(c.groups.map((g) => g['id']), [1]);
      expect(c.selectedGroup['id'], 1);
    });

    test('stops watching the subscription once disposed', () async {
      SharedPreferences.setMockInitialValues({});
      final c = controller(subscriptionId: null);
      c.dispose();

      push.issue('sub-late');
      await pumpEventQueue();

      expect(push.registrations, isEmpty);
    });
  });

  test('a stale selected id falls back to the first group', () async {
    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode([goa, flat]),
      'selectedGroupId': 99,
    });
    final c = controller();
    await c.loadGroups();

    expect(c.selectedGroup['id'], 1);
  });

  test('no groups means an empty selection', () async {
    SharedPreferences.setMockInitialValues({});
    final c = controller();
    await c.loadGroups();

    expect(c.selectedGroup, isEmpty);
  });

  test('rejoining updates the list entry itself, not just the selection',
      () async {
    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode([goa, flat]),
      'selectedGroupId': 2,
    });
    final c = controller();
    await c.loadGroups();

    await c.saveGroups(
      const Group(id: 1, name: 'Goa Trip', inviteId: 'new-invite'),
    );

    expect(c.groups, hasLength(2));
    expect(c.groups.first['inviteId'], 'new-invite');
    expect(c.selectedGroup['id'], 1);

    // Switching away and back used to lose the refreshed invite id.
    c.selectedGroup = c.groups[1];
    c.selectedGroup = c.groups[0];
    expect(c.selectedGroup['inviteId'], 'new-invite');
  });

  test('joining a new group adds it and selects it', () async {
    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode([goa]),
      'selectedGroupId': 1,
    });
    final c = controller();
    await c.loadGroups();

    await c.saveGroups(const Group(id: 3, name: 'Office', inviteId: 'x'));

    expect(c.groups.map((g) => g['id']), [1, 3]);
    expect(c.selectedGroup['id'], 3);
    expect((await prefs()).getInt('selectedGroupId'), 3);
  });

  test('leaving removes the group and selects the first remaining', () async {
    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode([goa, flat]),
      'selectedGroupId': 2,
    });
    final c = controller();
    await c.loadGroups();

    await c.removeCurrentGroup();

    expect(c.groups.map((g) => g['id']), [1]);
    expect(c.selectedGroup['id'], 1);

    await c.removeCurrentGroup();
    expect(c.selectedGroup, isEmpty);
    expect((await prefs()).getInt('selectedGroupId'), isNull);
  });

  test('every change replaces the list, so identity checks see it', () async {
    SharedPreferences.setMockInitialValues({
      'groups': jsonEncode([goa]),
      'selectedGroupId': 1,
    });
    final c = controller();
    await c.loadGroups();

    final before = c.groups;
    await c.saveGroups(const Group(id: 1, name: 'Goa Trip', inviteId: 'y'));
    expect(identical(before, c.groups), isFalse);
  });
}
