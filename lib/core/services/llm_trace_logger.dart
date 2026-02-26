import 'dart:convert';
import 'dart:io';

import '../config/llm_trace.dart';

/// Persistent LLM call trace logger.
///
/// Each isolate writes to its own .jsonl file to avoid concurrent access:
/// - Main isolate: `<dirPath>/llm_traces_main.jsonl`
/// - Service isolate: `<dirPath>/llm_traces_service.jsonl`
///
/// Traces are larger than log entries so we use a tighter cap (500 vs 5000).
class LlmTraceLogger {
  static LlmTraceLogger? _instance;

  final String _dirPath;
  final String _traceFilePath;
  IOSink? _sink;

  static const _maxEntries = 500;
  static const _retentionDuration = Duration(hours: 24);

  LlmTraceLogger._({required String dirPath, required String isolateName})
      : _dirPath = dirPath,
        _traceFilePath = '$dirPath/llm_traces_$isolateName.jsonl' {
    _openSink();
  }

  /// Initialize the trace logger for this isolate.
  static void init({required String dirPath, required String isolateName}) {
    _instance?.dispose();
    _instance = LlmTraceLogger._(dirPath: dirPath, isolateName: isolateName);
  }

  /// Access the singleton. Falls back to a no-op if not initialized.
  static LlmTraceLogger get instance {
    if (_instance == null) return _NoOpTraceLogger._();
    return _instance!;
  }

  /// Whether the logger has been initialized.
  static bool get isInitialized => _instance != null;

  void _openSink() {
    try {
      final file = File(_traceFilePath);
      _sink = file.openWrite(mode: FileMode.append);
    } catch (e) {
      // ignore: avoid_print
      print('[LlmTraceLogger] Failed to open trace file: $e');
    }
  }

  /// Log a trace entry.
  void log(LlmTrace trace) {
    try {
      _sink?.writeln(jsonEncode(trace.toJson()));
    } catch (e) {
      // ignore: avoid_print
      print('[LlmTraceLogger] Write failed: $e');
    }
  }

  /// Read all traces from both isolate files, sorted by timestamp desc.
  Future<List<LlmTrace>> readAll() async {
    final traces = <LlmTrace>[];
    for (final name in ['main', 'service']) {
      traces.addAll(await _readFile('$_dirPath/llm_traces_$name.jsonl'));
    }
    traces.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return traces;
  }

  /// Compute aggregate stats across all traces.
  Future<LlmTraceStats> getStats() async {
    final traces = await readAll();
    if (traces.isEmpty) return const LlmTraceStats();

    int totalPrompt = 0;
    int totalCompletion = 0;
    int totalLatency = 0;

    for (final t in traces) {
      totalPrompt += t.promptTokens ?? 0;
      totalCompletion += t.completionTokens ?? 0;
      totalLatency += t.latencyMs;
    }

    return LlmTraceStats(
      totalCalls: traces.length,
      totalPromptTokens: totalPrompt,
      totalCompletionTokens: totalCompletion,
      avgLatencyMs: traces.isEmpty ? 0 : totalLatency ~/ traces.length,
      oldestTrace: traces.last.timestamp,
      newestTrace: traces.first.timestamp,
    );
  }

  /// Purge traces older than 24h and enforce the 500 entry cap.
  /// Returns the number of entries removed.
  Future<int> purge() async {
    final file = File(_traceFilePath);
    if (!await file.exists()) return 0;

    final cutoff = DateTime.now().subtract(_retentionDuration);
    final entries = await _readFile(_traceFilePath);
    final before = entries.length;

    var kept = entries.where((t) => t.timestamp.isAfter(cutoff)).toList();

    if (kept.length > _maxEntries) {
      kept.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      kept = kept.sublist(0, _maxEntries);
    }

    final removed = before - kept.length;
    if (removed > 0) {
      await _sink?.flush();
      await _sink?.close();

      final tmpPath = '$_traceFilePath.tmp';
      final tmpFile = File(tmpPath);
      final tmpSink = tmpFile.openWrite();
      for (final entry in kept) {
        tmpSink.writeln(jsonEncode(entry.toJson()));
      }
      await tmpSink.flush();
      await tmpSink.close();
      await tmpFile.rename(_traceFilePath);

      _openSink();
    }

    return removed;
  }

  /// Clear all traces from both isolate files.
  Future<void> clearAll() async {
    await _sink?.flush();
    await _sink?.close();

    for (final name in ['main', 'service']) {
      final file = File('$_dirPath/llm_traces_$name.jsonl');
      if (await file.exists()) {
        await file.writeAsString('');
      }
    }

    _openSink();
  }

  void dispose() {
    _sink?.close();
    _sink = null;
  }

  /// Parse a .jsonl file into traces, skipping malformed lines.
  static Future<List<LlmTrace>> _readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return [];

    final traces = <LlmTrace>[];
    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          traces.add(
              LlmTrace.fromJson(jsonDecode(line) as Map<String, dynamic>));
        } catch (_) {
          // Skip malformed lines
        }
      }
    } catch (_) {
      // File read error
    }
    return traces;
  }
}

/// Fallback logger when LlmTraceLogger hasn't been initialized yet.
class _NoOpTraceLogger extends LlmTraceLogger {
  _NoOpTraceLogger._() : super._(dirPath: '', isolateName: 'noop');

  @override
  void _openSink() {
    // No-op
  }

  @override
  void log(LlmTrace trace) {
    // No-op
  }
}
