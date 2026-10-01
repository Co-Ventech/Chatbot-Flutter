import 'package:flutter/foundation.dart';
import 'package:chatbotapp/apis/ai_provider.dart';
import 'package:chatbotapp/apis/ai_types.dart';
import 'package:chatbotapp/apis/api_service.dart';

/// Owns provider selection, the user-provided API key, base URL, and model.
class AiConfigProvider extends ChangeNotifier {
  AiConfigProvider() {
    _refresh();
  }

  String _providerId = AiProviders.geminiId;
  bool _isConfigured = false;
  bool _busy = false;
  bool _loadingModels = false;
  String _maskedKey = '';
  String _source = 'Not set';
  String _model = '';
  String _baseUrl = '';
  List<String> _availableModels = const <String>[];
  String? _modelsError;

  List<AiProviderDescriptor> get providers => AiProviders.all;
  AiProviderDescriptor get descriptor => AiProviders.descriptor(_providerId);
  String get providerId => _providerId;
  bool get isConfigured => _isConfigured;
  bool get busy => _busy;
  bool get loadingModels => _loadingModels;
  String get maskedKey => _maskedKey;
  String get source => _source;
  String get model => _model;
  String get baseUrl => _baseUrl;
  List<String> get availableModels => _availableModels;
  String? get modelsError => _modelsError;

  void _refresh() {
    _providerId = ApiService.providerId;
    _isConfigured = ApiService.hasKeyFor(_providerId);
    _source = ApiService.sourceFor(_providerId);
    final storedKey = ApiService.storedKeyFor(_providerId);
    _maskedKey = storedKey.isEmpty ? '' : ApiService.maskKey(storedKey);
    _model = ApiService.modelFor(_providerId);
    _baseUrl = ApiService.baseUrlFor(_providerId);
  }

  Future<void> setProvider(String id) async {
    if (id == _providerId) return;
    _busy = true;
    notifyListeners();
    try {
      await ApiService.setProviderId(id);
      _availableModels = const <String>[];
      _modelsError = null;
    } finally {
      _busy = false;
      _refresh();
      notifyListeners();
    }
  }

  Future<void> saveKey(String key) async {
    _busy = true;
    notifyListeners();
    try {
      await ApiService.setKey(_providerId, key);
    } finally {
      _busy = false;
      _refresh();
      notifyListeners();
    }
  }

  Future<void> clearKey() async {
    _busy = true;
    notifyListeners();
    try {
      await ApiService.clearKey(_providerId);
    } finally {
      _busy = false;
      _refresh();
      notifyListeners();
    }
  }

  Future<void> saveModel(String model) async {
    _busy = true;
    notifyListeners();
    try {
      await ApiService.setModel(_providerId, model);
    } finally {
      _busy = false;
      _refresh();
      notifyListeners();
    }
  }

  Future<void> saveBaseUrl(String url) async {
    _busy = true;
    notifyListeners();
    try {
      await ApiService.setBaseUrl(_providerId, url);
    } finally {
      _busy = false;
      _refresh();
      notifyListeners();
    }
  }

  /// Returns `null` when the key works, otherwise a human-readable error.
  Future<String?> verifyKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return 'Enter an API key first.';
    }
    if (descriptor.requiresBaseUrl && _baseUrl.trim().isEmpty) {
      return 'Enter a base URL first.';
    }

    final provider = AiProviders.create(_providerId, baseUrl: _baseUrl);
    try {
      await provider.generateContent(
        turns: const [
          ChatTurn(role: 'user', text: 'Reply with the single word: OK'),
        ],
        apiKey: trimmed,
        model: _model,
        timeout: const Duration(seconds: 20),
        maxOutputTokens: 24,
      );
      return null;
    } on AiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not verify the key. Check your connection.';
    } finally {
      provider.dispose();
    }
  }

  /// Loads the models the key can access. Returns an error message or `null`.
  Future<String?> loadModels({String? key}) async {
    final typed = (key ?? '').trim();
    final activeKey =
        typed.isNotEmpty ? typed : ApiService.storedKeyFor(_providerId);
    if (activeKey.isEmpty) {
      _modelsError = 'Save or enter an API key first.';
      notifyListeners();
      return _modelsError;
    }
    if (descriptor.requiresBaseUrl && _baseUrl.trim().isEmpty) {
      _modelsError = 'Enter a base URL first.';
      notifyListeners();
      return _modelsError;
    }

    _loadingModels = true;
    _modelsError = null;
    notifyListeners();

    final provider = AiProviders.create(_providerId, baseUrl: _baseUrl);
    try {
      final models = await provider.listModels(
        apiKey: activeKey,
        timeout: const Duration(seconds: 20),
      );
      _availableModels = models;
      if (models.isEmpty) {
        _modelsError = 'No models returned for this key.';
      }
      return _modelsError;
    } on AiException catch (error) {
      _modelsError = error.message;
      return error.message;
    } catch (_) {
      _modelsError = 'Could not load models. Check your connection.';
      return _modelsError;
    } finally {
      _loadingModels = false;
      provider.dispose();
      notifyListeners();
    }
  }
}
