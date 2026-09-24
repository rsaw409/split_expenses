import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:split_expense/src/views/all_expenses_view.dart';
import 'package:split_expense/src/components/drawer.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../components/floating_action_button.dart';
import '../components/invite_dialog.dart';
import '../components/leave_group_dialog.dart';
import '../models/group.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/backend_reachability.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../services/api_exception.dart';
import '../services/group_service.dart';
import '../notify_controllers/groups_controller.dart';
import '../theme/app_theme.dart';
import '../utils/reachability.dart';
import 'overview_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
  });

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  late final OnNotificationClickListener _notificationClickListener;
  late final OnNotificationWillDisplayListener _notificationWillDisplayListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationClickListener = (event) => _refreshCurrentGroupData();
    _notificationWillDisplayListener = (event) => _refreshCurrentGroupData();
    OneSignal.Notifications.addClickListener(_notificationClickListener);
    OneSignal.Notifications
        .addForegroundWillDisplayListener(_notificationWillDisplayListener);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OneSignal.Notifications.removeClickListener(_notificationClickListener);
    OneSignal.Notifications
        .removeForegroundWillDisplayListener(_notificationWillDisplayListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after a while would otherwise keep showing cached data: the
    // controllers aren't rebuilt on resume and connectivity hasn't changed.
    if (state == AppLifecycleState.resumed) {
      _refreshCurrentGroupData();
    }
  }

  void _refreshCurrentGroupData() {
    if (!mounted) return;
    if (context.read<GroupsController>().selectedGroup['id'] == null) return;
    context.read<AllExpenseController>().refresh();
    context.read<UserBalanceController>().refresh();
  }

  /// Joins the group behind a `/joinGroup` deep link.
  ///
  /// Uses this state's own [context], which sits under the Scaffold. The
  /// caller in `app.dart` only has a context above `MaterialApp`, where there
  /// is no ScaffoldMessenger, so every snackbar here used to throw instead of
  /// showing.
  void handleInvite(String? inviteId) {
    if (!mounted) return;
    if (!requireReachable(context,
        message: "Can't reach Split — try joining again in a moment.")) {
      return;
    }

    if (inviteId != null) {
      joinGroupFromInviteId(inviteId).then((Group group) {
        if (!mounted) return;
        context.read<GroupsController>().saveGroups(group);
        var snackBar = SnackBar(
          content: Text('Successfully joined ${group.name}.'),
        );
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(snackBar);
      }).catchError((error) {
        if (!mounted) return;
        var snackBar = SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : "Can't reach Split — couldn't join this group.",
          ),
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

    final theme = Theme.of(context);

    return DefaultTabController(
      initialIndex: 1,
      length: 2,
      // Snackbars shown here must be fixed, not floating. ExpandableFab lays
      // itself out full-screen, and Scaffold places a floating snackbar above
      // the FAB's top edge, which is off the top of the screen: every snackbar
      // on this screen was silently invisible. A fixed one sits at the bottom
      // of the content, and ExpandableFab.location lifts the FAB above it.
      child: Theme(
        data: theme.copyWith(
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.fixed,
            backgroundColor: theme.snackBarTheme.backgroundColor,
            contentTextStyle: theme.snackBarTheme.contentTextStyle,
            actionTextColor: theme.snackBarTheme.actionTextColor,
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: Selector<GroupsController, Map<String, dynamic>>(
              selector: (_, GroupsController groupsController) =>
                  groupsController.selectedGroup,
              builder: (_, Map<String, dynamic> selectedGroup, __) => Text(
                selectedGroup['name'] ?? 'Split',
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
                      final groupName = groupsController.selectedGroup['name'];

                      final confirmed =
                          await showLeaveGroupDialog(context, groupName);
                      if (!confirmed) return;
                      if (!context.mounted) return;

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
          body: Column(
            children: [
              const _UnreachableBanner(),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    OverviewView(),
                    AllExpensesView(),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: ExpandableFab.location,
          floatingActionButton: Selector<GroupsController, bool>(
            selector: (_, controller) => controller.selectedGroup['id'] != null,
            builder: (context, hasGroup, __) {
              // Hidden outright with no group: every action needs one to attach
              // to, so the FAB used to open a menu whose three items all
              // silently did nothing. Joining or creating a group lives in the
              // drawer, which is what the empty state points at.
              if (!hasGroup) return const SizedBox.shrink();

              // Available even when Split is unreachable: each form checks
              // reachability on submit, so the user can fill it in offline and
              // retry without retyping.
              return ExpandableFloatingActionButton();
            },
          ),
        ),
      ),
    );
  }
}

class _UnreachableBanner extends StatelessWidget {
  const _UnreachableBanner();

  @override
  Widget build(BuildContext context) {
    if (context.watch<BackendReachability>().isReachable) {
      return const SizedBox.shrink();
    }

    // With no group there is nothing to be stale and nothing this banner can
    // usefully explain: the onboarding empty state is the message, and the
    // Join/Create forms report it themselves on submit.
    final expenses = context.watch<AllExpenseController>();
    if (expenses.groupId == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    // Nothing cached means nothing can be stale — don't claim otherwise.
    final hasData = expenses.items.isNotEmpty;

    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        hasData
            ? "Can't reach Split — data might be stale"
            : "Can't reach Split",
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: colorScheme.onErrorContainer),
      ),
    );
  }
}
