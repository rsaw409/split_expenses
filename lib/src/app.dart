import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/views/home.dart';

import 'notify_controllers/settings_controller.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
  });

  final GlobalKey<HomeViewState> homeStateGlobalKey =
      GlobalKey<HomeViewState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'app',
      supportedLocales: const [
        Locale('en', ''),
      ],
      theme: ThemeData(
        appBarTheme: AppBarTheme(backgroundColor: Colors.deepPurple.shade50),
        drawerTheme:
            DrawerThemeData(backgroundColor: Colors.deepPurple.shade50),
      ),
      darkTheme: ThemeData.dark(),
      themeMode: context.watch<SettingsController>().themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => HomeView(
              key: homeStateGlobalKey,
            ),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name!);
        final pathSegments = uri.pathSegments;

        if (pathSegments.isNotEmpty && pathSegments[0] == 'joinGroup') {
          final inviteId = pathSegments.length > 1 ? pathSegments[1] : null;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            homeStateGlobalKey.currentState?.handleInvite(context, inviteId);
          });
        }
        return null;
      },
    );
  }
}
