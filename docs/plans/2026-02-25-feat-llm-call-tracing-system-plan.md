---
title: "feat: LLM Call Tracing System"
type: feat
date: 2026-02-25
---

# LLM Call Tracing System

## Overview

Add a dedicated LLM call tracing system that records every API call made to LLM providers, with full request/response data, token usage, and latency. Traces are persisted for 24h and browsable via a dedicated UI screen with filtering, detail views, and token usage summaries.

## Problem Statement

Currently, LLM calls are logged as one-line `AppLogger.info()` entries ("LLM responded: content=142 chars, toolCalls=1, finish=tool_use") with no structured data — no token counts, no latency, no request content. When debugging agent behavior or monitoring API costs, there is no way to inspect what was actually sent to and received from the LLM.

## Proposed Solution

A lightweight tracing layer that:
1. Captures structured trace data at the two existing `provider.chat()` call sites in `AgentLoop`
2. Persists traces as JSONL with 24h retention (same pattern as `AppLogger`)
3. Provides a dedicated UI screen with a list view + expandable detail view

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Storage | Separate JSONL file (NOT reuse AppLogger) | Traces are much larger (contain full messages), different retention needs, dedicated purge |
| Dual-isolate | Separate files per isolate, merge on read | Same proven pattern as AppLogger — avoids concurrent write issues |
| Data captured | System prompt + messages + response + usage + latency | Full observability without needing to reproduce the call |
| System prompt storage | Truncated to first 500 chars | Full system prompt is 2-5KB, would bloat traces; first 500 chars gives enough context |
| Message storage | Full content for user/assistant, summarized for tool messages | Tool results can be huge (web scrape); store name + first 200 chars |
| Retention | 24h + 500 entry hard cap | LLM traces are larger than log entries; tighter cap prevents disk bloat |

## Technical Approach

### Data Model

New file: `lib/core/config/llm_trace.dart`

```dart
class LlmTrace {
  final String id;               // UUID v4
  final DateTime timestamp;
  final String provider;         // "anthropic", "openrouter", "gemini"
  final String model;            // "gemini-2.0-flash", "claude-sonnet-4-20250514"
  final String callType;         // "chat", "summarize", "extract" (KG extraction)
  final int iteration;           // agent loop iteration (0 for summarize/extract)
  final String? sessionKey;

  // Request
  final int messageCount;        // number of messages sent
  final int systemPromptChars;   // system prompt length
  final String systemPromptPreview; // first 500 chars of system prompt
  final List<LlmTraceMessage> messages; // compact message list
  final int toolDefinitionCount; // number of tool definitions sent

  // Response
  final String? responseContent; // assistant response (null on error)
  final int? responseChars;
  final List<String> toolCalls;  // tool names called ["get_location", "get_address"]
  final String? finishReason;    // "stop", "tool_use", "max_tokens"
  final String? error;           // error message if call failed

  // Metrics
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int latencyMs;           // wall-clock time of the API call

  // toJson(), fromJson()
}

class LlmTraceMessage {
  final String role;             // "user", "assistant", "tool", "system"
  final int contentLength;       // character count
  final String preview;          // first 200 chars
  final String? toolName;        // for tool results

  // toJson(), fromJson()
}
```

### Trace Logger

New file: `lib/core/services/llm_trace_logger.dart`

```dart
class LlmTraceLogger {
  static LlmTraceLogger? _instance;
  static bool get isInitialized => _instance != null;
  static LlmTraceLogger get instance => _instance ?? _NoOpTraceLogger();

  static void init({required String dirPath, required String isolateName});

  void log(LlmTrace trace);                    // append to JSONL
  Future<List<LlmTrace>> readAll();            // merge both isolate files
  Future<int> purge();                          // 24h + 500 cap
  Future<void> clearAll();

  // Aggregates for UI header
  Future<LlmTraceStats> getStats();            // total calls, total tokens, avg latency
}

class LlmTraceStats {
  final int totalCalls;
  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int avgLatencyMs;
  final DateTime? oldestTrace;
  final DateTime? newestTrace;
}
```

Files:
- Main isolate: `<appDir>/llm_traces_main.jsonl`
- Service isolate: `<appDir>/llm_traces_service.jsonl`

Same IOSink append pattern as AppLogger. Purge: 24h retention + 500 entry hard cap (traces are larger than log entries).

### Instrumentation Points

**Site 1 — Main agent loop** (`lib/core/agent/agent_loop.dart:132`)

```dart
// Before call
final stopwatch = Stopwatch()..start();
final traceMessages = _buildTraceMessages(messages);

// After call
stopwatch.stop();
LlmTraceLogger.instance.log(LlmTrace(
  provider: provider.providerName,
  model: config.agent.model,
  callType: 'chat',
  iteration: iteration,
  sessionKey: sessionKey,
  messageCount: messages.length,
  systemPromptChars: systemPrompt.length,
  systemPromptPreview: systemPrompt.substring(0, min(500, systemPrompt.length)),
  messages: traceMessages,
  toolDefinitionCount: tools.getDefinitions().length,
  responseContent: response.content,
  responseChars: response.content.length,
  toolCalls: response.toolCalls.map((tc) => tc.name).toList(),
  finishReason: response.finishReason,
  promptTokens: response.usage?.promptTokens,
  completionTokens: response.usage?.completionTokens,
  totalTokens: response.usage?.totalTokens,
  latencyMs: stopwatch.elapsedMilliseconds,
));
```

**Site 2 — Summarization** (`lib/core/agent/agent_loop.dart:249`)

Same pattern, `callType: 'summarize'`.

**Site 3 — KG extraction** (`lib/core/knowledge/services/entity_extractor.dart`)

Same pattern, `callType: 'extract'`.

**Error case**: When `provider.chat()` throws, log the trace with `error: e.toString()` and null response fields.

### Initialization

In `main.dart` (main isolate) and `background_task_handler.dart` (service isolate), init alongside AppLogger:

```dart
LlmTraceLogger.init(dirPath: appDir, isolateName: 'main');
```

### UI Screen

New file: `lib/features/settings/llm_traces_screen.dart`

#### List View (main screen)

```
┌──────────────────────────────────────┐
│ ← Traces LLM                        │
├──────────────────────────────────────┤
│ 📊 42 appels · 125K tokens · 2.1s   │  ← Stats header
│    (dernières 24h)                   │
├──────────────────────────────────────┤
│ ⚡ Filtre: [Tous ▼] [gemini ▼]     │  ← Filter row
├──────────────────────────────────────┤
│ 🟢 09:15:42  gemini-2.0-flash       │
│    chat · iter 2 · 1.2s             │
│    ↗ 1,240 tokens  ↙ 89 tokens      │
├──────────────────────────────────────┤
│ 🟢 09:15:38  gemini-2.0-flash       │
│    chat · iter 1 · 0.8s             │
│    ↗ 980 tokens  ↙ 156 tokens       │
├──────────────────────────────────────┤
│ 🔴 09:15:35  gemini-2.0-flash       │
│    chat · iter 0 · 3.2s  ERROR      │
│    ↗ 1,100 tokens  ↙ 0 tokens       │
├──────────────────────────────────────┤
│ 🟡 09:10:12  gemini-2.0-flash       │
│    summarize · 1.5s                  │
│    ↗ 2,400 tokens  ↙ 312 tokens     │
└──────────────────────────────────────┘
```

- Green dot = success, Red = error, Yellow = summarize/extract
- Sorted by timestamp descending (newest first)
- Pull to refresh
- Filter by: call type (chat/summarize/extract/all), provider/model

#### Detail View (tap on a trace)

New screen or bottom sheet showing:

```
┌──────────────────────────────────────┐
│ ← Détail trace                       │
├──────────────────────────────────────┤
│ 09:15:42 · gemini-2.0-flash         │
│ chat · iteration 2 · session: default│
│ Latence: 1,234 ms                    │
├──────────────────────────────────────┤
│ TOKENS                               │
│ ┌─────────┬─────────┬──────────┐    │
│ │ Entrée  │ Sortie  │  Total   │    │
│ │  1,240  │   89    │  1,329   │    │
│ └─────────┴─────────┴──────────┘    │
├──────────────────────────────────────┤
│ ▶ Prompt système (3,421 chars)       │  ← Expandable
│   "You are DroidClaw, a personal..." │
├──────────────────────────────────────┤
│ ▶ Messages (5)                       │  ← Expandable
│   👤 user: "peux-tu me dire où..."   │
│   🤖 assistant: "Calling get_loc..." │
│   🔧 tool [get_location]: "Locat..." │
│   🔧 tool [get_address]: "actual..." │
│   👤 user: (current turn)            │
├──────────────────────────────────────┤
│ ▶ Réponse (142 chars)                │  ← Expandable
│   "Il faut environ 46 minutes..."    │
├──────────────────────────────────────┤
│ ▶ Outils appelés: get_directions     │
│ ▶ Finish reason: tool_use            │
└──────────────────────────────────────┘
```

Each section is expandable (collapsed by default). Tapping expands to show full content with copy-to-clipboard button.

### Route & Navigation

- Route: `/settings/llm-traces`
- ListTile in `settings_screen.dart` in the "Outils" section:
  - Icon: `Icons.analytics_outlined`
  - Title: "Traces LLM" / "LLM Traces"
  - Subtitle: brief stats ("42 appels, 125K tokens")

## Implementation Phases

### Phase 1: Data Model + Logger

**Tasks:**
- [x] Create `lib/core/config/llm_trace.dart` — `LlmTrace` + `LlmTraceMessage` with `fromJson`/`toJson`
- [x] Create `lib/core/services/llm_trace_logger.dart` — singleton, JSONL persistence, merge, purge, stats
- [x] Initialize in `main.dart` and `background_task_handler.dart`
- [x] Add constants in `constants.dart` (file names, retention cap)

### Phase 2: Instrumentation

**Tasks:**
- [x] Instrument main agent loop call site (`agent_loop.dart:132`) with Stopwatch + trace logging
- [x] Instrument summarization call site (`agent_loop.dart:249`)
- [x] Instrument KG extraction call site (`entity_extractor.dart`)
- [x] Handle error cases (log trace with error field on exception)
- [x] Add helper `_buildTraceMessages()` to convert `List<Message>` to compact `List<LlmTraceMessage>`

### Phase 3: UI — List Screen

**Tasks:**
- [x] Create `lib/features/settings/llm_traces_screen.dart` — list view with stats header
- [x] Add filter chips (call type, provider)
- [x] Add trace tile widget with color-coded status, tokens, latency
- [x] Add route `/settings/llm-traces` in `app.dart`
- [x] Add ListTile in `settings_screen.dart`
- [x] Add pull-to-refresh + clear all button

### Phase 4: UI — Detail View + i18n

**Tasks:**
- [x] Create detail screen/bottom sheet with expandable sections
- [x] System prompt preview (expandable to full)
- [x] Messages list with role icons and previews (expandable)
- [x] Response content (expandable)
- [x] Copy-to-clipboard on expanded sections
- [x] Add ~20 ARB keys across 5 locales (EN/FR/ES/DE/IT)

## Files Modified

### New Files (4)

| File | Description |
|------|-------------|
| `lib/core/config/llm_trace.dart` | LlmTrace + LlmTraceMessage data model |
| `lib/core/services/llm_trace_logger.dart` | Singleton JSONL logger, merge, purge, stats |
| `lib/features/settings/llm_traces_screen.dart` | List view with filters + stats header |
| `lib/features/settings/llm_trace_detail_screen.dart` | Detail view with expandable sections |

### Modified Files (~10)

| File | Change |
|------|--------|
| `lib/shared/constants.dart` | Trace file names, retention cap (500) |
| `lib/main.dart` | Init `LlmTraceLogger` alongside `AppLogger` |
| `lib/core/services/background_task_handler.dart` | Init `LlmTraceLogger` in service isolate |
| `lib/core/agent/agent_loop.dart` | Instrument 2 call sites with Stopwatch + trace logging |
| `lib/core/knowledge/services/entity_extractor.dart` | Instrument KG extraction call |
| `lib/app.dart` | Add `/settings/llm-traces` route |
| `lib/features/settings/settings_screen.dart` | Add LLM Traces ListTile |
| All 5 `lib/l10n/app_*.arb` files | ~20 new keys each |

## Acceptance Criteria

- [x] Every `provider.chat()` call generates a trace entry
- [x] Traces include: provider, model, tokens (in/out), latency, messages, response
- [x] Traces persist across app restarts (JSONL files)
- [x] Traces auto-purge after 24h (500 entry hard cap)
- [x] Service isolate LLM calls (cron) are also traced
- [x] UI list shows all traces with color-coded status, token counts, latency
- [x] UI detail shows full request/response with expandable sections
- [x] Filter by call type and provider works
- [x] Stats header shows total calls, total tokens, avg latency
- [x] All UI strings localized in 5 languages
- [x] `flutter analyze` — 0 issues
- [x] APK builds and runs correctly
