import 'dart:io';

import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/invite_link.dart';

const _handledKey = 'installReferrerHandled';

/// The invite that led to this install, returned at most once per install.
///
/// Someone without the app who opens an invite link is sent to the Play Store
/// with the invite in the install referrer, so their first launch can join
/// the group without them having to find the link again.
///
/// Marked handled once Play has answered, invite or not, so an ordinary
/// launch never re-joins a group the user has since left. If Play cannot be
/// reached (sideloaded or debug build, Play services missing, a timeout, or a
/// transient error) nothing is marked, and the next launch simply asks again.
Future<String?> takeInstallReferrerInvite() async {
  if (!Platform.isAndroid) return null;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_handledKey) ?? false) return null;

  final String? referrer;
  try {
    // The plugin waits on Play's callback with no deadline of its own; seen
    // on an emulator whose Play Store could not reach the network, where the
    // call never completed.
    final details = await PlayInstallReferrer.installReferrer
        .timeout(const Duration(seconds: 10));
    referrer = details.installReferrer;
  } catch (_) {
    return null;
  }

  await prefs.setBool(_handledKey, true);
  return inviteIdFromInstallReferrer(referrer);
}
