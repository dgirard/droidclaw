import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/llm_response.dart';
import '../../core/providers/provider_factory.dart';
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

  static const _providers = [
    ('openrouter', 'OpenRouter', 'Access many models with one API key'),
    ('anthropic', 'Anthropic', 'Direct access to Claude models'),
    ('openai', 'OpenAI', 'Access to GPT models'),
    ('groq', 'Groq', 'Fast inference for open models'),
    ('gemini', 'Google Gemini', 'Google AI models with free tier'),
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
      setState(() => _testMessage = 'Please enter an API key');
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
        _testMessage = 'Connected! Response: ${response.content}';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testPassed = false;
        _testMessage = 'Failed: $e';
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
            'Welcome to DroidClaw',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your personal AI assistant on Android.\n'
            'Let\'s set up your LLM provider to get started.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _nextPage,
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Choose a provider', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Select which LLM provider you want to use.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_providers.length, (i) {
            final (id, name, desc) = _providers[i];
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
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Enter your API key', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your key is stored securely on device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
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
                : const Text('Test Connection'),
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
              child: const Text('Finish Setup'),
            ),
          ),
        ],
      ),
    );
  }
}
