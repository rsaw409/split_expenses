import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown by the service layer on a non-200 response. [toString] returns a
/// plain, user-presentable message (no "Exception: " prefix), preferring the
/// server's own error message over [fallback] when the body carries one.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Builds the exception for a non-200 response, preferring the server's own
/// `message`/`error` over [fallback].
///
/// Pass `useServerMessage: false` for endpoints whose failure messages are not
/// fit to show a user. The invite endpoint is the known case: a mistyped code
/// comes back as a raw Node crypto error ("The \"buffer\" argument must be of
/// type string...") under a 400, so the status alone cannot tell a helpful
/// validation message apart from a leaked internal one.
ApiException apiExceptionFrom(
  http.Response response,
  String fallback, {
  bool useServerMessage = true,
}) {
  String message = fallback;
  if (useServerMessage) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      } else if (decoded is Map && decoded['error'] is String) {
        message = decoded['error'] as String;
      }
    } catch (_) {
      // Response body wasn't JSON with a message field; fall back to the generic message.
    }
  }
  return ApiException(message, statusCode: response.statusCode);
}
