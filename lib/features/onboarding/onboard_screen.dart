import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/llm_response.dart';
import '../../core/providers/provider_factory.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../shared/constants.dart';

/// First-launch onboarding: select provider, enter API key, test, save.
class OnboardScreen extends ConsumerStatefulWidget {
  const OnboardScreen({super.key});

  @override
  ConsumerState<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends ConsumerState<OnboardScreen> {
  final _pageController = PageController();
  final _apiKeyController = TextEditingController();
  int _currentPage = 0;
  String _selectedProvider = AppConstants.defaultProvider;
  bool _testing = false;
  bool _testPassed = false;
  String? _testMessage;

  List<(String, String, String)> _providers(AppLocalizations l) => [
    ('openrouter', l.providerOpenRouter, l.providerOpenRouterDesc),
    ('anthropic', l.providerAnthropic, l.providerAnthropicDesc),
    ('openai', l.providerOpenAI, l.providerOpenAIDesc),
    ('groq', l.providerGroq, l.providerGroqDesc),
    ('gemini', l.providerGemini, l.providerGeminiDesc),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _testMessage = AppLocalizations.of(context).onboardEnterApiKeyError);
      return;
    }

    setState(() {
      _testing = true;
      _testMessage = null;
      _testPassed = false;
    });

    try {
      final provider = ProviderFactory.create(
        name: _selectedProvider,
        config: const ProviderConfig(apiBase: ''),
        apiKey: apiKey,
      );

      final response = await provider.chat(
        messages: [
          const Message(role: 'user', content: 'Say "hello" in one word.'),
        ],
        model: provider.defaultModel,
        options: {'max_tokens': 50, 'temperature': 0},
      );

      setState(() {
        _testPassed = true;
        _testMessage = AppLocalizations.of(context).onboardTestSuccess(response.content);
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testPassed = false;
        _testMessage = AppLocalizations.of(context).commonFailed(e.toString());
        _testing = false;
      });
    }
  }

  Future<void> _complete() async {
    final configStorage = ref.read(configStorageProvider);
    final apiKey = _apiKeyController.text.trim();

    // Save API key
    await configStorage.setApiKey(_selectedProvider, apiKey);

    // Save config
    final config = AppConfig(
      agent: AgentConfig(
        provider: _selectedProvider,
        model: ProviderFactory.create(
          name: _selectedProvider,
          config: const ProviderConfig(apiBase: ''),
          apiKey: apiKey,
        ).defaultModel,
      ),
      providers: {
        _selectedProvider: const ProviderConfig(apiBase: ''),
      },
    );

    await configStorage.save(config);
    await configStorage.setOnboardingComplete();
    ref.read(appConfigProvider.notifier).update(config);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(theme),
                  _buildProviderPage(theme),
                  _buildApiKeyPage(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ThemeData theme) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 96,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            l.onboardWelcome,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l.onboardSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _nextPage,
            child: Text(l.onboardGetStarted),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPage(ThemeData theme) {
    final l = AppLocalizations.of(context);
    final providers = _providers(l);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(l.onboardChooseProvider, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l.onboardChooseProviderSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(providers.length, (i) {
            final (id, name, desc) = providers[i];
            final selected = _selectedProvider == id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(name),
                subtitle: Text(desc),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                onTap: () => setState(() => _selectedProvider = id),
              ),
            );
          }),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _nextPage,
              child: Text(l.onboardNext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyPage(ThemeData theme) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(l.onboardEnterApiKey, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l.onboardApiKeySecure,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l.onboardApiKeyLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _testing ? null : _testConnection,
            child: _testing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.onboardTestConnection),
          ),
          if (_testMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _testMessage!,
              style: TextStyle(
                color: _testPassed ? Colors.green : Colors.red,
              ),
            ),
          ],
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _testPassed ? _complete : null,
              child: Text(l.onboardFinishSetup),
            ),
          ),
        ],
      ),
    );
  }
}
