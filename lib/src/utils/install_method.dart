import 'package:flutter/foundation.dart';

/// How a browser tab can install the web app, which is where notifications
/// work (see views/install_gate_view.dart).
enum InstallMethod {
  /// Installing is impossible here: Firefox on desktop, in-app browsers
  /// (Instagram's, Facebook's and other WebViews), Safari before 17 on Mac.
  none,

  /// iPhone and iPad, in any browser: Share, then Add to Home Screen.
  iosHomeScreen,

  /// The Android app from Google Play, or the web app through the browser.
  android,

  /// Chrome, Edge and other Chromium browsers on a computer.
  desktop,

  /// Safari 17 or later on a Mac: File, then Add to Dock.
  macSafari,
}

/// The install method for a browser, from Flutter's [platform] (which
/// detects iPads that report themselves as Macs) and its [userAgent].
InstallMethod installMethodFor(String userAgent, TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
      // Safari, Chrome, Edge and Firefox all carry Safari's token and can
      // Add to Home Screen (iOS 16.4+). In-app browsers built on a bare
      // WKWebView omit it, and can't.
      return userAgent.contains('Safari/')
          ? InstallMethod.iosHomeScreen
          : InstallMethod.none;
    case TargetPlatform.android:
      // Android WebViews, what in-app browsers use, mark themselves "wv".
      return userAgent.contains('; wv)')
          ? InstallMethod.none
          : InstallMethod.android;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      if (userAgent.contains('Firefox/')) return InstallMethod.none;
      // Chrome, Edge, Opera and Brave all carry Chrome's token.
      if (userAgent.contains('Chrome/')) return InstallMethod.desktop;
      if (platform == TargetPlatform.macOS &&
          userAgent.contains('Safari/') &&
          _safariVersion(userAgent) >= 17) {
        return InstallMethod.macSafari;
      }
      return InstallMethod.none;
    case TargetPlatform.fuchsia:
      return InstallMethod.none;
  }
}

int _safariVersion(String userAgent) {
  final match = RegExp(r'Version/(\d+)').firstMatch(userAgent);
  return match == null ? 0 : int.parse(match.group(1)!);
}
