import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:split_expense/src/views/home.dart';

import 'settings/groups_controller.dart';
import 'settings/settings_controller.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    required this.settingsController,
    required this.groupsController,
  });

  final SettingsController settingsController;
  final GroupsController groupsController;

  final GlobalKey<HomeViewState> homeStateGlobalKey =
      GlobalKey<HomeViewState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          restorationScopeId: 'app',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
          ],
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          theme: ThemeData(),
          darkTheme: ThemeData.dark(),
          themeMode: settingsController.themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => HomeView(
                  key: homeStateGlobalKey,
                  settingsController: settingsController,
                  groupsController: groupsController,
                ),
          },
          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name!);
            final pathSegments = uri.pathSegments;

            if (pathSegments.isNotEmpty && pathSegments[0] == 'joinGroup') {
              final inviteId = pathSegments.length > 1 ? pathSegments[1] : null;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                homeStateGlobalKey.currentState?.handleInvite(inviteId);
              });
            }
            return null;
          },
        );
      },
    );
  }
}
