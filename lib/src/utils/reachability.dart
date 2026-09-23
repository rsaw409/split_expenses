import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/backend_reachability.dart';

/// Watches backend reachability — use to disable write affordances while
/// Split cannot be reached.
bool watchIsReachable(BuildContext context) =>
    context.watch<BackendReachability>().isReachable;

/// Guards a write request, returning false and explaining when the backend
/// cannot be reached.
///
/// Every write path needs this even where its button is already disabled:
/// reachability can drop while a form is open, and pushed routes don't carry
/// the banner that `HomeView` shows.
bool requireReachable(
  BuildContext context, {
  String message = "Can't reach Split — check your connection and try again.",
}) {
  if (context.read<BackendReachability>().isReachable) {
    return true;
  }

  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return false;
}
