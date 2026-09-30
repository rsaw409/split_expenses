import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// The web app, through JS interop. See web_app.dart.

/// Whether this is a browser tab rather than the installed app. The manifest
/// sets `"display": "standalone"`, which is what an installed app reports,
/// from its Home Screen icon on iPhone (Safari supports the query from
/// iOS 12.2) or its app window elsewhere. Keep the two in step.
bool get runningInBrowserTab =>
    !web.window.matchMedia('(display-mode: standalone)').matches;

String get browserUserAgent => web.window.navigator.userAgent;

ValueNotifier<bool>? _promptAvailable;

/// Whether [promptInstall] can show the browser's install prompt right now.
///
/// Chromium browsers (Chrome, Edge, Samsung Internet) fire
/// `beforeinstallprompt` when the app can be installed, often before Flutter
/// has started, so flutter_bootstrap.js keeps the event as
/// `window.splitInstallPrompt`. It never fires once the app is installed, in
/// Safari or Firefox, or before the browser deems the app installable, and it
/// can arrive late, hence a listenable.
ValueListenable<bool> get installPromptAvailable {
  var notifier = _promptAvailable;
  if (notifier == null) {
    final created = _promptAvailable = ValueNotifier(_installPrompt != null);
    // flutter_bootstrap.js's listener, added first, has already stored it.
    web.window.addEventListener(
      'beforeinstallprompt',
      ((web.Event _) {
        created.value = _installPrompt != null;
      }).toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      ((web.Event _) {
        _installPrompt = null;
        created.value = false;
      }).toJS,
    );
    notifier = created;
  }
  return notifier;
}

/// Shows the browser's install prompt, and whether the user accepted. Must be
/// called from a tap handler, and calls `prompt()` before awaiting anything
/// so it stays inside the tap. A prompt event can only be used once.
Future<bool> promptInstall() async {
  final event = _installPrompt;
  if (event == null) return false;
  _installPrompt = null;
  _promptAvailable?.value = false;
  try {
    event.prompt();
    final choice = await event.userChoice.toDart;
    return choice.outcome == 'accepted';
  } catch (error) {
    debugPrint('Install prompt failed: $error');
    return false;
  }
}

@JS('splitInstallPrompt')
external _BeforeInstallPromptEvent? get _installPrompt;

@JS('splitInstallPrompt')
external set _installPrompt(_BeforeInstallPromptEvent? value);

extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<_InstallChoice> get userChoice;
}

extension type _InstallChoice._(JSObject _) implements JSObject {
  /// `accepted` or `dismissed`.
  external String get outcome;
}
