import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbotapp/providers/ai_config_provider.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';
import 'package:chatbotapp/widgets/app_screen_scaffold.dart';
import 'package:provider/provider.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  bool _obscure = true;
  bool _verifying = false;
  String? _keyError;
  String? _loadedProviderId;

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _syncFields(AiConfigProvider provider) {
    if (_loadedProviderId == provider.providerId) return;
    _loadedProviderId = provider.providerId;
    _modelController.text = provider.model;
    _baseUrlController.text = provider.baseUrl;
    _keyController.clear();
    _keyError = null;
  }

  Future<void> _saveKey(AiConfigProvider provider) async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _keyError = 'Enter an API key first.');
      return;
    }
    await provider.saveKey(key);
    if (!mounted) return;
    _keyController.clear();
    setState(() => _keyError = null);
    showAppSnackBar(context, 'API key saved');
  }

  Future<void> _verifyAndSave(AiConfigProvider provider) async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _keyError = 'Enter an API key first.');
      return;
    }
    if (provider.descriptor.requiresBaseUrl) {
      await provider.saveBaseUrl(_baseUrlController.text);
    }

    setState(() {
      _verifying = true;
      _keyError = null;
    });

    final result = await provider.verifyKey(key);
    if (!mounted) return;

    setState(() {
      _verifying = false;
      _keyError = result;
    });

    if (result == null) {
      await provider.saveKey(key);
      if (!mounted) return;
      _keyController.clear();
      showAppSnackBar(context, 'API key verified and saved');
    }
  }

  Future<void> _removeKey(AiConfigProvider provider) async {
    await provider.clearKey();
    if (!mounted) return;
    setState(() => _keyError = null);
    showAppSnackBar(context, 'API key removed');
  }

  Future<void> _loadModels(AiConfigProvider provider) async {
    final result = await provider.loadModels(key: _keyController.text);
    if (!mounted) return;
    if (result != null) {
      showAppSnackBar(context, result);
    } else {
      showAppSnackBar(
        context,
        '${provider.availableModels.length} models loaded',
      );
    }
  }

  Future<void> _saveModel(AiConfigProvider provider) async {
    final model = _modelController.text.trim();
    if (model.isEmpty) {
      showAppSnackBar(context, 'Enter a model id first');
      return;
    }
    await provider.saveModel(model);
    if (!mounted) return;
    showAppSnackBar(context, 'Model saved');
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showAppSnackBar(context, 'Link copied');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiConfigProvider>();
    _syncFields(provider);
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = provider.busy || _verifying;

    return AppScreenScaffold(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIconButton(
                  icon: CupertinoIcons.back,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.sparkles,
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI provider',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Key, endpoint & model',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Provider', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in provider.providers)
                  ChoiceChip(
                    label: Text(item.name),
                    selected: item.id == provider.providerId,
                    onSelected: disabled
                        ? null
                        : (_) => provider.setProvider(item.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _ConnectionCard(
              provider: provider,
              keyController: _keyController,
              baseUrlController: _baseUrlController,
              obscure: _obscure,
              verifying: _verifying,
              disabled: disabled,
              error: _keyError,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSave: () => _saveKey(provider),
              onVerify: () => _verifyAndSave(provider),
              onRemove: () => _removeKey(provider),
            ),
            const SizedBox(height: 18),
            Text('Model', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Load the models your key can access, or type an id '
                      'such as ${provider.descriptor.defaultModel.isEmpty ? "gpt-4o-mini" : provider.descriptor.defaultModel}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _modelController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Model id',
                        hintText: 'model-id',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                provider.loadingModels ? null : () => _loadModels(provider),
                            icon: provider.loadingModels
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(CupertinoIcons.refresh, size: 18),
                            label: const Text('Load models'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: disabled ? null : () => _saveModel(provider),
                            child: const Text('Save model'),
                          ),
                        ),
                      ],
                    ),
                    if (provider.modelsError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        provider.modelsError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                      ),
                    ],
                    if (provider.availableModels.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      AnimatedSize(
                        duration: AppMotion.regular,
                        curve: AppMotion.curve,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final model in provider.availableModels)
                              ChoiceChip(
                                label: Text(
                                  model,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                selected: model == _modelController.text.trim(),
                                onSelected: (_) {
                                  setState(() => _modelController.text = model);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (provider.descriptor.keyUrl.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const Icon(CupertinoIcons.link),
                  title: Text('Get a ${provider.descriptor.name} API key'),
                  subtitle: const Text('Tap to copy the link'),
                  trailing: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                  onTap: () => _copyLink(provider.descriptor.keyUrl),
                ),
              ),
            ],
            SizedBox(
              height: homeIndicatorSpacing(
                context,
                base: 10,
                factor: 0.1,
                maxExtra: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.provider,
    required this.keyController,
    required this.baseUrlController,
    required this.obscure,
    required this.verifying,
    required this.disabled,
    required this.error,
    required this.onToggleObscure,
    required this.onSave,
    required this.onVerify,
    required this.onRemove,
  });

  final AiConfigProvider provider;
  final TextEditingController keyController;
  final TextEditingController baseUrlController;
  final bool obscure;
  final bool verifying;
  final bool disabled;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSave;
  final VoidCallback onVerify;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final descriptor = provider.descriptor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: provider.isConfigured
                        ? colorScheme.primaryContainer
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.isConfigured
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.exclamationmark_circle,
                        size: 14,
                        color: provider.isConfigured
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isConfigured ? 'Connected' : 'Not connected',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: provider.isConfigured
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (provider.isConfigured)
                  Text(
                    provider.source,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            if (provider.maskedKey.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                provider.maskedKey,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Stored only on this device and never bundled into the app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (descriptor.requiresBaseUrl) ...[
              const SizedBox(height: 16),
              TextField(
                controller: baseUrlController,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: '${descriptor.name} API key',
                hintText: descriptor.keyHint,
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show' : 'Hide',
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: disabled ? null : onSave,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: disabled ? null : onVerify,
                    child: verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('Verify & save'),
                  ),
                ),
              ],
            ),
            if (provider.isConfigured) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: disabled ? null : onRemove,
                child: const Text('Remove key'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
