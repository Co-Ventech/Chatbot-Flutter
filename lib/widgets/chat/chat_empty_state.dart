import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chatbotapp/constants/constants.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.apiConfigured,
    required this.showStarterPrompts,
    required this.onSuggestionTap,
    required this.onAddApiKey,
  });

  final bool apiConfigured;
  final bool showStarterPrompts;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onAddApiKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 36),
          const _HeroBadge(),
          const SizedBox(height: 22),
          Text(
            'How can I help?',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              apiConfigured
                  ? 'Ask anything, or attach an image to analyze.'
                  : 'Connect your Gemini API key to get started.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showStarterPrompts && apiConfigured) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: Constants.starterPrompts
                    .map(
                      (prompt) => ActionChip(
                        avatar: const Icon(CupertinoIcons.sparkles, size: 14),
                        label: Text(prompt),
                        onPressed: () => onSuggestionTap(prompt),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (!apiConfigured) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAddApiKey,
              icon: const Icon(CupertinoIcons.lock_fill, size: 18),
              label: const Text('Add API key'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onAddApiKey,
              child: const Text('Choose a model'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Icon(
        CupertinoIcons.sparkles,
        color: colorScheme.onPrimary,
        size: 32,
      ),
    );
  }
}
