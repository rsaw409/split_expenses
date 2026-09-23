import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:split_expense/src/services/api_exception.dart';

void main() {
  group('apiExceptionFrom', () {
    test('prefers the server message when it is fit to show', () {
      final exception = apiExceptionFrom(
        http.Response('{"message":"Group not found"}', 404),
        'Something went wrong.',
      );

      expect(exception.message, 'Group not found');
      expect(exception.statusCode, 404);
    });

    test('accepts an "error" field as well as "message"', () {
      expect(
        apiExceptionFrom(
          http.Response('{"error":"Group not found"}', 404),
          'Something went wrong.',
        ).message,
        'Group not found',
      );
    });

    test('falls back when the body is not JSON', () {
      expect(
        apiExceptionFrom(
          http.Response('<html>502 Bad Gateway</html>', 502),
          'Something went wrong.',
        ).message,
        'Something went wrong.',
      );
    });

    test('ignores the server message when asked to', () {
      // The real payload a mistyped invite code produces: a raw Node crypto
      // error, under a 400, which used to be shown to the user verbatim.
      final leaked =
          '{"message":"The \\"buffer\\" argument must be of type string or an '
          'instance of ArrayBuffer, Buffer, TypedArray, or DataView. '
          'Received undefined"}';

      final exception = apiExceptionFrom(
        http.Response(leaked, 400),
        'Invalid or expired invite code.',
        useServerMessage: false,
      );

      expect(exception.message, 'Invalid or expired invite code.');
      expect(exception.statusCode, 400,
          reason: 'the status is still worth keeping for diagnostics');
    });

    test('toString is the bare message, safe to show in a SnackBar', () {
      expect(
        apiExceptionFrom(
          http.Response('{"message":"Group not found"}', 404),
          'fallback',
        ).toString(),
        'Group not found',
        reason: 'no "Exception: " prefix',
      );
    });
  });
}
