---
title: "feat: Persistent application logging with 24h retention"
type: feat
date: 2026-02-22
---

# feat: Persistent application logging with 24h retention

## Overview

DroidClaw currently logs via `print()` to stdout only — visible through `adb logcat` but lost otherwise. When crons execute at 3 AM, there is zero record of what happened unless the user connects to `adb`. Additionally, old cron execution sessions cannot be deleted from the history screen.

This plan adds:
1. A persistent `AppLog` system that stores structured log entries for 24 hours
2. A Logs screen to view, filter, and understand what happened
3. Delete capability for cron execution sessions in the history screen
4. Automatic purge of entries older than 24h

## Architecture Decision: Storage Backend

**Problem**: Hive is NOT safe for concurrent writes from two isolates. Both the main isolate and service isolate need to write logs. Hive uses an append-only file with in-memory cache — two independent `HiveImpl` instances writing to the same `.hive` file can corrupt it.

**Decision: Separate log files per isolate, merged at read time.**

Each isolate writes to its own JSON Lines file (`.jsonl`) in the app's filesystem:
- Main isolate: `<hivePath>/logs_main.jsonl`
- Service isolate: `<hivePath>/logs_service.jsonl`

**Why `.jsonl` files instead of Hive or SQLite:**
- No concurrency issue — each isolate owns its own file exclusively
- No new dependency (SQLite/drift would add ~2MB to APK)
- Append-only writes are atomic at the OS level for reasonable line sizes
- Easy to read, merge, sort by timestamp, and purge (rewrite without old entries)
- Human-readable for debugging (`adb pull` the file)
- Matches the project's manual JSON serialization convention

**Trade-off accepted**: Reading logs requires parsing both files and merging. This is fine — the Logs screen loads on-demand, not continuously.

## Data Model

### `LogEntry`

```dart
// lib/core/config/log_entry.dart
class LogEntry {
  final String id;          // UUID v4
  final DateTime timestamp;
  final LogLevel level;     // debug, info, warning, error
  final LogSource source;   // agent, cron, service, telegram, app
  final String message;
  final String? sessionKey; // link to session (cron_xxx, telegram_xxx)
  final String? cronId;     // for cron-related entries
  final Map<String, dynamic>? metadata; // tool name, response length, etc.

  // Manual toJson/fromJson (project convention)
}

enum LogLevel { debug, info, warning, error }
enum LogSource { agent, cron, service, telegram, app }
```

**Key design choices:**
- `debug` level: prints to stdout but is NOT persisted (avoids log bloat from AgentLoop iteration noise)
- `info`/`warning`/`error`: both printed and persisted
- `sessionKey`: links log entry to a session for cross-reference
- `cronId`: enables filtering logs for a specific cron
- `id`: UUID for potential future features (deletion, deduplication)

### Estimated volume

- 1 cron every 15 min = 96 executions/day, ~5 entries each = ~500 entries/day
- Telegram: ~100-500 entries/day with active use
- Each entry: ~200-500 bytes JSON
- **24h total: ~200KB-500KB** — well within filesystem constraints
- **Hard cap: 5000 entries** as safety net (oldest purged first)

## Files to Create

| File | Purpose |
|------|---------|
| `lib/core/config/log_entry.dart` | `LogEntry` model + `LogLevel` + `LogSource` enums |
| `lib/core/services/app_logger.dart` | `AppLogger` singleton — write, read, purge |
| `lib/features/settings/logs_screen.dart` | Logs viewer UI with filters |

## Files to Modify

| File | Change |
|------|---------|
| `lib/main.dart` | Init `AppLogger` for main isolate |
| `lib/core/services/background_task_handler.dart` | Init `AppLogger` for service isolate, replace `_log()` with `AppLogger`, add service-side purge |
| `lib/core/agent/agent_loop.dart` | Replace `print()` calls with `AppLogger` |
| `lib/providers/background_service_provider.dart` | Replace `_cronLog()` with `AppLogger` |
| `lib/features/chat/history_screen.dart` | Add delete buttons for cron sessions (individual + group) |
| `lib/features/settings/settings_screen.dart` | Add "Logs" entry |
| `lib/app.dart` | Add `/settings/logs` route |
| `lib/l10n/app_en.arb` | Add ~20 log-related i18n keys |
| `lib/l10n/app_fr.arb` | French translations |
| `lib/l10n/app_es.arb` | Spanish translations |
| `lib/l10n/app_de.arb` | German translations |
| `lib/l10n/app_it.arb` | Italian translations |

## Implementation

### Phase 1: LogEntry model + AppLogger singleton

#### `lib/core/config/log_entry.dart`

```dart
enum LogLevel { debug, info, warning, error }
enum LogSource { agent, cron, service, telegram, app }

class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogSource source;
  final String message;
  final String? sessionKey;
  final String? cronId;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.sessionKey,
    this.cronId,
    this.metadata,
  });

  // Manual toJson/fromJson (project convention)
}
```

#### `lib/core/services/app_logger.dart`

```dart
class AppLogger {
  static AppLogger? _instance;
  final String _logFilePath; // logs_main.jsonl or logs_service.jsonl
  final String _dirPath;     // directory containing both log files
  IOSink? _sink;

  static void init({required String dirPath, required String isolateName}) { ... }
  static AppLogger get instance => _instance!;

  // Core API
  void debug(LogSource source, String message, {String? sessionKey, String? cronId, Map<String, dynamic>? metadata});
  void info(LogSource source, String message, {String? sessionKey, String? cronId, Map<String, dynamic>? metadata});
  void warning(LogSource source, String message, {String? sessionKey, String? cronId, Map<String, dynamic>? metadata});
  void error(LogSource source, String message, {String? sessionKey, String? cronId, Map<String, dynamic>? metadata});

  // debug: print only, no persistence
  // info/warning/error: print + append to .jsonl file

  // Read API (for Logs screen)
  Future<List<LogEntry>> readAll();      // merge both files, sort by timestamp desc
  Future<List<LogEntry>> readFiltered({  // with optional filters
    LogLevel? minLevel,
    LogSource? source,
    String? cronId,
    String? searchQuery,
  });

  // Purge API
  Future<int> purge();                   // remove entries > 24h old + enforce 5000 cap
  void dispose();                        // close IOSink
}
```

**Init pattern:**
- Main isolate: `AppLogger.init(dirPath: hivePath, isolateName: 'main')` in `main.dart` after Hive init
- Service isolate: `AppLogger.init(dirPath: hivePath, isolateName: 'service')` in `ServiceAgentFactory.create()` or `BackgroundTaskHandler.onStart()`

**Write pattern:**
- Opens file in append mode (`FileMode.append`)
- Each `log()` call: `_sink!.writeln(jsonEncode(entry.toJson()))`
- Flush periodically or on `dispose()`

**Read pattern:**
- Read both `logs_main.jsonl` and `logs_service.jsonl`
- Parse each line as JSON → `LogEntry.fromJson()`
- Merge, sort by `timestamp` descending
- Skip malformed lines gracefully (corrupted writes)

**Purge pattern:**
- Read all entries from own file
- Filter out entries where `timestamp < now - 24h`
- If remaining > 5000, keep only newest 5000
- Rewrite the file atomically (write to `.tmp`, rename)
- Does NOT touch the other isolate's file

### Phase 2: Replace print() calls

#### `lib/core/agent/agent_loop.dart`

Replace 4 `print()` statements:

```dart
// Line 97-98: iteration info → debug (not persisted, too verbose)
AppLogger.instance.debug(LogSource.agent, 'iter=$iteration, msgs=${messages.length}...');

// Line 114-117: LLM response → info
AppLogger.instance.info(LogSource.agent, 'LLM responded: ${content.length} chars',
  sessionKey: session.key);

// Line 120: LLM error → error
AppLogger.instance.error(LogSource.agent, 'LLM error: $e',
  sessionKey: session.key);

// Line 147-148: tool result → debug (too verbose for persistence)
AppLogger.instance.debug(LogSource.agent, 'Tool ${toolCall.name} result: ${result.forLLM.length} chars');
```

#### `lib/core/services/background_task_handler.dart`

Replace `_log()` helper (line 55) with `AppLogger`:

```dart
// Before: void _log(String msg) => print('[DroidClaw] $msg');
// After: use AppLogger.instance directly

// Cron check → debug (every 15s, too frequent)
AppLogger.instance.debug(LogSource.service, 'Checking ${crons.length} crons at ${now.hour}:${now.minute}');

// Cron trigger → info (important, actionable)
AppLogger.instance.info(LogSource.cron, 'Triggering "${cron.name}"',
  cronId: cron.id, sessionKey: sessionKey);

// Cron completed → info
AppLogger.instance.info(LogSource.cron, 'Completed "${cron.name}" (${response.length} chars)',
  cronId: cron.id, sessionKey: sessionKey);

// Cron error → error
AppLogger.instance.error(LogSource.cron, 'ERROR in "${cron.name}": $e',
  cronId: cron.id, sessionKey: sessionKey);

// AgentLoop init → info
AppLogger.instance.info(LogSource.service, 'AgentLoop initialized in service isolate');

// Telegram polling → debug
AppLogger.instance.debug(LogSource.telegram, 'Polling getUpdates...');
```

#### `lib/providers/background_service_provider.dart`

Replace `_cronLog()` helper (line 232):

```dart
// Cron trigger received from service → info
AppLogger.instance.info(LogSource.cron, 'Service isolate completed "${data['cron_name']}"',
  cronId: data['cron_id']);

// Cron fallback execution → info
AppLogger.instance.info(LogSource.cron, 'Executing "${cron.name}" in main isolate (fallback)',
  cronId: cron.id, sessionKey: sessionKey);
```

### Phase 3: Service-side purge

In `BackgroundTaskHandler.onRepeatEvent()`, add a purge counter (same pattern as `_cronCheckCounter`):

```dart
int _purgeCounter = 0;
static const _purgeIntervalSeconds = 6 * 3600; // every 6 hours

@override
Future<void> onRepeatEvent(DateTime timestamp) async {
  // Purge logs periodically
  _purgeCounter++;
  if (_purgeCounter >= _purgeIntervalSeconds) {
    _purgeCounter = 0;
    await AppLogger.instance.purge();
  }
  // ... existing cron check + telegram polling ...
}
```

Also purge on service isolate startup (`onStart()`).

### Phase 4: Logs screen

#### `lib/features/settings/logs_screen.dart`

```
Scaffold
├── AppBar: "Logs" + clear button (trash icon)
├── FilterBar (horizontal chips):
│   ├── Level: All / Info / Warning / Error
│   └── Source: All / Agent / Cron / Service / Telegram
└── ListView.builder (sorted by timestamp desc):
    └── LogEntryTile:
        ├── Leading: colored icon by level (info=blue, warning=orange, error=red)
        ├── Title: message (truncated to 2 lines, expandable on tap)
        ├── Subtitle: source + timestamp (relative: "2h ago", "14:32")
        └── If cronId: chip with cron name
```

**Key behaviors:**
- Loads all entries on screen entry (reads both `.jsonl` files)
- Filters applied client-side (dataset is small — <5000 entries)
- No real-time auto-refresh (pull-to-refresh instead)
- "Clear all" button with confirmation dialog
- Tapping an entry with a `sessionKey` navigates to that session in the chat view

#### Route and settings entry

`lib/app.dart`: Add `'/settings/logs': (_) => const LogsScreen()`

`lib/features/settings/settings_screen.dart`: Add ListTile with `Icons.receipt_long_outlined` after the existing entries

### Phase 5: Cron session deletion in history

#### `lib/features/chat/history_screen.dart`

**Cron group tile** (lines 65-90): Add a delete button that deletes ALL sessions for that cron group:

```dart
trailing: IconButton(
  icon: const Icon(Icons.delete_outline),
  onPressed: () => _confirmDeleteCronGroup(context, cronId, sessions),
),
```

**`CronExecutionsScreen`** (lines 204-254): Add delete button per execution:

```dart
trailing: IconButton(
  icon: const Icon(Icons.delete_outline, size: 20),
  onPressed: () => _confirmDeleteExecution(context, session),
),
```

Both use the existing `SessionManager.deleteSession()` — no new infrastructure needed.

### Phase 6: i18n

Add ~20 keys to all 5 ARB files:

```json
"logsTitle": "Logs",
"logsEmpty": "No log entries",
"logsFilterAll": "All",
"logsFilterInfo": "Info",
"logsFilterWarning": "Warning",
"logsFilterError": "Error",
"logsSourceAgent": "Agent",
"logsSourceCron": "Cron",
"logsSourceService": "Service",
"logsSourceTelegram": "Telegram",
"logsSourceApp": "App",
"logsClearAll": "Clear all logs",
"logsClearConfirm": "Delete all log entries?",
"logsTimeAgo": "{time} ago",
"logsEntryCount": "{count} entries",
"cronDeleteGroup": "Delete all executions for this cron?",
"cronDeleteExecution": "Delete this execution?",
"cronDeleteGroupCount": "This will delete {count} sessions.",
"logsCleared": "Logs cleared",
"logsPurged": "Purged {count} old log entries"
```

## Acceptance Criteria

- [x] `LogEntry` model with `toJson()`/`fromJson()`, 4 levels, 5 sources
- [x] `AppLogger` singleton: init, write (append to `.jsonl`), read (merge both files), purge (24h + 5000 cap)
- [x] Main isolate: `AppLogger.init()` in `main.dart`
- [x] Service isolate: `AppLogger.init()` in `BackgroundTaskHandler.onStart()`
- [x] `agent_loop.dart`: 4 `print()` calls replaced (2 debug, 1 info, 1 error)
- [x] `background_task_handler.dart`: `_log()` replaced with `AppLogger` calls (~20 sites)
- [x] `background_service_provider.dart`: `_cronLog()` replaced with `AppLogger` calls (~10 sites)
- [x] Service isolate purges on startup + every 6 hours
- [x] Main isolate purges on startup
- [x] Logs screen: view entries, filter by level/source, expandable messages
- [x] Logs screen: "Clear all" button with confirmation
- [x] Logs screen: tap entry with `sessionKey` navigates to session
- [x] History screen: delete button on cron group tiles (deletes all sessions)
- [x] History screen: delete button on individual cron executions
- [x] Settings screen: "Logs" entry navigates to logs screen
- [x] Route `/settings/logs` registered in `app.dart`
- [x] All 5 ARB files updated with ~20 log-related keys
- [x] `flutter gen-l10n` succeeds
- [x] `flutter analyze` passes with 0 issues
- [x] Build APK and verify on device

## Notes

- Log entries are stored as English strings (no localization in log content) — the Logs screen UI labels are localized
- `debug` level is print-only, never persisted — keeps log volume manageable
- Each isolate writes to its own `.jsonl` file — no concurrency issues
- Purge rewrites the file atomically (write `.tmp`, rename) — safe against crashes
- The existing `sessions` Hive box already has the dual-isolate concurrency risk — this plan avoids amplifying it by using separate files
- `IOSink` is opened once and reused — no file handle churn
