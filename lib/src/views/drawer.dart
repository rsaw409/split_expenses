import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_controller.dart';
import 'new_form.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer(
      {super.key,
      required this.groups,
      required this.settingsController,
      required this.callback});

  final SettingsController settingsController;
  final List<Map<String, dynamic>>? groups;
  final Function(Map<String, dynamic>) callback;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          SizedBox(
            height: 112,
            child: DrawerHeader(
              margin: const EdgeInsets.all(0.0),
              padding: const EdgeInsets.all(0.0),
              child: ListTile(
                // trailing: const Icon(Icons.edit),
                title: const Text('Groups'),
                onTap: () {},
              ),
            ),
          ),
          ...?groups?.map((group) => ListTile(
                title: Text(group['name']),
                onTap: () {
                  callback(group);
                  Navigator.pop(context);
                },
              )),
          if (groups != null && groups!.isNotEmpty) const Divider(),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Join group'),
            trailing: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: const Icon(Icons.add_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => NewForm(
                        settingsController: settingsController,
                        saveButtonText: 'Join Group',
                        textFieldLabel: 'Invite Id',
                        successCallBackForGroupJoin: callback,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Create group'),
            trailing: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: const Icon(Icons.add_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => NewForm(
                        settingsController: settingsController,
                        saveButtonText: 'Create Group',
                        textFieldLabel: 'Group Name',
                        successCallBackForGroupJoin: callback,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            trailing: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: settingsController.themeMode == ThemeMode.dark,
                onChanged: (val) {
                  if (val) {
                    settingsController.updateThemeMode(ThemeMode.dark);
                  } else {
                    settingsController.updateThemeMode(ThemeMode.light);
                  }
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Feedback'),
            onTap: () {
              if (Platform.isAndroid || Platform.isIOS) {
                final appId = Platform.isAndroid
                    ? 'developer.rohitsaw.split'
                    : 'YOUR_IOS_APP_ID';
                final url = Uri.parse(
                  Platform.isAndroid
                      ? "market://details?id=$appId"
                      : "https://apps.apple.com/app/id$appId",
                );
                launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
          ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              // onTap: () async {
              //   final Uri url = Uri.parse('https://portfolio.rsaw409.me/about');
              //   if (!await launchUrl(url)) {
              //     throw Exception('Could not launch $url');
              //   }
              // },
              onTap: () {
                showAboutDialog(
                    context: context,
                    applicationVersion: '1.0.1+4',
                    applicationName: "Split Expenses",
                    applicationIcon: Image.asset(
                      'assets/images/split.webp',
                      width: 50,
                      height: 50,
                    ),
                    children: [
                      Text('Key Features:'),
                      Divider(),
                      Text('Join or Create Group'),
                      Text('Record and split expenses in groups.'),
                      Text('Record payment made within  groups.'),
                      Text('Overview Dashboard to settle up easliy.'),
                      Divider(),
                      RichText(
                        text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Made with  ',
                              ),
                              TextSpan(
                                text: '\u2764',
                                style: TextStyle(
                                  fontFamily: 'EmojiOne',
                                ),
                              ),
                              TextSpan(
                                text: '  by rsaw409.',
                              ),
                            ],
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                      )
                    ]);
              }),
        ],
      ),
    );
  }
}
