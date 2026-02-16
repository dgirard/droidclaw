import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Voice recording and transcription via Groq Whisper API.
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final String _groqApiKey;
  String? _recordingPath;

  VoiceService({required String groqApiKey}) : _groqApiKey = groqApiKey;

  /// Check if recording is supported.
  Future<bool> get isAvailable async => await _recorder.hasPermission();

  /// Start recording audio.
  Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_input.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
  }

  /// Stop recording and transcribe the audio.
  Future<String> stopAndTranscribe() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw Exception('No recording captured');
    }

    try {
      return await _transcribe(path);
    } finally {
      // Clean up temp file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Cancel recording without transcribing.
  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Transcribe audio file via Groq Whisper API.
  Future<String> _transcribe(String filePath) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_groqApiKey'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['response_format'] = 'json'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Transcription failed: HTTP ${response.statusCode}: $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }

  void dispose() {
    _recorder.dispose();
  }
}
