import 'package:flutter/material.dart';
import 'package:split_expense/src/settings/settings_controller.dart';
import 'package:split_expense/src/views/drawer.dart';
import 'package:split_expense/src/views/group_view.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:split_expense/src/views/new_expense.dart';
import 'package:share_plus/share_plus.dart';

import '../settings/groups_controller.dart';
import 'new_form.dart';
import 'new_payment.dart';

class HomeView extends StatefulWidget {
  final SettingsController settingsController;
  final GroupsController groupsController;

  const HomeView({
    super.key,
    required this.settingsController,
    required this.groupsController,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

  @override
  void initState() {
    super.initState();
  }

  inviteToJoinGroup() async {
    final groupName = widget.groupsController.selectedGroup['name'];
    final inviteId = widget.groupsController.selectedGroup['inviteId'];
    const url =
        'https://play.google.com/store/apps/details?id=developer.rohitsaw.split';
    final userJoinLink = 'https://portfolio.rsaw409.me/joinGroup/$inviteId';

    final msg =
        'Join our group "$groupName".\n\n1. Download Split: $url\n2. Open this link on your smartphone: $userJoinLink\n\nEnter the following code: $inviteId';

    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Padding(
          padding:
              const EdgeInsets.only(top: 8.0, bottom: 8, left: 20, right: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.only(
                    left: 10.0, right: 10, top: 5, bottom: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  inviteId, // Your text
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Others can access your group using this code.')
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'OK'),
            child: const Text('LATER'),
          ),
          OutlinedButton(
            onPressed: () async {
              final result =
                  await Share.share(msg, subject: 'Look what I made!');
              if (result.status == ShareResultStatus.success) {
                var snackBar = SnackBar(
                  content: Text('Successfully share group: $groupName'),
                );
                if (!context.mounted) return;

                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(snackBar);
                Navigator.pop(context, 'OK');
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            ),
            child: const Text(
              'INVITE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  leaveGroup() async {
    final groupName = widget.groupsController.selectedGroup['name'];

    widget.groupsController.removeCurrentGroup();

    var snackBar = SnackBar(
      content: Text('Successfully leave group: $groupName'),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  void _addNewPersonInGroup() {
    if (widget.groupsController.selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => NewForm(
          groupId: widget.groupsController.selectedGroup['id'],
          saveButtonText: 'Save person',
          textFieldLabel: 'Person Name',
        ),
      ),
    );
  }

  void _addNewExpenseInGroup() {
    if (widget.groupsController.selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            NewExpense(groupId: widget.groupsController.selectedGroup['id']),
      ),
    );
  }

  void _addNewPaymentInGroup() {
    if (widget.groupsController.selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            NewPayment(groupId: widget.groupsController.selectedGroup['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 1,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.groupsController.selectedGroup['name'] ??
              'No Group Found'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<int>(
                onSelected: (item) async {
                  if (widget.groupsController.selectedGroup['name'] == null) {
                    return;
                  }
                  if (item == 0) {
                    await inviteToJoinGroup();
                  } else if (item == 1) {
                    await leaveGroup();
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
        drawer: MyDrawer(
          settingsController: widget.settingsController,
          groupsController: widget.groupsController,
        ),
        body:
            TabBarScreen(groupId: widget.groupsController.selectedGroup['id']),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: ExpandableFab(
          key: _fabKey,
          openButtonBuilder: RotateFloatingActionButtonBuilder(
            child: const Icon(Icons.add),
            fabSize: ExpandableFabSize.regular,
            shape: const CircleBorder(),
          ),
          type: ExpandableFabType.up,
          childrenAnimation: ExpandableFabAnimation.none,
          distance: 70,
          overlayStyle: ExpandableFabOverlayStyle(
              color: widget.settingsController.themeMode == ThemeMode.light
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.5)),
          children: [
            Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('New person'),
                    Text(
                      'Somebody to split costs with',
                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                    )
                  ],
                ),
                const SizedBox(width: 20),
                FloatingActionButton.small(
                  heroTag: null,
                  onPressed: _addNewPersonInGroup,
                  child: const Icon(Icons.person_2_outlined),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('New payment'),
                    Text(
                      'A payment made within the group',
                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                FloatingActionButton.small(
                  heroTag: null,
                  onPressed: _addNewPaymentInGroup,
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
            Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('New expense'),
                    Text(
                      'A purchase made for the group',
                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                FloatingActionButton.small(
                  heroTag: null,
                  onPressed: _addNewExpenseInGroup,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
