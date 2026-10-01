import 'dart:typed_data';

/// A single turn in a conversation, independent of any provider.
///
/// [role] is always `user` or `assistant`; each adapter maps it to its own
/// wire format.
class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.text,
    this.images = const <InlineImage>[],
  });

  final String role;
  final String text;
  final List<InlineImage> images;
}

/// Image bytes attached to a turn.
class InlineImage {
  const InlineImage({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

/// Error raised when an AI provider cannot fulfil a request.
class AiException implements Exception {
  const AiException({
    required this.message,
    this.statusCode,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

/// Static description of a supported provider.
class AiProviderDescriptor {
  const AiProviderDescriptor({
    required this.id,
    required this.name,
    required this.defaultModel,
    required this.keyHint,
    required this.keyUrl,
    this.requiresBaseUrl = false,
    this.defaultBaseUrl = '',
  });

  final String id;
  final String name;
  final String defaultModel;
  final String keyHint;
  final String keyUrl;
  final bool requiresBaseUrl;
  final String defaultBaseUrl;
}

/// Contract every AI provider adapter implements.
abstract class AiProvider {
  String get id;

  Future<String> generateContent({
    required List<ChatTurn> turns,
    required String apiKey,
    required String model,
    String systemInstruction,
    required Duration timeout,
    int maxOutputTokens,
  });

  Future<List<String>> listModels({
    required String apiKey,
    required Duration timeout,
  });

  /// Releases any underlying resources. Adapters may override.
  void dispose() {}
}
