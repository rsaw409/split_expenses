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

ApiException apiExceptionFrom(http.Response response, String fallback) {
  String message = fallback;
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
  return ApiException(message, statusCode: response.statusCode);
}
