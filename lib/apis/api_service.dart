import 'package:hive/hive.dart';
import 'package:chatbotapp/apis/ai_provider.dart';
import 'package:chatbotapp/apis/ai_types.dart';
import 'package:chatbotapp/constants/constants.dart';

/// Per-provider local configuration (key, model, base URL).
///
/// Nothing here is committed or bundled — values live in the on-device
/// `app_config` Hive box and are entered by the user in the app.
class ApiService {
  static const String _placeholderApiKey = 'your_google_ai_api_key';
  static const String _providerField = 'provider_id';

  static const Map<String, String> _dartDefineKeys = {
    AiProviders.geminiId: String.fromEnvironment('API_KEY'),
    AiProviders.openAiId: String.fromEnvironment('OPENAI_API_KEY'),
    AiProviders.anthropicId: String.fromEnvironment('ANTHROPIC_API_KEY'),
  };

  static Box<dynamic>? get _configBox =>
      Hive.isBoxOpen(Constants.apiKeyBox)
          ? Hive.box<dynamic>(Constants.apiKeyBox)
          : null;

  static String _stored(String field) {
    final value = _configBox?.get(field);
    return value is String ? value.trim() : '';
  }

  // --- Provider selection -------------------------------------------------

  static String get providerId {
    final stored = _stored(_providerField);
    return stored.isEmpty ? AiProviders.geminiId : stored;
  }

  static Future<void> setProviderId(String id) async {
    final box = _configBox ?? await Hive.openBox<dynamic>(Constants.apiKeyBox);
    await box.put(_providerField, id.trim());
  }

  static AiProviderDescriptor get descriptor => AiProviders.descriptor(providerId);

  // --- API keys -----------------------------------------------------------

  static String _keyField(String provider) => 'key_$provider';
  static String _modelField(String provider) => 'model_$provider';
  static String _baseUrlField(String provider) => 'base_url_$provider';

  static String buildTimeKeyFor(String provider) =>
      _sanitize(_dartDefineKeys[provider] ?? '');

  static String storedKeyFor(String provider) =>
      _sanitize(_stored(_keyField(provider)));

  static bool hasKeyFor(String provider) =>
      storedKeyFor(provider).isNotEmpty || buildTimeKeyFor(provider).isNotEmpty;

  static String apiKeyFor(String provider) {
    final key = storedKeyFor(provider).isNotEmpty
        ? storedKeyFor(provider)
        : buildTimeKeyFor(provider);
    if (key.isEmpty) {
      throw StateError(
        'Add your ${AiProviders.descriptor(provider).name} API key to continue.',
      );
    }
    return key;
  }

  static String sourceFor(String provider) {
    if (storedKeyFor(provider).isNotEmpty) return 'Saved in app';
    if (buildTimeKeyFor(provider).isNotEmpty) return 'Build (--dart-define)';
    return 'Not set';
  }

  static Future<void> setKey(String provider, String key) async {
    final box = _configBox ?? await Hive.openBox<dynamic>(Constants.apiKeyBox);
    await box.put(_keyField(provider), _sanitize(key));
  }

  static Future<void> clearKey(String provider) async {
    final box = _configBox ?? await Hive.openBox<dynamic>(Constants.apiKeyBox);
    await box.delete(_keyField(provider));
  }

  // --- Models -------------------------------------------------------------

  static String modelFor(String provider) {
    final stored = _stored(_modelField(provider));
    return stored.isEmpty
        ? AiProviders.descriptor(provider).defaultModel
        : stored;
  }

  static Future<void> setModel(String provider, String model) async {
    final box = _configBox ?? await Hive.openBox<dynamic>(Constants.apiKeyBox);
    final trimmed = model.trim();
    if (trimmed.isEmpty) {
      await box.delete(_modelField(provider));
    } else {
      await box.put(_modelField(provider), trimmed);
    }
  }

  // --- Base URL (custom / OpenAI-compatible endpoints) --------------------

  static String baseUrlFor(String provider) {
    final stored = _stored(_baseUrlField(provider));
    return stored.isEmpty
        ? AiProviders.descriptor(provider).defaultBaseUrl
        : stored;
  }

  static Future<void> setBaseUrl(String provider, String url) async {
    final box = _configBox ?? await Hive.openBox<dynamic>(Constants.apiKeyBox);
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await box.delete(_baseUrlField(provider));
    } else {
      await box.put(_baseUrlField(provider), trimmed);
    }
  }

  // --- Current provider convenience --------------------------------------

  static bool get isConfigured => hasKeyFor(providerId);
  static String get apiKey => apiKeyFor(providerId);
  static String get model => modelFor(providerId);
  static String get baseUrl => baseUrlFor(providerId);
  static String get source => sourceFor(providerId);

  /// Masks a key for display, e.g. `sk-1…4Yk`.
  static String maskKey(String key) {
    final trimmed = _sanitize(key);
    if (trimmed.length <= 8) return trimmed.isEmpty ? '' : '••••';
    return '${trimmed.substring(0, 4)}••••${trimmed.substring(trimmed.length - 4)}';
  }

  static String _sanitize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == _placeholderApiKey) return '';
    return trimmed;
  }
}
