import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_types.dart';
import '../http_errors.dart';

/// Google Gemini adapter (`generativelanguage.googleapis.com`).
class GeminiProvider implements AiProvider {
  GeminiProvider({
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  @override
  String get id => 'gemini';

  @override
  void dispose() => _httpClient.close();

  @override
  Future<String> generateContent({
    required List<ChatTurn> turns,
    required String apiKey,
    required String model,
    String systemInstruction = '',
    required Duration timeout,
    int maxOutputTokens = 4096,
  }) async {
    final uri = Uri.parse('$baseUrl/models/$model:generateContent');
    final body = <String, dynamic>{
      'contents': turns.map(_encodeTurn).toList(growable: false),
      if (systemInstruction.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'thinkingConfig': {'thinkingLevel': 'low'},
      },
    };

    final response = await _post(uri, apiKey, body, timeout);
    if (response.statusCode != 200) throw httpError(response);
    return _extractText(response.body);
  }

  @override
  Future<List<String>> listModels({
    required String apiKey,
    required Duration timeout,
  }) async {
    final models = <String>[];
    String? pageToken;
    var page = 0;

    do {
      final uri = Uri.parse('$baseUrl/models').replace(
        queryParameters: {
          'pageSize': '100',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );

      late final http.Response response;
      try {
        response = await _httpClient
            .get(uri, headers: {'x-goog-api-key': apiKey})
            .timeout(timeout);
      } on TimeoutException {
        throw timeoutError;
      } catch (_) {
        throw networkError;
      }

      if (response.statusCode != 200) throw httpError(response);

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw malformedResponse;

      final items = decoded['models'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final name = item['name'];
          final methods = item['supportedGenerationMethods'];
          final supportsGenerate =
              methods is List && methods.contains('generateContent');
          if (name is String && supportsGenerate) {
            models.add(name.startsWith('models/') ? name.substring(7) : name);
          }
        }
      }

      final next = decoded['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
      page++;
    } while (pageToken != null && page < 5);

    models.sort();
    return models;
  }

  Future<http.Response> _post(
    Uri uri,
    String apiKey,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
    try {
      return await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw timeoutError;
    } catch (_) {
      throw networkError;
    }
  }

  Map<String, dynamic> _encodeTurn(ChatTurn turn) {
    return {
      'role': turn.role == 'assistant' ? 'model' : 'user',
      'parts': [
        if (turn.text.trim().isNotEmpty) {'text': turn.text},
        for (final image in turn.images)
          {
            'inlineData': {
              'mimeType': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          },
      ],
    };
  }

  String _extractText(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw malformedResponse;

    final feedback = decoded['promptFeedback'];
    final blockReason = feedback is Map ? feedback['blockReason'] : null;
    if (blockReason is String && blockReason.isNotEmpty) {
      throw AiException(
        message: 'The prompt was blocked ($blockReason). Try rephrasing it.',
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiException(message: 'No response returned. Try again.', retryable: true);
    }

    final candidate = candidates.first;
    final content = candidate is Map ? candidate['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) throw _finishReasonError(candidate);

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String) buffer.write(text);
    }

    if (buffer.isEmpty) throw _finishReasonError(candidate);
    return buffer.toString().trim();
  }

  AiException _finishReasonError(Object? candidate) {
    final finishReason = candidate is Map ? candidate['finishReason'] : null;
    final reason = finishReason is String ? finishReason : 'UNKNOWN';
    final message = switch (reason) {
      'SAFETY' || 'PROHIBITED_CONTENT' =>
        'The response was blocked for safety reasons. Try rephrasing.',
      'MAX_TOKENS' => 'The response was cut off. Try a shorter request.',
      'RECITATION' => 'The response was blocked (recitation). Try rephrasing.',
      _ => 'No response returned. Try again.',
    };
    return AiException(message: message, retryable: reason == 'UNKNOWN');
  }
}
