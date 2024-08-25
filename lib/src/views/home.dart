import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/views/drawer.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../components/floating_action_button.dart';
import '../components/invite_dialog.dart';
import '../models/group.dart';
import '../services/connectivity_check.dart';
import '../services/group_service.dart';
import '../settings/groups_controller.dart';
import 'expenses_view.dart';
import 'overview_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
  });

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
  }

  handleInvite(BuildContext context, String? inviteId) {
    if (inviteId != null) {
      joinGroupFromInviteId(inviteId).then((Group group) {
        context.read<GroupsController>().saveGroups(group);
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsController = context.read<GroupsController>();
    return DefaultTabController(
      initialIndex: 1,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<GroupsController>(
            builder: (_, groupsController, __) => Text(
                groupsController.selectedGroup['name'] ?? 'No Group Found'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<int>(
                onSelected: (item) async {
                  if (groupsController.selectedGroup['name'] == null) {
                    return;
                  }
                  if (item == 0) {
                    showInviteDialog(
                      context,
                      groupsController.selectedGroup['name'],
                      groupsController.selectedGroup['inviteId'],
                    );
                  } else if (item == 1) {
                    final groupName = groupsController.selectedGroup['name'];

                    groupsController.removeCurrentGroup();

                    var snackBar = SnackBar(
                      content: Text('Successfully leave group: $groupName'),
                    );

                    ScaffoldMessenger.of(context)
                      ..removeCurrentSnackBar()
                      ..showSnackBar(snackBar);
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
        drawer:
            context.watch<InternetConnectivityHelper>().isConnectedToInternet
                ? const MyDrawer()
                : null,
        body: !context.watch<InternetConnectivityHelper>().isConnectedToInternet
            ? Center(
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/offline.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )
            : const TabBarView(
                children: <Widget>[
                  OverviewView(),
                  ExpensesView(),
                ],
              ),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton:
            context.watch<InternetConnectivityHelper>().isConnectedToInternet
                ? const ExpandableFloatingActionButton()
                : null,
      ),
    );
  }
}
