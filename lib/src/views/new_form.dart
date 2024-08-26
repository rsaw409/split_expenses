import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/settings/userbalances_controller.dart';

import '../models/group.dart';
import '../services/backend.dart';
import '../services/group_service.dart';
import '../settings/groups_controller.dart';

class NewForm extends StatefulWidget {
  const NewForm({
    super.key,
    required this.saveButtonText,
    required this.textFieldLabel,
    this.inviteId,
  });

  final String saveButtonText;
  final String textFieldLabel;

  final String? inviteId;

  @override
  State<NewForm> createState() => _NewFormState();
}

class _NewFormState extends State<NewForm> {
  late final TextEditingController myController;

  @override
  void initState() {
    super.initState();
    myController = TextEditingController(text: widget.inviteId);
  }

  @override
  void dispose() {
    super.dispose();
    myController.dispose();
  }

  _saveTextFieldValue(BuildContext context, GroupsController groupsController,
      UserBalanceController userBalanceController) async {
    try {
      if (myController.text.trim().isEmpty) {
        throw 'Field cannot be empty';
      }

      SnackBar snackBar = const SnackBar(content: Text('No action performed.'));

      if (widget.saveButtonText == 'Save person') {
        final groupId = groupsController.selectedGroup['id'];
        await addUserInGroup(groupId, myController.text);

        userBalanceController.refresh();
        snackBar = SnackBar(
          content: Text('${myController.text} added in group.'),
        );
      } else if (widget.saveButtonText == 'Join Group') {
        Group group = await joinGroupFromInviteId(myController.text);
        await groupsController.saveGroups(group);
        snackBar = SnackBar(
          content: Text(
              'Successfully joined ${groupsController.selectedGroup["name"]}.'),
        );
        if (!context.mounted) return;
        Navigator.pop(context);
      } else if (widget.saveButtonText == 'Create Group') {
        Group group = await createGroup(myController.text);
        await groupsController.saveGroups(group);
        snackBar = SnackBar(
          content: Text(
              'Successfully create group: ${groupsController.selectedGroup["name"]}.'),
        );
        if (!context.mounted) return;
        Navigator.pop(context);
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(snackBar);

      return Future.value(true);
    } catch (error) {
      final snackBar = SnackBar(
        content: Text('$error'),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(snackBar);
      return Future.value(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
              onPressed: () {
                final groupsController = context.read<GroupsController>();
                final userBalanceController =
                    context.read<UserBalanceController>();
                _saveTextFieldValue(
                        context, groupsController, userBalanceController)
                    .then((isSuccess) {
                  if (isSuccess == true) {
                    Navigator.pop(context);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(widget.saveButtonText),
              ))
        ],
      ),
      body: Material(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: TextField(
            controller: myController,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              labelText: widget.textFieldLabel,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
      ),
    );
  }
}
