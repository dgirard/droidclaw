import 'package:flutter/material.dart';

import 'voice_service.dart';

/// Mic button widget for voice input with press-and-hold recording.
class VoiceInputButton extends StatefulWidget {
  final VoiceService? voiceService;
  final void Function(String text) onTranscribed;

  const VoiceInputButton({
    super.key,
    required this.voiceService,
    required this.onTranscribed,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _isRecording = false;
  bool _isTranscribing = false;

  Future<void> _startRecording() async {
    if (widget.voiceService == null) return;

    try {
      await widget.voiceService!.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || widget.voiceService == null) return;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    try {
      final text = await widget.voiceService!.stopAndTranscribe();
      if (text.isNotEmpty) {
        widget.onTranscribed(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.voiceService == null) {
      return const SizedBox.shrink();
    }

    if (_isTranscribing) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: IconButton(
        icon: Icon(
          _isRecording ? Icons.mic : Icons.mic_outlined,
          color: _isRecording ? theme.colorScheme.error : null,
        ),
        tooltip: 'Hold to speak',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hold the mic button to record'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}
