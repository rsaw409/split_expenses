import 'dart:async';

import 'package:flutter/material.dart';

import '../models/group.dart';
import '../services/backend.dart';
import '../services/group_service.dart';
import '../settings/groups_controller.dart';

class NewForm extends StatefulWidget {
  const NewForm(
      {super.key,
      required this.saveButtonText,
      required this.textFieldLabel,
      this.groupId,
      this.groupsController,
      this.inviteId});

  final String saveButtonText;
  final String textFieldLabel;

  final int? groupId;
  final GroupsController? groupsController;
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

  Future<void> addPersonInGroup(context) async {
    final res = await addUserInGroup(widget.groupId, myController.text);
    SnackBar snackBar;
    if (res == 'Success') {
      snackBar = SnackBar(
        content: Text('${myController.text} added in group.'),
      );
    } else {
      snackBar = const SnackBar(
        content: Text('something went wrong while adding person in group.'),
      );
    }
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Future<void> joinGroup(context) async {
    //  Join a group
    Group group = await joinGroupFromInviteId(myController.text);
    widget.groupsController?.saveGroups(group);

    Navigator.pop(context);

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
    widget.groupsController?.saveGroups(group);

    Navigator.pop(context);

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

      if (widget.groupId != null) {
        await addPersonInGroup(context);
      } else if (widget.saveButtonText == 'Join Group') {
        await joinGroup(context);
      } else if (widget.saveButtonText == 'Create Group') {
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
