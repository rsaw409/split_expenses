import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/connectivity_check.dart';

/// Watches connectivity — use to disable write affordances while offline.
bool watchIsOnline(BuildContext context) =>
    context.watch<InternetConnectivityHelper>().isConnectedToInternet;

/// Guards a write request. Returns false (and explains) when offline.
///
/// Every write path needs this even where its button is already disabled:
/// connectivity can drop while a form is open, and pushed routes don't carry
/// the offline banner that `HomeView` shows.
bool requireOnline(
  BuildContext context, {
  String message = "You're offline — connect to make changes.",
}) {
  if (context.read<InternetConnectivityHelper>().isConnectedToInternet) {
    return true;
  }

  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return false;
}
