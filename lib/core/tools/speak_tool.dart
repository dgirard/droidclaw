import 'package:flutter_tts/flutter_tts.dart';

import 'tool.dart';

/// Tool that speaks text aloud using the device TTS engine.
class SpeakTool extends Tool {
  static const int _maxChars = 5000;
  FlutterTts? _tts;

  @override
  String get name => 'speak';

  @override
  String get description =>
      'Speak text aloud using the device text-to-speech engine. '
      'Use when the user asks you to read something aloud or for hands-free '
      'interaction. Audio plays on the device speaker.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': 'The text to speak aloud',
          },
          'language': {
            'type': 'string',
            'description':
                'Language code (e.g. "fr-FR", "en-US"). '
                'Defaults to device language.',
          },
        },
        'required': ['text'],
      };

  Future<FlutterTts> _getTts() async {
    if (_tts == null) {
      _tts = FlutterTts();
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
    }
    return _tts!;
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final text = arguments['text'] as String?;
    if (text == null || text.isEmpty) {
      return ToolResult.error('Missing required parameter: text');
    }

    try {
      final tts = await _getTts();

      // Handle language
      final language = arguments['language'] as String?;
      if (language != null) {
        final available = await tts.isLanguageAvailable(language);
        if (available != 1) {
          final languages = await tts.getLanguages;
          return ToolResult.error(
              'Language "$language" is not available for TTS. '
              'Available: ${(languages as List).take(20).join(", ")}');
        }
        await tts.setLanguage(language);
      }

      // Truncate if needed
      var toSpeak = text;
      final truncated = text.length > _maxChars;
      if (truncated) {
        toSpeak = text.substring(0, _maxChars);
      }

      // Fire and forget
      await tts.speak(toSpeak);

      final charInfo = truncated
          ? '${toSpeak.length} chars (truncated from ${text.length})'
          : '${toSpeak.length} chars';

      return ToolResult.dual(
        forLLM: 'Text is being spoken aloud ($charInfo).',
        forUser: 'Speaking ($charInfo)...',
      );
    } catch (e) {
      return ToolResult.error('Text-to-speech failed: $e');
    }
  }
}
