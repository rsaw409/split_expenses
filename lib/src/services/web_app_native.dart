import 'package:flutter/foundation.dart';

// The native apps: installed by definition. See web_app.dart.

bool get runningInBrowserTab => false;

String get browserUserAgent => '';

final ValueListenable<bool> installPromptAvailable = ValueNotifier(false);

Future<bool> promptInstall() async => false;
