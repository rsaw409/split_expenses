import 'package:flutter/material.dart';
import 'package:split_expense/src/settings/settings_controller.dart';
import 'package:split_expense/src/views/drawer.dart';
import 'package:split_expense/src/views/group_view.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../components/floating_action_button.dart';
import '../components/invite_dialog.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../settings/groups_controller.dart';

class HomeView extends StatefulWidget {
  final SettingsController settingsController;
  final GroupsController groupsController;

  const HomeView({
    super.key,
    required this.settingsController,
    required this.groupsController,
  });

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  handleInvite(String? inviteId) {
    if (inviteId != null) {
      joinGroupFromInviteId(inviteId).then((Group group) {
        widget.groupsController.saveGroups(group);
        var snackBar = SnackBar(
          content: Text('Successfully joined ${group.name}.'),
        );
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(snackBar);
      }).catchError((error) {
        var snackBar = const SnackBar(
          content: Text('Failed to join group'),
        );
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(snackBar);
      });
    } else {
      var snackBar = const SnackBar(
        content: Text('Could not find inviteId'),
      );
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }

  void inviteToJoinGroup(context) {
    final groupName = widget.groupsController.selectedGroup['name'];
    final inviteId = widget.groupsController.selectedGroup['inviteId'];
    showInviteDialog(context, groupName, inviteId);
  }

  Future<void> leaveGroup(context) async {
    final groupName = widget.groupsController.selectedGroup['name'];

    widget.groupsController.removeCurrentGroup();

    var snackBar = SnackBar(
      content: Text('Successfully leave group: $groupName'),
    );

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 1,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: ListenableBuilder(
            listenable: widget.groupsController,
            builder: (BuildContext context, Widget? child) => Text(
                widget.groupsController.selectedGroup['name'] ??
                    'No Group Found'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<int>(
                onSelected: (item) async {
                  if (widget.groupsController.selectedGroup['name'] == null) {
                    return;
                  }
                  if (item == 0) {
                    inviteToJoinGroup(context);
                  } else if (item == 1) {
                    await leaveGroup(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<int>(value: 0, child: Text('Invite')),
                  const PopupMenuItem<int>(
                      value: 1, child: Text('Leave group')),
                ],
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(
                icon: Text('Overview'),
              ),
              Tab(
                icon: Text('Expenses'),
              ),
            ],
          ),
        ),
        drawer: ListenableBuilder(
          listenable: widget.groupsController,
          builder: (BuildContext context, Widget? child) => MyDrawer(
            settingsController: widget.settingsController,
            groupsController: widget.groupsController,
          ),
        ),
        body: ListenableBuilder(
          listenable: widget.groupsController,
          builder: (BuildContext context, Widget? child) => TabBarScreen(
            groupId: widget.groupsController.selectedGroup['id'],
          ),
        ),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: ExpandableFloatingActionButton(
            groupsController: widget.groupsController,
            settingsController: widget.settingsController),
      ),
    );
  }
}
