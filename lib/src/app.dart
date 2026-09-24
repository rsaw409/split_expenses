import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_expense/src/views/home.dart';

import 'notify_controllers/settings_controller.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'utils/invite_link.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
  });

  final GlobalKey<HomeViewState> homeStateGlobalKey =
      GlobalKey<HomeViewState>();

  Widget _buildHome(BuildContext context) => HomeView(key: homeStateGlobalKey);

  void _handleDeepLink(String routeName) {
    if (!isJoinGroupRoute(routeName)) return;

    final inviteId = inviteIdFromRoute(routeName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeStateGlobalKey.currentState?.handleInvite(inviteId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'app',
      supportedLocales: const [
        Locale('en', ''),
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<SettingsController>().themeMode,
      scrollBehavior: const AppScrollBehavior(),
      initialRoute: '/',
      routes: {
        '/': _buildHome,
      },
      // A cold-start deep link arrives as the initial route. Navigator's
      // default splits it into one route per path prefix and generates each,
      // so '/joinGroup/a/b' ran the invite handler for '/joinGroup' and
      // '/joinGroup/a' too, racing a truncated join against the real one.
      // Handling it here sees the whole link exactly once.
      onGenerateInitialRoutes: (initialRoute) {
        _handleDeepLink(initialRoute);
        return [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: Navigator.defaultRouteName),
            builder: _buildHome,
          ),
        ];
      },
      // A deep link while the app is running is pushed as a single name.
      onGenerateRoute: (settings) {
        _handleDeepLink(settings.name!);
        return null;
      },
    );
  }
}
