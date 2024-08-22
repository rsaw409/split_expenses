import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:split_expense/src/views/home.dart';

import 'settings/settings_controller.dart';
import 'views/new_form.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

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
          onGenerateInitialRoutes: (String initialRouteName) {
            List<Route<dynamic>> routes = [
              MaterialPageRoute(
                builder: (context) =>
                    HomeView(settingsController: settingsController),
              )
            ];

            if (initialRouteName != '/') {
              final uri = Uri.parse(initialRouteName);
              final pathSegments = uri.pathSegments;

              if (pathSegments.isNotEmpty) {
                if (pathSegments[0] == 'joinGroup') {
                  final groupId =
                      pathSegments.length > 1 ? pathSegments[1] : null;
                  routes.add(
                    MaterialPageRoute(
                      builder: (_) => NewForm(
                          saveButtonText: 'Join Group',
                          textFieldLabel: 'Invite Id',
                          settingsController: settingsController,
                          inviteId: groupId,
                          successCallBackForGroupJoin: (group) {}),
                    ),
                  );
                }
              }
            }

            return routes;
          },
          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name!);
            final pathSegments = uri.pathSegments;

            if (pathSegments.isNotEmpty) {
              if (pathSegments[0] == 'joinGroup') {
                final groupId =
                    pathSegments.length > 1 ? pathSegments[1] : null;
                return MaterialPageRoute(
                  builder: (_) => NewForm(
                      saveButtonText: 'Join Group',
                      textFieldLabel: 'Invite Id',
                      settingsController: settingsController,
                      inviteId: groupId,
                      successCallBackForGroupJoin: (group) {}),
                );
              }
            }
            return MaterialPageRoute(
              builder: (_) => HomeView(settingsController: settingsController),
            );
          },
        );
      },
    );
  }
}
