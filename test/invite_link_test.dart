import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:split_expense/src/components/invite_dialog.dart';
import 'package:split_expense/src/utils/invite_link.dart';

/// A real invite id from the live backend: base64-like, so it holds a `/`.
const inviteId = 'MxhZd6Rjv9iT+J9y:sLU=:d1KJXiJkaHE7eS/WyA8skw==';

/// What `onGenerateRoute` receives for [link]: the Android engine forwards the
/// still-encoded URL, and the framework decodes the whole route name
/// (`WidgetsApp.didPushRouteInformation` / `WidgetsBinding`).
String routeNameFor(Uri link) {
  final uri = Uri.parse(link.toString());
  return Uri.decodeComponent(Uri(path: uri.path).toString());
}

void main() {
  test('the link keeps an id containing "/" as one encoded segment', () {
    final link = inviteLink(inviteId);

    expect(link.host, inviteLinkHost);
    expect(link.pathSegments, ['joinGroup', inviteId]);
    expect(link.toString(), contains('%2F'));
  });

  test('an id survives the trip from link to route name', () {
    final routeName = routeNameFor(inviteLink(inviteId));

    // The framework has turned %2F back into a real slash by now...
    expect(routeName, '/joinGroup/$inviteId');
    // ...so reading only the next segment would truncate the id.
    expect(inviteIdFromRoute(routeName), inviteId);
  });

  test('links shared before encoding still parse', () {
    expect(inviteIdFromRoute('/joinGroup/$inviteId'), inviteId);
  });

  test('an id starting with "/" survives, as the backend does issue them', () {
    const leading = '/y4YidFAs84c69RQ:EZQ=:OSTPPuiui0kx+B7ABPUurA==';

    // Decoded warm-start name ('/joinGroup//y4…') and raw cold-start URL.
    expect(inviteIdFromRoute(routeNameFor(inviteLink(leading))), leading);
    expect(inviteIdFromRoute(inviteLink(leading).toString()), leading);
  });

  test('ids without a slash are unaffected', () {
    const plain = 'abc+def=:ghi==';
    expect(inviteIdFromRoute(routeNameFor(inviteLink(plain))), plain);
  });

  test('a join route without an id is recognised but has no id', () {
    expect(isJoinGroupRoute('/joinGroup'), isTrue);
    expect(inviteIdFromRoute('/joinGroup'), isNull);
    expect(inviteIdFromRoute('/joinGroup/'), isNull);
  });

  test('other routes are not join routes', () {
    expect(isJoinGroupRoute('/'), isFalse);
    expect(isJoinGroupRoute('/settings'), isFalse);
    expect(inviteIdFromRoute('/settings/abc'), isNull);
  });

  testWidgets('the invite dialog shows a QR code and the code',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showInviteDialog(context, 'Goa Trip', inviteId),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, 'QR code to join Goa Trip');
    expect(find.text(inviteId), findsOneWidget);
    // Laying the dialog out at all is the point: AlertDialog asks its content
    // for intrinsic sizes, which QrImageView (a LayoutBuilder) cannot answer.
    // Its payload is private; the inviteLink tests above pin it instead.
  });
}
