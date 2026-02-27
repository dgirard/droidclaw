---
title: "feat: Rebuild Knowledge Base from conversation history"
type: feat
date: 2026-02-27
---

# feat: Rebuild Knowledge Base from Conversation History

## Overview

Add a "Rebuild KB" button in the Knowledge Graph settings screen that re-processes all stored conversation sessions through the `IngestionPipeline` to populate the Knowledge Base retroactively. This lets users who enabled KB after already having conversation history backfill their knowledge graph.

## Problem Statement

Currently, KB extraction only happens live during conversations (`AgentLoop._extractAsync()`). Users who:
- Enabled KB after weeks of using the app
- Had KB disabled temporarily and re-enabled it
- Ran "Forget Everything" and want to rebuild from history

...have no way to retroactively extract knowledge from their existing conversation history.

## Proposed Solution

A single button in `knowledge_config_screen.dart` that:

1. Counts conversation turns across all sessions
2. Shows a confirmation dialog with the count
3. Iterates sessions sequentially, extracting user/assistant message pairs
4. Runs each pair through `IngestionPipeline.extractAndStore()`
5. Shows a determinate progress indicator with cancel support
6. Displays a summary on completion

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Additive vs. clear-first** | Additive | `EntityResolver` deduplicates via alias + Jaro-Winkler. `updateFactBiTemporal` upserts facts. Safe and non-destructive. |
| **Isolate** | Main isolate | Settings screen is on main isolate. DB + LLM provider already available via Riverpod. UI updates require main isolate. |
| **Rate limiting** | 2s delay between calls | Gemini Flash free tier: 15 RPM. 2s delay = 30 RPM (safe margin). Adaptive backoff on 429. |
| **Session types** | All sessions | Telegram + cron sessions contain valid knowledge. Entity resolution handles duplicates. |
| **Summarized content** | Process summary as single turn | Summary captures compressed knowledge from truncated messages. Better than losing it. |

### Message Pairing Algorithm

Walk the session message list sequentially. For each `user` message, find the next `assistant` message where `content.isNotEmpty && (toolCalls == null || toolCalls!.isEmpty)`. Skip `tool` and `system` messages entirely. This matches how `AgentLoop._extractAsync()` pairs messages implicitly.

```
Example: [user("What's the weather?"), assistant("", toolCalls=[weather]), tool(result), assistant("It's 22C")]
Pair: ("What's the weather?", "It's 22C and sunny")
```

For sessions with a non-empty `summary`, also process: `(summary, '')` as a standalone extraction turn before the remaining messages.

## Implementation

### Change 1: Add `ingestionPipelineProvider` (`lib/providers/app_providers.dart`)

Extract the inline pipeline construction from `agentLoopProvider` into a dedicated provider so both the agent loop and the rebuild screen can access it.

```dart
final ingestionPipelineProvider =
    FutureProvider<IngestionPipeline?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!config.knowledge.enabled) return null;

  final kgDb = await ref.watch(knowledgeGraphDbProvider.future);
  if (kgDb == null) return null;

  final provider = await ref.watch(llmProviderProvider.future);
  final embeddingProvider = await ref.watch(embeddingProviderProvider.future);

  return IngestionPipeline(
    extractor: EntityExtractor(
      provider: provider,
      model: config.agent.model,
      kbLanguage: config.knowledge.kbLanguage,
    ),
    resolver: EntityResolver(kgDb),
    db: kgDb,
    embeddingProvider: embeddingProvider,
    embeddingModel: config.embedding.model,
    embeddingDimensions: config.embedding.dimensions,
    kbLanguage: config.knowledge.kbLanguage,
  );
});
```

Update `agentLoopProvider` to use `ref.watch(ingestionPipelineProvider.future)` instead of constructing inline.

### Change 2: Add message pairing utility (`lib/core/knowledge/services/ingestion_pipeline.dart`)

Add a static helper to extract user/assistant pairs from a session:

```dart
/// Extract (userMessage, assistantResponse) pairs from session messages.
/// Skips tool/system messages and assistant messages with only tool calls.
static List<(String, String)> extractPairs(List<Message> messages) {
  final pairs = <(String, String)>[];
  for (var i = 0; i < messages.length; i++) {
    if (messages[i].role != 'user' || messages[i].content.isEmpty) continue;
    final userMsg = messages[i].content;
    // Find next assistant message with actual content
    for (var j = i + 1; j < messages.length; j++) {
      if (messages[j].role == 'user') break; // next user turn, no match
      if (messages[j].role == 'assistant' &&
          messages[j].content.isNotEmpty &&
          (messages[j].toolCalls == null || messages[j].toolCalls!.isEmpty)) {
        pairs.add((userMsg, messages[j].content));
        break;
      }
    }
  }
  return pairs;
}
```

### Change 3: Add rebuild UI to `knowledge_config_screen.dart`

Add state variables and a new ListTile between "Browse" and "Forget everything":

**State:**
```dart
bool _rebuildInProgress = false;
bool _rebuildCancelled = false;
int _rebuildCurrent = 0;
int _rebuildTotal = 0;
```

**UI (new ListTile):**
```dart
ListTile(
  leading: Icon(_rebuildInProgress ? Icons.sync : Icons.replay),
  title: Text(l.knowledgeRebuild),
  subtitle: _rebuildInProgress
      ? Column(children: [
          LinearProgressIndicator(value: _rebuildTotal > 0 ? _rebuildCurrent / _rebuildTotal : null),
          Text(l.knowledgeRebuildProgress(_rebuildCurrent, _rebuildTotal)),
        ])
      : Text(l.knowledgeRebuildDesc),
  trailing: _rebuildInProgress
      ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _rebuildCancelled = true))
      : null,
  onTap: _rebuildInProgress ? null : _confirmRebuild,
),
```

**Confirmation dialog:**
```dart
Future<void> _confirmRebuild() async {
  final sessions = await ref.read(sessionManagerProvider.future);
  final allSessions = sessions.getAllSessions();

  // Count pairs across all sessions
  int totalPairs = 0;
  for (final session in allSessions) {
    if (session.summary != null && session.summary!.isNotEmpty) totalPairs++;
    totalPairs += IngestionPipeline.extractPairs(session.messages).length;
  }

  if (totalPairs == 0) {
    // Show snackbar: no conversations to process
    return;
  }

  final confirmed = await showDialog<bool>(...);
  if (confirmed != true) return;

  await _runRebuild(allSessions, totalPairs);
}
```

**Rebuild loop:**
```dart
Future<void> _runRebuild(List<Session> sessions, int totalPairs) async {
  final pipeline = await ref.read(ingestionPipelineProvider.future);
  if (pipeline == null) return;

  setState(() {
    _rebuildInProgress = true;
    _rebuildCancelled = false;
    _rebuildCurrent = 0;
    _rebuildTotal = totalPairs;
  });

  int processed = 0;
  int failed = 0;

  for (final session in sessions) {
    if (_rebuildCancelled) break;

    // Process summary if present
    if (session.summary != null && session.summary!.isNotEmpty) {
      try {
        await pipeline.extractAndStore(
          userMessage: session.summary!,
          assistantResponse: '',
        );
        processed++;
      } catch (_) {
        failed++;
      }
      setState(() => _rebuildCurrent++);
      await Future.delayed(const Duration(seconds: 2)); // Rate limit
    }

    // Process message pairs
    final pairs = IngestionPipeline.extractPairs(session.messages);
    for (final (userMsg, assistantMsg) in pairs) {
      if (_rebuildCancelled) break;
      try {
        await pipeline.extractAndStore(
          userMessage: userMsg,
          assistantResponse: assistantMsg,
        );
        processed++;
      } catch (_) {
        failed++;
      }
      setState(() => _rebuildCurrent++);
      await Future.delayed(const Duration(seconds: 2)); // Rate limit
    }
  }

  setState(() => _rebuildInProgress = false);
  _loadStats(); // Refresh stats display

  // Show completion snackbar
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(_rebuildCancelled
        ? l.knowledgeRebuildCancelled(processed)
        : l.knowledgeRebuildComplete(processed, failed)),
  ));
}
```

### Change 4: Add i18n strings (5 ARB files)

New keys needed in all 5 locale files:

| Key | EN | FR |
|-----|----|----|
| `knowledgeRebuild` | `Rebuild from conversations` | `Reconstruire depuis les conversations` |
| `knowledgeRebuildDesc` | `Re-process all conversation history into the knowledge base` | `Retraiter tout l'historique des conversations dans la base de connaissances` |
| `knowledgeRebuildConfirmTitle` | `Rebuild Knowledge Base?` | `Reconstruire la base de connaissances ?` |
| `knowledgeRebuildConfirmBody` | `This will process {count} conversation turns across {sessions} sessions. Each turn requires one LLM API call. This may take several minutes.` | `Ceci va traiter {count} tours de conversation dans {sessions} sessions. Chaque tour nécessite un appel API LLM. Cela peut prendre plusieurs minutes.` |
| `knowledgeRebuildProgress` | `Processing {current} of {total}...` | `Traitement {current} sur {total}...` |
| `knowledgeRebuildComplete` | `Rebuild complete: {processed} turns processed, {failed} failed` | `Reconstruction terminée : {processed} tours traités, {failed} échoués` |
| `knowledgeRebuildCancelled` | `Rebuild cancelled after {processed} turns` | `Reconstruction annulée après {processed} tours` |
| `knowledgeRebuildEmpty` | `No conversations to process` | `Aucune conversation à traiter` |

Also add ES, DE, IT translations.

### Change 5: Refactor `agentLoopProvider` to use `ingestionPipelineProvider`

In `lib/providers/app_providers.dart`, replace the inline `IngestionPipeline` construction in `agentLoopProvider` with:

```dart
final ingestionPipeline = await ref.watch(ingestionPipelineProvider.future);
```

This deduplicates the construction logic and ensures both the agent loop and rebuild screen use the same configuration.

## Files to Modify

1. `lib/providers/app_providers.dart` — new `ingestionPipelineProvider` + refactor `agentLoopProvider`
2. `lib/core/knowledge/services/ingestion_pipeline.dart` — add `extractPairs()` static method
3. `lib/features/settings/knowledge_config_screen.dart` — rebuild button, progress UI, confirmation dialog, rebuild loop
4. `lib/l10n/app_en.arb` — 8 new keys
5. `lib/l10n/app_fr.arb` — 8 new keys (translated)
6. `lib/l10n/app_es.arb` — 8 new keys (translated)
7. `lib/l10n/app_de.arb` — 8 new keys (translated)
8. `lib/l10n/app_it.arb` — 8 new keys (translated)

Then regenerate l10n: `flutter gen-l10n`

## Acceptance Criteria

- [x] "Rebuild from conversations" button appears in KB settings when KB is enabled
- [x] Confirmation dialog shows session count and turn count before starting
- [x] Determinate progress indicator with "Processing X of Y..." text
- [x] Cancel button stops processing (already-processed data is retained)
- [x] Button is disabled during rebuild (no double-tap)
- [x] 2s delay between API calls (rate limit protection)
- [x] Message pairing skips tool/system messages and empty assistant messages
- [x] Session summaries are processed as standalone extraction turns
- [x] Stats refresh after rebuild completes
- [x] Completion snackbar shows processed/failed counts
- [x] All strings localized in 5 languages (EN/FR/ES/DE/IT)
- [x] `flutter analyze` — 0 issues
- [x] `agentLoopProvider` refactored to use `ingestionPipelineProvider` (no duplication)

## Edge Cases

| Case | Handling |
|------|----------|
| No sessions / no conversation turns | Show "No conversations to process" snackbar, no dialog |
| App killed mid-rebuild | Partial rebuild persisted. Re-running is safe (additive). |
| Rate limit (429) from LLM | EntityExtractor catches and returns empty result. Counted as "failed". |
| Concurrent live auto-extract | SQLite serializes writes. Minor risk of duplicate entities (acceptable). |
| Session with only tool messages | `extractPairs()` returns empty list — session is skipped |
| Session summary + last 4 messages | Both processed: summary as one turn, then remaining pairs |

## References

- `IngestionPipeline.extractAndStore()`: `lib/core/knowledge/services/ingestion_pipeline.dart:44-131`
- `AgentLoop._extractAsync()`: `lib/core/agent/agent_loop.dart:321-338`
- `KnowledgeConfigScreen`: `lib/features/settings/knowledge_config_screen.dart`
- `SessionManager.getAllSessions()`: `lib/core/session/session_manager.dart:66-69`
- `agentLoopProvider` pipeline construction: `lib/providers/app_providers.dart:339-354`
- KB architecture doc: `docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md`
