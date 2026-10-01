import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_types.dart';
import '../http_errors.dart';

/// Anthropic Claude adapter (`api.anthropic.com`).
class AnthropicProvider implements AiProvider {
  AnthropicProvider({
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.apiVersion = '2023-06-01',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiVersion;
  final http.Client _httpClient;

  @override
  String get id => 'anthropic';

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
    final uri = Uri.parse('$_root/messages');
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxOutputTokens,
      if (systemInstruction.trim().isNotEmpty) 'system': systemInstruction,
      'messages': turns.map(_encodeTurn).toList(growable: false),
    };

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': apiVersion,
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
          .get(
            uri,
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': apiVersion,
            },
          )
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
    return {
      'role': role,
      'content': [
        if (turn.text.trim().isNotEmpty) {'type': 'text', 'text': turn.text},
        for (final image in turn.images)
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          },
      ],
    };
  }

  String _extractText(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw malformedResponse;

    final content = decoded['content'];
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['type'] == 'text' && part['text'] is String) {
          buffer.write(part['text']);
        }
      }
      if (buffer.isNotEmpty) return buffer.toString().trim();
    }

    final stopReason = decoded['stop_reason'];
    if (stopReason == 'refusal') {
      throw const AiException(message: 'The response was refused. Try rephrasing.');
    }
    throw const AiException(message: 'No response returned. Try again.', retryable: true);
  }
}
