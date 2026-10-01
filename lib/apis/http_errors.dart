import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_types.dart';

/// Maps a non-2xx HTTP response to a friendly [AiException].
AiException httpError(http.Response response) {
  String? apiMessage;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        apiMessage = error['message'] as String;
      } else if (error is String) {
        apiMessage = error;
      } else if (decoded['message'] is String) {
        apiMessage = decoded['message'] as String;
      }
    }
  } catch (_) {
    // Ignore malformed bodies.
  }

  final status = response.statusCode;
  final message = switch (status) {
    400 => apiMessage ?? 'The request was rejected.',
    401 || 403 => 'Invalid API key. Check your key and try again.',
    404 => 'Model or endpoint not found. Check the model id and base URL.',
    429 => 'Rate limit reached. Wait a moment and try again.',
    >= 500 => 'The provider is temporarily unavailable. Try again shortly.',
    _ => apiMessage ?? 'Something went wrong. Please try again.',
  };

  return AiException(
    message: message,
    statusCode: status,
    retryable: status == 429 || status >= 500,
  );
}

const AiException networkError = AiException(
  message: 'Could not reach the provider. Check your network and try again.',
  retryable: true,
);

const AiException timeoutError = AiException(
  message: 'Request timed out. Check your connection and try again.',
  retryable: true,
);

const AiException malformedResponse = AiException(
  message: 'Unexpected response from the provider.',
);
