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
import 'voice_conversation_controller.dart';

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

  /// Hands-free conversation mode (U5). Entered by long-pressing the mic
  /// button; exited by tap on the mode chip, mic tap, typing, exit phrase,
  /// or silence in the follow-up window.
  late final VoiceConversationController _voiceController;
  StreamSubscription<VoiceConversationState>? _voiceSub;
  VoiceConversationState _voiceState = const VoiceConversationState();

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
    _voiceController = VoiceConversationController(
      stt: SpeechToTextSttEngine(_speech),
      narrator: ref.read(voiceNarratorProvider),
      resolveLocale: () => ref.read(appConfigProvider).resolvedLocale,
      onSendVoiceMessage: (text) => ref
          .read(chatProvider.notifier)
          .sendMessage(text, modality: ChatTurnModality.voice),
    );
    _voiceSub = _voiceController.states.listen(_onVoiceConversationState);
  }

  void _onVoiceConversationState(VoiceConversationState state) {
    if (!mounted) return;
    // Two unusable STT sessions in a row: visual fallback (no audible
    // reprompt beyond the single clarification).
    if (!state.isActive &&
        _voiceState.isActive &&
        state.closeReason == VoiceCloseReason.notUnderstood) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).voiceConvNotUnderstood),
        ),
      );
    }
    setState(() => _voiceState = state);
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
      // Never keep the mic open in the background (U5).
      _voiceController.exitConversationMode();
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (mounted) setState(() {});
  }

  /// Long-press on the mic: enter hands-free conversation mode. A live
  /// single-shot session is stopped first (the recognizer is a singleton —
  /// never two listen sessions).
  Future<void> _enterConversationMode() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }
    await _voiceController.enterConversationMode();
  }

  void _toggleListening() {
    // Mic tap during conversation mode exits it (single-shot and
    // conversation never share a session).
    if (_voiceState.isActive) {
      _voiceController.exitConversationMode();
      return;
    }
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
    // speech_to_text status/error callbacks are global (set once at
    // initialize) — forward them to the conversation controller, which
    // ignores them outside conversation mode.
    _voiceController.onSttStatus(status);
    if (status == 'done' || status == 'notListening') {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _voiceController.onSttError(error.errorMsg);
    if (mounted) {
      setState(() => _isListening = false);
      // Don't show error for normal speech timeout, and let conversation
      // mode handle its own recoveries (clarification / silent close).
      if (error.errorMsg != 'error_speech_timeout' && !_voiceState.isActive) {
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
    _voiceSub?.cancel();
    _voiceController.dispose();
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
      // Turn finished (response or error): conversation mode waits for the
      // narration to drain, then opens the 7 s follow-up listen window.
      if ((previous?.isProcessing ?? false) && !next.isProcessing) {
        _voiceController.onTurnFinished();
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

          // Conversation mode chip (U5) when active; otherwise the plain
          // narration indicator (tap stop to cut speech).
          if (_voiceState.isActive)
            _ConversationModeBar(
              state: _voiceState,
              onExit: () => _voiceController.exitConversationMode(),
            )
          else
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
            onMicLongPress:
                _speechAvailable ? _enterConversationMode : null,
            onUserTyped: () {
              // Keyboard edit: demote the pending voice turn to typed, stop
              // any ongoing narration (R2) and leave conversation mode (U5).
              _pendingVoiceSend = false;
              ref.read(voiceNarratorProvider).stop();
              _voiceController.exitConversationMode();
            },
            isListening: _isListening ||
                _voiceState.phase == VoiceConversationPhase.listening,
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

/// Voice conversation mode chip (U5): shows the current phase
/// (Listening pulse / Processing / Speaking) and exits the mode on tap
/// anywhere on the chip.
class _ConversationModeBar extends StatelessWidget {
  final VoiceConversationState state;
  final VoidCallback onExit;

  const _ConversationModeBar({required this.state, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    final (Widget icon, String label) = switch (state.phase) {
      VoiceConversationPhase.listening => (
          _PulsingIcon(
            icon: Icons.mic,
            color: theme.colorScheme.error,
          ),
          l.voiceConvListening,
        ),
      VoiceConversationPhase.processing => (
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          l.voiceConvProcessing,
        ),
      _ => (
          Icon(Icons.volume_up_outlined,
              size: 16, color: theme.colorScheme.primary),
          l.voiceConvSpeaking,
        ),
    };

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onExit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.stop_circle_outlined,
                size: 20,
                color: theme.colorScheme.primary,
                semanticLabel: l.voiceConvExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gently pulsing icon for the "listening" phase of conversation mode.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Icon(widget.icon, size: 16, color: widget.color),
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
