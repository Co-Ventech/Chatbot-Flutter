import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_types.dart';
import '../http_errors.dart';

/// Adapter for OpenAI and any OpenAI-compatible endpoint
/// (OpenRouter, Groq, Together, local servers, etc.).
class OpenAiProvider implements AiProvider {
  OpenAiProvider({
    this.baseUrl = 'https://api.openai.com/v1',
    this.id = 'openai',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;

  @override
  final String id;

  final http.Client _httpClient;

  @override
  void dispose() => _httpClient.close();

  String get _root => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  @override
  Future<String> generateContent({
    required List<ChatTurn> turns,
    required String apiKey,
    required String model,
    String systemInstruction = '',
    required Duration timeout,
    int maxOutputTokens = 4096,
  }) async {
    final uri = Uri.parse('$_root/chat/completions');
    final messages = <Map<String, dynamic>>[
      if (systemInstruction.trim().isNotEmpty)
        {'role': 'system', 'content': systemInstruction},
      for (final turn in turns) _encodeTurn(turn),
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'max_tokens': maxOutputTokens,
    };

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw timeoutError;
    } catch (_) {
      throw networkError;
    }

    if (response.statusCode != 200) throw httpError(response);
    return _extractText(response.body);
  }

  @override
  Future<List<String>> listModels({
    required String apiKey,
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$_root/models');

    late final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
          .timeout(timeout);
    } on TimeoutException {
      throw timeoutError;
    } catch (_) {
      throw networkError;
    }

    if (response.statusCode != 200) throw httpError(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw malformedResponse;

    final data = decoded['data'];
    final models = <String>[];
    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final id = item['id'];
        if (id is String && id.isNotEmpty) models.add(id);
      }
    }
    models.sort();
    return models;
  }

  Map<String, dynamic> _encodeTurn(ChatTurn turn) {
    final role = turn.role == 'assistant' ? 'assistant' : 'user';
    if (turn.images.isEmpty) {
      return {'role': role, 'content': turn.text};
    }

    return {
      'role': role,
      'content': [
        if (turn.text.trim().isNotEmpty)
          {'type': 'text', 'text': turn.text},
        for (final image in turn.images)
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
            },
          },
      ],
    };
  }

  String _extractText(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw malformedResponse;

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiException(message: 'No response returned. Try again.', retryable: true);
    }

    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;

    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }

    // Some providers return content as a list of parts.
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text']);
        }
      }
      if (buffer.isNotEmpty) return buffer.toString().trim();
    }

    final finishReason = first is Map ? first['finish_reason'] : null;
    if (finishReason == 'content_filter') {
      throw const AiException(
        message: 'The response was blocked. Try rephrasing.',
      );
    }
    throw const AiException(message: 'No response returned. Try again.', retryable: true);
  }
}
