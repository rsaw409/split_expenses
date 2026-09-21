import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/views/all_expenses_view.dart';
import 'package:split_expense/src/components/drawer.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../components/floating_action_button.dart';
import '../components/invite_dialog.dart';
import '../models/group.dart';
import '../notify_controllers/connectivity_check.dart';
import '../services/group_service.dart';
import '../notify_controllers/groups_controller.dart';
import '../theme/app_theme.dart';
import 'overview_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
  });

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  void handleInvite(BuildContext context, String? inviteId) {
    if (inviteId != null) {
      joinGroupFromInviteId(inviteId).then((Group group) {
        if (!context.mounted) return;
        context.read<GroupsController>().saveGroups(group);
        var snackBar = SnackBar(
          content: Text('Successfully joined ${group.name}.'),
        );
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(snackBar);
      }).catchError((error) {
        if (!context.mounted) return;
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
  Widget build(BuildContext context) {
    final groupsController = context.read<GroupsController>();

    return DefaultTabController(
      initialIndex: 1,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Selector<GroupsController, Map<String, dynamic>>(
            selector: (_, GroupsController groupsController) =>
                groupsController.selectedGroup,
            builder: (_, Map<String, dynamic> selectedGroup, __) => Text(
              selectedGroup['name'] ?? 'No Group Found',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                    final isConnectedToInternet = context
                        .read<InternetConnectivityHelper>()
                        .isConnectedToInternet;
                    if (!isConnectedToInternet) {
                      ScaffoldMessenger.of(context)
                        ..removeCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('No Internet'),
                          ),
                        );
                      return;
                    }

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
              Tab(text: 'Overview'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        drawer: const MyDrawer(),
        body: Consumer<InternetConnectivityHelper>(
          builder: (_, internetConnectivity, __) {
            if (internetConnectivity.isConnectedToInternet) {
              return const TabBarView(
                children: <Widget>[
                  OverviewView(),
                  AllExpensesView(),
                ],
              );
            } else {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Image.asset(
                            'assets/images/offline.webp',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        "You're offline",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Check your connection to keep using Split.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: Consumer<InternetConnectivityHelper>(
          builder: (_, internetConnectivity, __) {
            if (internetConnectivity.isConnectedToInternet) {
              return ExpandableFloatingActionButton();
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}
