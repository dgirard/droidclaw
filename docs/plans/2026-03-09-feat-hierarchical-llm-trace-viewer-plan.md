---
title: "feat: Hierarchical LLM trace viewer with session tree"
type: feat
date: 2026-03-09
---

# feat: Hierarchical LLM trace viewer with session tree

## Overview

Replace the flat chronological list in the LLM traces screen with a **session-grouped tree view** that shows the agent's reasoning flow: user prompt → LLM calls → tool executions → follow-up calls → final response. Each session becomes an expandable node revealing the full agent loop as a visual timeline.

## Problem Statement

The current `LlmTracesScreen` shows a flat list of all LLM calls sorted by time. When debugging agent behavior, it's impossible to:

1. **See which prompt triggered which calls** — traces from different sessions interleave
2. **Follow the agent loop flow** — iteration 0 → tools → iteration 1 → ... → response is invisible
3. **Distinguish user vs cron vs extract calls** — they're all mixed together
4. **Understand cost per query** — tokens are shown per-call, not aggregated per session

The data already exists in `LlmTrace` (`sessionKey`, `iteration`, `callType`, `toolCalls`) — it just isn't displayed hierarchically.

## Proposed Solution

### Two-level architecture: Session List → Session Timeline

**Level 1: Session List** (replaces current flat list)

Group traces by `sessionKey`. Each session shows:
- User's original prompt (from the first `chat` trace's messages, find the last `user` role message preview)
- Session type badge: "Chat", "Cron", "KG Extract" (inferred from sessionKey prefix + callTypes)
- Aggregate stats: total LLM calls, total tokens (in+out), total latency, tool count
- Timestamp of first call
- Expandable: tap to reveal session timeline

```
┌─────────────────────────────────────────────────┐
│ 🟢 14:32  "Quelle est la météo à Paris ?"       │
│    Chat · 3 calls · 4.2K tokens · 3.8s          │
│    Tools: web_search, weather                    │
├─────────────────────────────────────────────────┤
│ 🟢 14:15  "Résume cet article..."                │
│    Chat · 5 calls · 12.1K tokens · 8.2s         │
│    Tools: web_scrape, web_scrape_js              │
├─────────────────────────────────────────────────┤
│ 🟡 14:00  [Cron] Revue de presse                 │
│    Cron · 8 calls · 28.3K tokens · 22.1s        │
│    Tools: web_search, web_scrape ×3, file        │
└─────────────────────────────────────────────────┘
```

**Level 2: Session Timeline** (new screen, pushed via `Navigator.push`)

Shows the agent loop as a vertical timeline with connecting lines:

```
● User: "Quelle est la météo à Paris ?"
│
├─ 🔵 LLM Call #0 (1.2s, 1.8K tokens)
│  └─ Tools called: get_location, weather
│
├─ 🔵 LLM Call #1 (1.4s, 1.6K tokens)
│  └─ Tools called: get_datetime
│
├─ 🟢 LLM Call #2 → Final response (1.2s, 0.8K tokens)
│  └─ "Il fait 18°C à Paris, ciel dégagé..."
│
└─ 🟡 Summarize (0.8s, 2.1K tokens)    [if triggered]
```

Each node is tappable → opens existing `LlmTraceDetailScreen`.

### Data Model: No Schema Changes to LlmTrace

The existing `LlmTrace` fields are sufficient. One small instrumentation fix: pass `sessionKey` to summarize/extract trace calls (currently missing — see Technical Considerations).

| Field | Used for |
|---|---|
| `sessionKey` | Group traces into sessions |
| `iteration` | Order within session, show loop progression |
| `callType` | Distinguish chat/summarize/extract nodes |
| `toolCalls` | Show which tools were called per iteration |
| `messages` | Extract user prompt preview from first trace |
| `promptTokens` + `completionTokens` | Aggregate per session |
| `latencyMs` | Aggregate per session |
| `error` | Red status on failed nodes |
| `finishReason` | Identify final response (finish=stop, no tool calls) |

### Session Type Detection

```dart
String _sessionType(String? sessionKey, List<LlmTrace> traces) {
  if (sessionKey == null) return 'unknown';
  if (sessionKey.startsWith('cron_')) return 'cron';
  // If ALL traces are 'extract', it's a KG extraction session
  if (traces.every((t) => t.callType == 'extract')) return 'extract';
  return 'chat';
}
```

### User Prompt Extraction

From the first `chat` trace in the session, scan `messages` for the last `user` role message:

```dart
String _extractUserPrompt(List<LlmTrace> sessionTraces) {
  final firstChat = sessionTraces.firstWhere(
    (t) => t.callType == 'chat',
    orElse: () => sessionTraces.first,
  );
  // Messages are in context order; find last user message (the trigger)
  final userMsg = firstChat.messages.lastWhere(
    (m) => m.role == 'user',
    orElse: () => firstChat.messages.first,
  );
  return userMsg.preview;
}
```

### Aggregated Session Stats

```dart
class _SessionGroup {
  final String? sessionKey;
  final String sessionType; // 'chat', 'cron', 'extract'
  final String userPrompt;
  final List<LlmTrace> traces; // sorted by timestamp asc
  final DateTime firstCall;
  final int totalCalls;
  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int totalLatencyMs;
  final Set<String> allTools;
  final bool hasError;
}
```

## Implementation

### Files to Modify

| File | Change |
|---|---|
| `lib/features/settings/llm_traces_screen.dart` | Replace flat list with session-grouped list |
| `lib/features/settings/llm_session_timeline_screen.dart` | **New** — timeline view for a single session |
| `lib/l10n/app_*.arb` (5 files) | Add i18n keys for session grouping + timeline |

### Minor Instrumentation Fix (prerequisite)

| File | Change |
|---|---|
| `lib/core/agent/agent_loop.dart:405` | Add `sessionKey: sessionKey` to summarize `LlmTrace` call |
| `lib/core/knowledge/services/entity_extractor.dart:137` | Add `sessionKey` parameter to extract `LlmTrace` call (requires passing sessionKey to `extractAndStore`) |

Currently summarize and extract traces are logged without `sessionKey`, making grouping impossible without heuristics. Adding the parameter at the call site is trivial — `sessionKey` is already in scope in `agent_loop.dart`, and can be passed through to `entity_extractor.dart`.

### Files NOT Modified

- `lib/core/config/llm_trace.dart` — data model unchanged (sessionKey field already exists)
- `lib/core/services/llm_trace_logger.dart` — logging unchanged
- `lib/features/settings/llm_trace_detail_screen.dart` — keep as-is, reached from timeline nodes

### Phase 1: Session-Grouped List (main screen refactor)

Replace `ListView.separated` in `LlmTracesScreen` with a grouped view:

1. After loading traces, group by `sessionKey` into `_SessionGroup` objects
2. Sort groups by `firstCall` descending (newest first)
3. Display each group as a tappable `ListTile` that pushes the timeline screen
4. Keep existing filter chips (callType, provider) — they filter traces before grouping
5. Keep stats header — shows global aggregates
6. Traces with `sessionKey == null` grouped under "Ungrouped" section

**Session tile widget:**
```dart
ListTile(
  leading: _StatusDot(hasError: group.hasError, type: group.sessionType),
  title: Text(group.userPrompt, maxLines: 1, overflow: TextOverflow.ellipsis),
  subtitle: Text('${group.sessionType} · ${group.totalCalls} calls · '
      '${formatTokens(group.totalPromptTokens + group.totalCompletionTokens)} tokens · '
      '${(group.totalLatencyMs / 1000).toStringAsFixed(1)}s'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => LlmSessionTimelineScreen(group: group),
  )),
)
```

### Phase 2: Session Timeline Screen (new)

Vertical timeline showing the agent loop flow:

1. **Header**: User prompt (full text, scrollable), session key, timestamp
2. **Timeline nodes**: Each `LlmTrace` in the session, ordered by timestamp
   - **Chat node**: Shows iteration number, latency, tokens, tool calls
   - **Summarize node**: Yellow accent, shows "Context summarization"
   - **Extract node**: Amber accent, shows "KG extraction"
   - **Error node**: Red accent with error message
3. **Connecting lines**: Vertical line between nodes (Flutter `CustomPaint` or simple `Container` with border)
4. **Tap to detail**: Each node opens `LlmTraceDetailScreen`

**Timeline node layout:**
```
  │
  ├── ● LLM Call #0                      1.2s  1.8K tokens
  │   └─ → get_location, weather
  │
  ├── ● LLM Call #1                      1.4s  1.6K tokens
  │   └─ → get_datetime
  │
  ├── ● Final Response                   1.2s  0.8K tokens
  │   └─ "Il fait 18°C à Paris..."
  │
  └── ○ Summarize                        0.8s  2.1K tokens
```

Implementation with simple widgets (no custom painting needed):

```dart
// Each node is a Row with:
// [vertical line column] [dot] [content card]
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Vertical connector line
    SizedBox(
      width: 24,
      child: Column(
        children: [
          Container(width: 2, height: 12, color: lineColor), // top segment
          Container(width: 10, height: 10, decoration: BoxDecoration(
            color: dotColor, shape: BoxShape.circle)),
          if (!isLast)
            Container(width: 2, height: 40, color: lineColor), // bottom segment
        ],
      ),
    ),
    // Content card
    Expanded(child: _TimelineNodeCard(trace: trace)),
  ],
)
```

### Phase 3: Polish

- **Pull-to-refresh** on session list
- **Total cost summary** per session in timeline header

## i18n Keys to Add (5 locales)

| Key | EN |
|---|---|
| `llmTracesSessionCalls` | `{count} calls` |
| `llmTracesSessionTokens` | `{tokens} tokens` |
| `llmTracesSessionCron` | `Cron` |
| `llmTracesSessionChat` | `Chat` |
| `llmTracesSessionExtract` | `Extract` |
| `llmTracesUngrouped` | `Ungrouped calls` |
| `llmTimelineTitle` | `Session Timeline` |
| `llmTimelineFinalResponse` | `Final response` |
| `llmTimelineSummarize` | `Context summarization` |
| `llmTimelineExtract` | `KG extraction` |
| `llmTimelineToolsCalled` | `Tools: {tools}` |
| `llmTimelineUserPrompt` | `Prompt` |

## Acceptance Criteria

- [x] Traces screen groups traces by sessionKey
- [x] Each session group shows: user prompt preview, type badge, aggregate stats (calls, tokens, latency, tools)
- [x] Tapping a session opens the timeline screen
- [x] Timeline shows vertical tree with nodes for each LLM call
- [x] Nodes show: iteration, latency, tokens, tool calls, error status
- [x] Final response node shows response text preview
- [x] Summarize/extract calls shown as distinct node types
- [x] Tapping a timeline node opens existing trace detail screen
- [x] Existing filter chips still work (filter before grouping)
- [x] Stats header still shows global aggregates
- [x] Cron sessions detected by sessionKey prefix and labeled
- [x] i18n keys in all 5 locales
- [x] `flutter analyze` passes with 0 issues

## Technical Considerations

- **No data model changes**: All grouping is done at the UI layer using existing `LlmTrace` fields
- **Performance**: Grouping 500 traces by sessionKey is O(n), negligible
- **Null sessionKey on old traces**: After the instrumentation fix, new summarize/extract traces will have `sessionKey`. Old traces without it go to "Ungrouped" — no timestamp heuristics needed.
- **Interleaved sessions**: If two sessions run concurrently (main + service isolate), they have different sessionKeys and group correctly.
- **Filter interaction**: Filters narrow the trace list before grouping. If all traces of a session are filtered out, the session disappears.

## References

- `lib/features/settings/llm_traces_screen.dart` — current flat list (to refactor)
- `lib/features/settings/llm_trace_detail_screen.dart` — detail screen (keep, link from timeline)
- `lib/core/config/llm_trace.dart` — data model with sessionKey, iteration, callType, toolCalls
- `lib/core/services/llm_trace_logger.dart` — trace storage (500 entry cap)
- `lib/core/agent/agent_loop.dart:169-173` — where traces are logged (info + LlmTraceLogger.log)
- `docs/plans/2026-02-25-feat-llm-call-tracing-system-plan.md` — original tracing plan
