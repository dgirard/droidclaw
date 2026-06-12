import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/services/voice_narrator.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_provider.dart';
import 'agent_status_indicator.dart';
import 'input_bar.dart';
import 'message_bubble.dart';

/// Main chat screen.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _inputBarKey = GlobalKey<InputBarState>();
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  /// True when the input field was last filled by speech-to-text: the next
  /// send is a voice turn. Any keyboard edit demotes it back to typed.
  bool _pendingVoiceSend = false;

  StreamSubscription<VoiceNarratorState>? _narratorSub;
  VoiceDegradation _lastDegradation = VoiceDegradation.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
    // Surface narrator degradation (no voice for locale / no TTS engine) as
    // a one-shot snackbar on each transition into a degraded state (U11
    // pattern: never fail silently — the text answer is always displayed).
    _narratorSub =
        ref.read(voiceNarratorProvider).states.listen(_onNarratorState);
  }

  void _onNarratorState(VoiceNarratorState state) {
    if (!mounted) return;
    if (state.degradation != _lastDegradation &&
        state.degradation != VoiceDegradation.none) {
      final l = AppLocalizations.of(context);
      final message = switch (state.degradation) {
        VoiceDegradation.languageUnavailable => l.voiceLanguageUnavailable(
            ref.read(appConfigProvider).resolvedLocale),
        _ => l.voiceTtsUnavailable,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    _lastDegradation = state.degradation;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Interruption (R2): backgrounding the app (incoming call, home button)
    // stops narration. Audio-focus loss and AUDIO_BECOMING_NOISY are not
    // exposed by flutter_tts — documented gap in VoiceNarrator.
    if (state == AppLifecycleState.paused) {
      ref.read(voiceNarratorProvider).stop();
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      final locale = ref.read(appConfigProvider).resolvedLocale;
      _speech.listen(
        onResult: _onSpeechResult,
        localeId: locale,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
        ),
      );
      setState(() => _isListening = true);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _inputBarKey.currentState?.setText(result.recognizedWords);
    // Field content came from voice — the next send is a voice turn
    // (demoted to typed if the user edits with the keyboard first).
    _pendingVoiceSend = result.recognizedWords.trim().isNotEmpty;
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (mounted) {
      setState(() => _isListening = false);
      // Don't show error for normal speech timeout
      if (error.errorMsg != 'error_speech_timeout') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).chatSpeechError(error.errorMsg),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _narratorSub?.cancel();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final chatNotifier = ref.read(chatProvider.notifier);

    // Auto-scroll when messages change
    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).chatTitle),
        actions: [
          _LocaleSwitcher(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppLocalizations.of(context).chatConversations,
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: AppLocalizations.of(context).chatNewSession,
            onPressed: () => chatNotifier.newSession(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context).chatSettings,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(
                          message: chatState.messages[index]);
                    },
                  ),
          ),

          // Agent status
          if (chatState.isProcessing)
            AgentStatusIndicator(event: chatState.currentEvent),

          // Voice narration indicator (tap stop to cut speech)
          _SpeakingIndicator(narrator: ref.watch(voiceNarratorProvider)),

          // Input bar
          InputBar(
            key: _inputBarKey,
            onSend: (text) {
              // Stop listening if active when sending
              if (_isListening) {
                _speech.stop();
                setState(() => _isListening = false);
              }
              final modality = _pendingVoiceSend
                  ? ChatTurnModality.voice
                  : ChatTurnModality.typed;
              _pendingVoiceSend = false;
              chatNotifier.sendMessage(text, modality: modality);
            },
            onMicToggle: _speechAvailable ? _toggleListening : null,
            onUserTyped: () {
              // Keyboard edit: demote the pending voice turn to typed and
              // stop any ongoing narration (R2).
              _pendingVoiceSend = false;
              ref.read(voiceNarratorProvider).stop();
            },
            isListening: _isListening,
            enabled: !chatState.isProcessing,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l.chatEmptyTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.chatEmptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal "speaking" indicator shown while the narrator reads a voice
/// turn aloud, with a stop button (mirrors AgentStatusIndicator styling).
class _SpeakingIndicator extends StatelessWidget {
  final VoiceNarrator narrator;

  const _SpeakingIndicator({required this.narrator});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VoiceNarratorState>(
      stream: narrator.states,
      initialData: narrator.state,
      builder: (context, snapshot) {
        if (!(snapshot.data?.isSpeaking ?? false)) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final l = AppLocalizations.of(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                l.voiceSpeaking,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                color: theme.colorScheme.primary,
                visualDensity: VisualDensity.compact,
                tooltip: l.voiceStopSpeaking,
                onPressed: () => narrator.stop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact locale switcher: shows current language flag, tap to cycle.
class _LocaleSwitcher extends ConsumerWidget {
  static const _locales = ['system', 'en', 'fr', 'es', 'de', 'it'];

  static String _flag(String locale) => switch (locale) {
        'en' => '\u{1F1EC}\u{1F1E7}',
        'fr' => '\u{1F1EB}\u{1F1F7}',
        'es' => '\u{1F1EA}\u{1F1F8}',
        'de' => '\u{1F1E9}\u{1F1EA}',
        'it' => '\u{1F1EE}\u{1F1F9}',
        _ => '\u{1F310}', // globe for system
      };

  static String _label(String locale) => switch (locale) {
        'en' => 'English',
        'fr' => 'Français',
        'es' => 'Español',
        'de' => 'Deutsch',
        'it' => 'Italiano',
        _ => 'System',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final current = config.locale;
    final resolved = config.resolvedLocale;
    // Show the resolved flag (actual language), but with a globe overlay for 'system'
    final displayFlag =
        current == 'system' ? _flag('system') : _flag(resolved);

    return PopupMenuButton<String>(
      tooltip: AppLocalizations.of(context).localeSettingsTitle,
      onSelected: (locale) {
        final newConfig = config.copyWith(locale: locale);
        ref.read(configStorageProvider).save(newConfig);
        ref.read(appConfigProvider.notifier).update(newConfig);
      },
      itemBuilder: (context) => _locales.map((locale) {
        return PopupMenuItem<String>(
          value: locale,
          child: Row(
            children: [
              Text(_flag(locale), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(_label(locale)),
              if (locale == current) ...[
                const Spacer(),
                Icon(Icons.check,
                    size: 18, color: Theme.of(context).colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(displayFlag, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
