/// Push notifications through OneSignal on each platform.
///
/// `onesignal_flutter` has no web implementation (OneSignal closed Flutter
/// web support as not planned), so web builds use OneSignal's Web SDK
/// through JS interop instead. `dart:js_interop` doesn't compile for the
/// native apps, hence a conditional export. Both files must provide the same
/// functions: the analyzer only checks callers against the native one, so a
/// mismatch surfaces in `flutter build web`.
library;

export 'push_common.dart';
export 'push_native.dart' if (dart.library.js_interop) 'push_web.dart';
