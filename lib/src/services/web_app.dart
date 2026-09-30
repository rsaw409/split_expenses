/// Whether the web app runs in a browser tab or installed, and the browser's
/// own install prompt. The native apps are never in a tab. Split like
/// push.dart, since `dart:js_interop` doesn't compile for the native apps;
/// both files must provide the same members.
library;

export 'web_app_native.dart' if (dart.library.js_interop) 'web_app_web.dart';
