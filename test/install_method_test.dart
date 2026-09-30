import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/utils/install_method.dart';

void main() {
  void expectMethod(
    String userAgent,
    TargetPlatform platform,
    InstallMethod expected,
  ) {
    expect(installMethodFor(userAgent, platform), expected,
        reason: userAgent);
  }

  test('iPhone and iPad browsers add to the Home Screen', () {
    for (final userAgent in [
      // Safari.
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
          'Mobile/15E148 Safari/604.1',
      // Chrome.
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0.6478.54 '
          'Mobile/15E148 Safari/604.1',
      // An iPad's Safari reports a Mac; Flutter still detects iOS.
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.5 Safari/605.1.15',
    ]) {
      expectMethod(userAgent, TargetPlatform.iOS, InstallMethod.iosHomeScreen);
    }
  });

  test("an iPhone in-app browser can't install", () {
    expectMethod(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 '
          'Instagram 337.0.3.23.54 (iPhone15,3; iOS 17_5; en_US; en)',
      TargetPlatform.iOS,
      InstallMethod.none,
    );
  });

  test('Android browsers offer Play and the web app', () {
    for (final userAgent in [
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like '
          'Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
      'Mozilla/5.0 (Android 14; Mobile; rv:127.0) Gecko/127.0 Firefox/127.0',
      'Mozilla/5.0 (Linux; Android 14; SAMSUNG SM-S918B) AppleWebKit/537.36 '
          '(KHTML, like Gecko) SamsungBrowser/25.0 Chrome/121.0.0.0 Mobile '
          'Safari/537.36',
    ]) {
      expectMethod(userAgent, TargetPlatform.android, InstallMethod.android);
    }
  });

  test("an Android in-app browser (a WebView) can't install", () {
    expectMethod(
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP1A.240505.004; wv) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
          'Chrome/125.0.6422.165 Mobile Safari/537.36 '
          '[FB_IAB/FB4A;FBAV/466.0.0.53.109;]',
      TargetPlatform.android,
      InstallMethod.none,
    );
  });

  test('Chromium browsers on a computer install', () {
    expectMethod(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, '
          'like Gecko) Chrome/126.0.0.0 Safari/537.36',
      TargetPlatform.windows,
      InstallMethod.desktop,
    );
    expectMethod(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, '
          'like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
      TargetPlatform.windows,
      InstallMethod.desktop,
    );
    // Chrome on a Mac carries Safari's token too; Chrome's wins.
    expectMethod(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      TargetPlatform.macOS,
      InstallMethod.desktop,
    );
    expectMethod(
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/126.0.0.0 Safari/537.36',
      TargetPlatform.linux,
      InstallMethod.desktop,
    );
  });

  test('Safari 17 or later on a Mac adds to the Dock', () {
    expectMethod(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.5 Safari/605.1.15',
      TargetPlatform.macOS,
      InstallMethod.macSafari,
    );
    expectMethod(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/16.6 Safari/605.1.15',
      TargetPlatform.macOS,
      InstallMethod.none,
    );
  });

  test("Firefox on a computer can't install", () {
    expectMethod(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.5; rv:127.0) '
          'Gecko/20100101 Firefox/127.0',
      TargetPlatform.macOS,
      InstallMethod.none,
    );
    expectMethod(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 '
          'Firefox/127.0',
      TargetPlatform.windows,
      InstallMethod.none,
    );
  });
}
