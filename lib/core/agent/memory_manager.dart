import 'package:intl/intl.dart';

import '../../data/local/storage_service.dart';
import '../../shared/constants.dart';

/// Manages long-term memory and daily notes in the workspace.
class MemoryManager {
  final StorageService _storage;

  MemoryManager(this._storage);

  // --- Long-term memory (MEMORY.md) ---

  /// Read the long-term memory file.
  Future<String?> readMemory() =>
      _storage.readWorkspaceFile('memory/MEMORY.md');

  /// Write the long-term memory file.
  Future<void> writeMemory(String content) =>
      _storage.writeWorkspaceFile('memory/MEMORY.md', content);

  // --- Daily notes ---

  /// Get the path for a daily note.
  String _dailyNotePath(DateTime date) {
    final month = DateFormat('yyyyMM').format(date);
    final day = DateFormat('yyyyMMdd').format(date);
    return 'memory/$month/$day.md';
  }

  /// Read today's daily note.
  Future<String?> readDailyNote([DateTime? date]) =>
      _storage.readWorkspaceFile(_dailyNotePath(date ?? DateTime.now()));

  /// Append to today's daily note with timestamp.
  Future<void> appendDailyNote(String content, [DateTime? date]) async {
    final now = date ?? DateTime.now();
    final path = _dailyNotePath(now);
    final existing = await _storage.readWorkspaceFile(path);
    final timestamp = DateFormat('HH:mm').format(now);
    final entry = '## $timestamp\n$content\n\n';
    final newContent = existing != null ? '$existing$entry' : entry;
    await _storage.writeWorkspaceFile(path, newContent);
  }

  /// Get recent daily notes from the last N days.
  Future<Map<String, String>> getRecentDailyNotes({
    int days = AppConstants.recentDailyNoteDays,
  }) async {
    final notes = <String, String>{};
    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final content = await readDailyNote(date);
      if (content != null && content.isNotEmpty) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        notes[dateStr] = content;
      }
    }
    return notes;
  }

  /// Get formatted memory context for the system prompt.
  Future<String> getMemoryContext() async {
    final buffer = StringBuffer();

    // Long-term memory
    final memory = await readMemory();
    if (memory != null && memory.isNotEmpty) {
      buffer.writeln('<long_term_memory>');
      buffer.writeln(memory);
      buffer.writeln('</long_term_memory>');
      buffer.writeln();
    }

    // Recent daily notes
    final notes = await getRecentDailyNotes();
    if (notes.isNotEmpty) {
      buffer.writeln('<recent_notes>');
      for (final entry in notes.entries) {
        buffer.writeln('## ${entry.key}');
        buffer.writeln(entry.value);
      }
      buffer.writeln('</recent_notes>');
    }

    return buffer.toString().trimRight();
  }
}
