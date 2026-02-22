import 'dart:convert';
import 'dart:io';

import '../config/log_entry.dart';

/// Persistent application logger.
///
/// Each isolate writes to its own .jsonl file to avoid concurrent access:
/// - Main isolate: `<dirPath>/logs_main.jsonl`
/// - Service isolate: `<dirPath>/logs_service.jsonl`
///
/// [debug] level prints only (not persisted) to avoid log bloat.
/// [info], [warning], [error] are both printed and persisted.
class AppLogger {
  static AppLogger? _instance;

  final String _dirPath;
  final String _logFilePath;
  IOSink? _sink;

  static const _maxEntries = 5000;
  static const _retentionDuration = Duration(hours: 24);

  AppLogger._({required String dirPath, required String isolateName})
      : _dirPath = dirPath,
        _logFilePath = '$dirPath/logs_$isolateName.jsonl' {
    _openSink();
  }

  /// Initialize the logger for this isolate.
  /// Call once in main.dart (isolateName='main') and once in
  /// BackgroundTaskHandler.onStart (isolateName='service').
  static void init({required String dirPath, required String isolateName}) {
    _instance?.dispose();
    _instance = AppLogger._(dirPath: dirPath, isolateName: isolateName);
  }

  /// Access the singleton. Falls back to a no-op print if not initialized.
  static AppLogger get instance {
    if (_instance == null) {
      // Fallback: create a dummy that only prints (no file path known yet)
      return _NoOpLogger._();
    }
    return _instance!;
  }

  /// Whether the logger has been initialized.
  static bool get isInitialized => _instance != null;

  void _openSink() {
    try {
      final file = File(_logFilePath);
      _sink = file.openWrite(mode: FileMode.append);
    } catch (e) {
      // ignore: avoid_print
      print('[AppLogger] Failed to open log file: $e');
    }
  }

  void _write(LogEntry entry) {
    // Always print to stdout
    // ignore: avoid_print
    print('[${entry.source.name}] ${entry.message}');

    // Debug level: print only, no persistence
    if (entry.level == LogLevel.debug) return;

    // Persist to .jsonl file
    try {
      _sink?.writeln(jsonEncode(entry.toJson()));
    } catch (e) {
      // ignore: avoid_print
      print('[AppLogger] Write failed: $e');
    }
  }

  /// Log a debug message (print only, NOT persisted).
  void debug(LogSource source, String message,
      {String? sessionKey, String? cronId, Map<String, dynamic>? metadata}) {
    _write(LogEntry(
      level: LogLevel.debug,
      source: source,
      message: message,
      sessionKey: sessionKey,
      cronId: cronId,
      metadata: metadata,
    ));
  }

  /// Log an info message (printed + persisted).
  void info(LogSource source, String message,
      {String? sessionKey, String? cronId, Map<String, dynamic>? metadata}) {
    _write(LogEntry(
      level: LogLevel.info,
      source: source,
      message: message,
      sessionKey: sessionKey,
      cronId: cronId,
      metadata: metadata,
    ));
  }

  /// Log a warning message (printed + persisted).
  void warning(LogSource source, String message,
      {String? sessionKey, String? cronId, Map<String, dynamic>? metadata}) {
    _write(LogEntry(
      level: LogLevel.warning,
      source: source,
      message: message,
      sessionKey: sessionKey,
      cronId: cronId,
      metadata: metadata,
    ));
  }

  /// Log an error message (printed + persisted).
  void error(LogSource source, String message,
      {String? sessionKey, String? cronId, Map<String, dynamic>? metadata}) {
    _write(LogEntry(
      level: LogLevel.error,
      source: source,
      message: message,
      sessionKey: sessionKey,
      cronId: cronId,
      metadata: metadata,
    ));
  }

  /// Read all persisted log entries from both isolate files.
  /// Sorted by timestamp descending (newest first).
  Future<List<LogEntry>> readAll() async {
    final entries = <LogEntry>[];
    for (final name in ['main', 'service']) {
      entries.addAll(await _readFile('$_dirPath/logs_$name.jsonl'));
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Read entries with optional filters.
  Future<List<LogEntry>> readFiltered({
    LogLevel? minLevel,
    LogSource? source,
    String? cronId,
    String? searchQuery,
  }) async {
    var entries = await readAll();
    if (minLevel != null) {
      entries = entries
          .where((e) => e.level.index >= minLevel.index)
          .toList();
    }
    if (source != null) {
      entries = entries.where((e) => e.source == source).toList();
    }
    if (cronId != null) {
      entries = entries.where((e) => e.cronId == cronId).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      entries = entries
          .where((e) => e.message.toLowerCase().contains(query))
          .toList();
    }
    return entries;
  }

  /// Purge entries older than 24h and enforce the 5000 entry cap.
  /// Only purges this isolate's own file. Returns the number of entries removed.
  Future<int> purge() async {
    final file = File(_logFilePath);
    if (!await file.exists()) return 0;

    final cutoff = DateTime.now().subtract(_retentionDuration);
    final entries = await _readFile(_logFilePath);
    final before = entries.length;

    // Remove entries older than 24h
    var kept = entries.where((e) => e.timestamp.isAfter(cutoff)).toList();

    // Enforce cap: keep newest
    if (kept.length > _maxEntries) {
      kept.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      kept = kept.sublist(0, _maxEntries);
    }

    final removed = before - kept.length;
    if (removed > 0) {
      // Close current sink, rewrite file atomically, reopen
      await _sink?.flush();
      await _sink?.close();

      final tmpPath = '$_logFilePath.tmp';
      final tmpFile = File(tmpPath);
      final tmpSink = tmpFile.openWrite();
      for (final entry in kept) {
        tmpSink.writeln(jsonEncode(entry.toJson()));
      }
      await tmpSink.flush();
      await tmpSink.close();
      await tmpFile.rename(_logFilePath);

      _openSink();
    }

    return removed;
  }

  /// Clear all entries from both isolate files.
  Future<void> clearAll() async {
    await _sink?.flush();
    await _sink?.close();

    for (final name in ['main', 'service']) {
      final file = File('$_dirPath/logs_$name.jsonl');
      if (await file.exists()) {
        await file.writeAsString('');
      }
    }

    _openSink();
  }

  /// Close the file sink.
  void dispose() {
    _sink?.close();
    _sink = null;
  }

  /// Parse a .jsonl file into log entries, skipping malformed lines.
  static Future<List<LogEntry>> _readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return [];

    final entries = <LogEntry>[];
    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          entries.add(LogEntry.fromJson(
              jsonDecode(line) as Map<String, dynamic>));
        } catch (_) {
          // Skip malformed lines
        }
      }
    } catch (_) {
      // File read error — return what we have
    }
    return entries;
  }
}

/// Fallback logger when AppLogger hasn't been initialized yet.
/// Only prints to stdout, no persistence.
class _NoOpLogger extends AppLogger {
  _NoOpLogger._() : super._(dirPath: '', isolateName: 'noop');

  @override
  void _openSink() {
    // No-op: don't open any file
  }

  @override
  void _write(LogEntry entry) {
    // Print only, no file write
    // ignore: avoid_print
    print('[${entry.source.name}] ${entry.message}');
  }
}
