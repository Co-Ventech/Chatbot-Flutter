import 'ai_types.dart';
import 'providers/anthropic_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';

/// Registry of supported AI providers and their metadata.
abstract final class AiProviders {
  static const String geminiId = 'gemini';
  static const String openAiId = 'openai';
  static const String anthropicId = 'anthropic';
  static const String customId = 'custom';

  static const AiProviderDescriptor gemini = AiProviderDescriptor(
    id: geminiId,
    name: 'Google Gemini',
    defaultModel: 'gemini-3.8-flash',
    keyHint: 'AIza…',
    keyUrl: 'https://aistudio.google.com/app/apikey',
  );

  static const AiProviderDescriptor openAi = AiProviderDescriptor(
    id: openAiId,
    name: 'OpenAI',
    defaultModel: 'gpt-4o-mini',
    keyHint: 'sk-…',
    keyUrl: 'https://platform.openai.com/api-keys',
  );

  static const AiProviderDescriptor anthropic = AiProviderDescriptor(
    id: anthropicId,
    name: 'Anthropic Claude',
    defaultModel: 'claude-3-5-sonnet-latest',
    keyHint: 'sk-ant-…',
    keyUrl: 'https://console.anthropic.com/settings/keys',
  );

  static const AiProviderDescriptor custom = AiProviderDescriptor(
    id: customId,
    name: 'Custom (OpenAI-compatible)',
    defaultModel: '',
    keyHint: 'API key',
    keyUrl: '',
    requiresBaseUrl: true,
    defaultBaseUrl: 'https://api.openai.com/v1',
  );

  static const List<AiProviderDescriptor> all = [
    gemini,
    openAi,
    anthropic,
    custom,
  ];

  static AiProviderDescriptor descriptor(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return gemini;
  }

  static AiProvider create(String id, {String baseUrl = ''}) {
    switch (id) {
      case openAiId:
        return OpenAiProvider(
          baseUrl: 'https://api.openai.com/v1',
          id: openAiId,
        );
      case anthropicId:
        return AnthropicProvider();
      case customId:
        return OpenAiProvider(
          baseUrl: baseUrl.trim().isEmpty ? custom.defaultBaseUrl : baseUrl.trim(),
          id: customId,
        );
      case geminiId:
      default:
        return GeminiProvider();
    }
  }
}
