---
title: "feat: Add Telegram bot channel with long polling"
type: feat
date: 2026-02-16
---

# Add Telegram Bot Channel with Long Polling

## Overview

Add a Telegram bot integration to DroidClaw that receives messages via long polling from a foreground Android service, processes them through the existing AgentLoop, and sends responses back to Telegram users. The bot runs persistently in the background even when the app is closed.

## Problem Statement / Motivation

DroidClaw currently only works through its built-in Flutter chat UI. Users who want to interact with their AI assistant while using other apps, or from another device, cannot. Telegram is the ideal first external channel because:

- Long polling works without a public server (no NAT/firewall issues)
- The Bot API is simple HTTP (no WebSocket complexity)
- Telegram is widely used and works across all platforms
- Other users (family, team) could also message the bot

## Proposed Solution

### Architecture Decision: Main Isolate Processing

**Key decision**: The TaskHandler isolate handles **only** Telegram polling and message sending. All AgentLoop processing happens in the main isolate via port communication.

**Why**: AgentLoop depends on Riverpod providers (LLMProvider, SessionManager, ToolRegistry, ContextBuilder) that live in the main isolate. Recreating them in the TaskHandler isolate would require duplicating Hive boxes, config, and secure storage access — fragile and error-prone. Flutter's `flutter_foreground_task` provides bidirectional port communication for this exact pattern.

```
┌─────────────────────────────────────────────────────┐
│                 TaskHandler Isolate                  │
│  ┌──────────────┐        ┌────────────────────┐     │
│  │ Long Polling  │───────▶│ Telegram sendMessage│    │
│  │ (getUpdates)  │        └────────────────────┘    │
│  └──────┬───────┘                  ▲                │
│         │ new message              │ response       │
│         ▼                          │                │
│  ┌──────────────┐        ┌────────┴───────────┐    │
│  │ sendDataToMain│        │ onReceiveData      │    │
│  └──────┬───────┘        └────────────────────┘    │
└─────────┼──────────────────────────┼────────────────┘
          │ port                     │ port
┌─────────▼──────────────────────────┼────────────────┐
│                 Main Isolate                         │
│  ┌──────────────┐        ┌────────┴───────────┐    │
│  │ onReceiveData │        │ sendDataToTask     │    │
│  └──────┬───────┘        └────────────────────┘    │
│         │                          ▲                │
│         ▼                          │                │
│  ┌──────────────────────────────────┐               │
│  │       TelegramBotManager         │               │
│  │  - message queue (per chat_id)   │               │
│  │  - AgentLoop.processMessage()    │               │
│  │  - rate limiter                  │               │
│  └──────────────────────────────────┘               │
└─────────────────────────────────────────────────────┘
```

**When app is killed**: The foreground service continues polling. Incoming messages are queued in the TaskHandler. When the user re-opens the app, queued messages are flushed to the main isolate for processing. If the main isolate is dead, TaskHandler sends a "Bot is temporarily processing, please wait" auto-reply and queues the message.

### Foreground Service Type

Use **`remoteMessaging`** (not `dataSync`) because:
- `dataSync` has a **6-hour runtime limit per 24 hours** on Android 15+
- `remoteMessaging` has **no time limit** — designed for messaging apps

## Technical Approach

### Phase 1: Telegram Service Core

#### 1.1 `lib/features/telegram/telegram_api.dart`

Raw HTTP client for Telegram Bot API. No external package dependency.

```dart
class TelegramApi {
  final String token;
  final http.Client _client;

  // Core methods:
  Future<Map<String, dynamic>> getMe();
  Future<List<TelegramUpdate>> getUpdates({int? offset, int timeout = 30, int limit = 100});
  Future<void> sendMessage(int chatId, String text, {String? parseMode});
}

class TelegramUpdate {
  final int updateId;
  final int chatId;
  final String? username;
  final String text;
  final DateTime date;
}
```

- Long polling: `timeout=30`, HTTP client timeout = 35s
- Parse mode: `HTML` for responses (supports bold, italic, code, links)
- Message splitting: if response > 4000 chars, split into multiple messages

#### 1.2 `lib/features/telegram/telegram_task_handler.dart`

Runs in the foreground service isolate.

```dart
@pragma('vm:entry-point')
void telegramServiceCallback() {
  FlutterForegroundTask.setTaskHandler(TelegramTaskHandler());
}

class TelegramTaskHandler extends TaskHandler {
  TelegramApi? _api;
  int _offset = 0;
  final List<TelegramUpdate> _pendingQueue = [];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Receive token + saved offset from init data
    // Initialize TelegramApi
    // Load persisted offset from SharedPreferences
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Poll getUpdates
    // For each update: sendDataToMain({chatId, text, username, updateId})
    // Update and persist offset
  }

  @override
  void onReceiveData(Object data) {
    // Receive response from main isolate: {chatId, text}
    // Send to Telegram via sendMessage
    // Update notification
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Persist offset
    // Cleanup
  }
}
```

**Offset persistence**: Saved to SharedPreferences after each batch of updates is processed. Key: `telegram_bot_offset`. On first start, offset = 0 (gets all pending messages, max 100).

#### 1.3 `lib/features/telegram/telegram_bot_manager.dart`

Runs in the main isolate. Bridges TaskHandler messages to AgentLoop.

```dart
class TelegramBotManager {
  final AgentLoop agentLoop;
  final SessionManager sessions;
  final RateLimiter _rateLimiter;
  final Map<int, Queue<TelegramUpdate>> _chatQueues = {};
  final Set<int> _processing = {};

  // Called when TaskHandler sends a message
  Future<void> handleIncomingMessage(TelegramUpdate update) async {
    // 1. Check whitelist (if configured)
    // 2. Add to per-chat queue
    // 3. If not already processing this chat, start processing
  }

  Future<void> _processQueue(int chatId) async {
    _processing.add(chatId);
    while (_chatQueues[chatId]?.isNotEmpty ?? false) {
      final update = _chatQueues[chatId]!.removeFirst();
      final sessionKey = 'telegram_$chatId';

      try {
        String? finalResponse;
        await for (final event in agentLoop.processMessage(update.text, sessionKey)) {
          if (event is ResponseEvent) {
            finalResponse = event.content;
          } else if (event is ErrorEvent) {
            finalResponse = "Sorry, I encountered an error. Please try again.";
          }
        }

        if (finalResponse != null) {
          await _rateLimiter.waitForSlot(chatId);
          FlutterForegroundTask.sendDataToTask({
            'action': 'send',
            'chat_id': chatId,
            'text': finalResponse,
          });
        }
      } catch (e) {
        FlutterForegroundTask.sendDataToTask({
          'action': 'send',
          'chat_id': chatId,
          'text': 'An error occurred while processing your message.',
        });
      }
    }
    _processing.remove(chatId);
  }
}
```

**Concurrency model**:
- Messages from the **same chat** are processed **sequentially** (queue per chat_id)
- Messages from **different chats** are processed **concurrently** (up to 3 simultaneous)
- If user sends a new message while previous is processing, it's queued

#### 1.4 Rate Limiter

```dart
class RateLimiter {
  final Map<int, DateTime> _lastSent = {};
  static const _perChatInterval = Duration(seconds: 1);

  Future<void> waitForSlot(int chatId) async {
    final last = _lastSent[chatId];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _perChatInterval) {
        await Future.delayed(_perChatInterval - elapsed);
      }
    }
    _lastSent[chatId] = DateTime.now();
  }
}
```

### Phase 2: Android Configuration

#### 2.1 Dependencies

```yaml
dependencies:
  flutter_foreground_task: ^9.2.0
```

#### 2.2 `AndroidManifest.xml` additions

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="remoteMessaging"
    android:exported="false" />
```

#### 2.3 Kotlin version check

Verify `android/build.gradle` has Kotlin 1.9.10+ and Gradle 8.6.0+.

### Phase 3: Settings & Configuration UI

#### 3.1 `lib/features/settings/telegram_config_screen.dart`

Settings screen for Telegram bot configuration:

- **Bot token field** (obscured, stored in FlutterSecureStorage key `telegram_bot_token`)
- **Test Connection button** → calls `getMe` API, shows bot username on success
- **Enable/Disable toggle** → starts/stops foreground service
  - Greyed out when no token is set
  - Validates token on enable (calls `getMe`, shows error if invalid)
- **Allowed users field** (optional) — comma-separated Telegram usernames
  - If empty, all users can message the bot
  - If set, only listed usernames get responses; others get "Access denied"
- **Status display** — shows "Running since HH:MM", message count, last message info

#### 3.2 `lib/features/settings/settings_screen.dart` update

Add a new ListTile linking to `telegram_config_screen.dart`:

```dart
ListTile(
  leading: Icon(Icons.telegram),
  title: Text('Telegram Bot'),
  subtitle: Text(isEnabled ? 'Running' : 'Disabled'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => Navigator.pushNamed(context, '/settings/telegram'),
),
```

### Phase 4: Riverpod Integration

#### 4.1 `lib/providers/telegram_provider.dart`

```dart
class TelegramState {
  final bool isEnabled;
  final bool isRunning;
  final String? botUsername;
  final int messageCount;
  final DateTime? lastMessageTime;
  final String? error;
}

class TelegramNotifier extends Notifier<TelegramState> {
  // Enable/disable bot
  // Listen for messages from TaskHandler
  // Forward to TelegramBotManager
  // Track stats
}

final telegramProvider = NotifierProvider<TelegramNotifier, TelegramState>(...);
```

### Phase 5: Error Handling

#### Error Response Mapping

| Error Source | Error Type | Telegram Response | Bot Action |
|---|---|---|---|
| Telegram API | 401 Unauthorized | — | Stop bot, show error in notification |
| Telegram API | 429 Rate Limited | — | Wait `Retry-After` seconds, retry |
| Telegram API | 5xx Server Error | — | Exponential backoff (2s, 4s, 8s... max 60s) |
| Network | Timeout/No connection | — | Retry after 5s, then backoff |
| LLM API | Any error | "Sorry, I'm having trouble right now. Please try again." | Log error |
| Tool | web_search/web_fetch fail | (handled by AgentLoop internally) | Continue processing |
| AgentLoop | Max iterations | "I wasn't able to fully process your request." | Log warning |
| Access | Non-whitelisted user | "This bot is private." | Ignore future messages |

#### Reconnection Strategy

```
Poll failure → wait 2s → retry
2nd failure  → wait 4s → retry
3rd failure  → wait 8s → retry
...
Max backoff  → wait 60s → retry
Success      → reset backoff to 0
```

After 10 consecutive failures: update notification to "Bot disconnected — retrying..."

## Acceptance Criteria

### Functional Requirements

- [x] User can enter Telegram bot token in settings and test connection
- [x] User can enable/disable Telegram bot via toggle
- [x] Foreground service starts with persistent notification showing "DroidClaw Bot - Active"
- [x] Bot receives Telegram messages via long polling (getUpdates, timeout=30s)
- [x] Messages are processed through existing AgentLoop with session key `telegram_<chat_id>`
- [x] Agent responses (including tool call results) are sent back to Telegram
- [x] Bot works with web_search and web_fetch tools
- [x] Summarization works for long Telegram conversations (same thresholds as chat UI)
- [x] Responses > 4000 chars are split into multiple Telegram messages
- [x] Bot continues running when app is in background
- [x] Update offset is persisted across service restarts (no duplicate messages)
- [x] Optional whitelist restricts which Telegram users can use the bot
- [x] Invalid bot token shows clear error when enabling

### Non-Functional Requirements

- [x] Rate limiting: max 1 message/sec per chat, respects Telegram 429 responses
- [x] Error recovery: exponential backoff on failures, auto-reconnect
- [x] Notification updates: shows last message time, message count
- [x] Per-chat sequential processing, cross-chat concurrent (max 3)
- [x] Foreground service uses `remoteMessaging` type (no Android 15 time limit)

## Dependencies & Risks

### Dependencies

- `flutter_foreground_task` ^9.2.0 — foreground service
- Android Kotlin 1.9.10+ and Gradle 8.6.0+
- User must create a Telegram bot via @BotFather

### Risks

| Risk | Impact | Mitigation |
|---|---|---|
| App killed → queued messages lost | Messages not processed until app reopened | TaskHandler queues messages, sends "processing..." auto-reply |
| Android OEM battery optimization kills service | Bot stops without user knowing | Request battery optimization exemption, show guidance in settings |
| Multiple LLM API calls drain user's API quota | Unexpected costs | Optional whitelist, message count visible in settings |
| Telegram bot token leaked | Security compromise | Stored in FlutterSecureStorage, passed to isolate via init data only |

## Files to Create/Modify

### New Files (6)

| File | Description |
|---|---|
| `lib/features/telegram/telegram_api.dart` | Raw HTTP client for Telegram Bot API |
| `lib/features/telegram/telegram_task_handler.dart` | Foreground service TaskHandler (isolate) |
| `lib/features/telegram/telegram_bot_manager.dart` | Main isolate message bridge + queue |
| `lib/features/telegram/rate_limiter.dart` | Per-chat rate limiter |
| `lib/features/settings/telegram_config_screen.dart` | Telegram bot settings screen |
| `lib/providers/telegram_provider.dart` | Riverpod state for Telegram bot |

### Modified Files (5)

| File | Change |
|---|---|
| `pubspec.yaml` | Add `flutter_foreground_task: ^9.2.0` |
| `android/app/src/main/AndroidManifest.xml` | Add permissions + service declaration |
| `lib/features/settings/settings_screen.dart` | Add Telegram bot list tile |
| `lib/app.dart` | Add `/settings/telegram` route |
| `lib/main.dart` | Add `FlutterForegroundTask.initCommunicationPort()` |
| `lib/shared/constants.dart` | Add Telegram-related constants |

## References & Research

### Internal References
- Agent loop: `lib/core/agent/agent_loop.dart` — `processMessage()` returns `Stream<AgentEvent>`
- Session manager: `lib/core/session/session_manager.dart` — `getOrCreate(key)` for per-chat sessions
- Riverpod pattern: `lib/providers/app_providers.dart` — `NotifierProvider` pattern
- Tool registry: `lib/core/tools/tool.dart` — tools already decoupled from UI

### External References
- [Telegram Bot API — getUpdates](https://core.telegram.org/bots/api#getupdates)
- [flutter_foreground_task](https://pub.dev/packages/flutter_foreground_task) v9.2.0
- [Android Foreground Service Types](https://developer.android.com/develop/background-work/services/fgs/timeout) — `remoteMessaging` has no time limit
- [Android 15 dataSync 6-hour limit](https://developer.android.com/about/versions/15/behavior-changes-15)
