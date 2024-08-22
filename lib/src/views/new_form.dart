import 'dart:async';

import 'package:flutter/material.dart';
import 'package:split_expense/src/settings/settings_controller.dart';

import '../models/group.dart';
import '../services/backend.dart';

class NewForm extends StatelessWidget {
  NewForm(
      {super.key,
      required this.saveButtonText,
      required this.textFieldLabel,
      this.groupId,
      this.settingsController,
      this.successCallBackForGroupJoin,
      this.inviteId}) {
    myController = TextEditingController(text: inviteId);
  }

  final String saveButtonText;
  final String textFieldLabel;

  final int? groupId;
  final SettingsController? settingsController;
  final Function(Map<String, dynamic>)? successCallBackForGroupJoin;
  final String? inviteId;

  late final TextEditingController myController;

  Future<void> addPersonInGroup(context) async {
    //  Add a Person
    await addUserInGroup(groupId, myController.text);
    var snackBar = SnackBar(
      content: Text('${myController.text} added in group.'),
    );
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Future<void> joinGroup(context) async {
    //  Join a group
    Group group = await joinGroupFromInviteId(myController.text);
    settingsController?.saveGroups(group.toMap());

    Navigator.pop(context);
    successCallBackForGroupJoin!(group.toMap());

    var snackBar = SnackBar(
      content: Text('Successfully joined ${group.name}.'),
    );
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Future<void> createAndJoinGroup(context) async {
    //  Create a group
    Group group = await createGroup(myController.text);
    settingsController?.saveGroups(group.toMap());

    Navigator.pop(context);
    successCallBackForGroupJoin!(group.toMap());

    var snackBar = SnackBar(
      content: Text('Successfully create group: ${group.name}.'),
    );
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Future _saveTextFieldValue(context) async {
    try {
      if (myController.text.trim().isEmpty) {
        throw 'Field cannot be empty';
      }

      if (groupId != null) {
        await addPersonInGroup(context);
      } else if (saveButtonText == 'Join Group') {
        await joinGroup(context);
      } else if (saveButtonText == 'Create Group') {
        await createAndJoinGroup(context);
      }
      return Future.value(true);
    } catch (error) {
      var snackBar = SnackBar(
        content: Text('$error'),
      );
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
                _saveTextFieldValue(context).then((isSuccess) {
                  if (isSuccess == true) {
                    Navigator.pop(context);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(saveButtonText),
              ))
        ],
      ),
      body: Material(
        elevation: 5,
        child: Row(
          children: [
            const SizedBox(
              width: 50,
            ),
            Text(textFieldLabel),
            const SizedBox(
              width: 100,
            ),
            Expanded(
              child: TextField(
                controller: myController,
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
