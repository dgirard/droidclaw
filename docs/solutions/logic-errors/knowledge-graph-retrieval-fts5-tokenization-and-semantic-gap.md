---
title: "Fix Knowledge Graph Retrieval: Tokenization, Facts Search, and Query Expansion"
date: "2026-02-25"
category: "logic-errors"
severity: "high"
status: "resolved"

symptoms:
  - "KG query 'Ou est-ce que j habite?' failed to retrieve stored address '9 rue la Paix a Montigny-le-Bretonneux'"
  - "Agent requested GPS coordinates instead of retrieving existing knowledge from the graph"
  - "Stored facts (address, location) invisible to the retrieval pipeline"
  - "Semantic gap between natural language query and stored entity/fact tokens"

root_cause: |
  Three independent bugs prevented KG retrieval:
  1. Tokenization mismatch: _buildFtsQuery() stripped all punctuation with [^\w\s] regex, merging words across hyphens/apostrophes, while FTS5 unicode61 tokenizer splits on them
  2. Incomplete search scope: queryRelevant() only searched entities_fts (name/summary/type), never facts_fts (key/value), making stored facts invisible
  3. Semantic gap: Query tokens had zero overlap with stored entity/fact tokens, requiring LLM-based query expansion

components:
  - "lib/core/knowledge/services/knowledge_service.dart"
  - "lib/core/agent/agent_loop.dart"

tags:
  - "knowledge-graph"
  - "full-text-search"
  - "fts5"
  - "tokenization"
  - "semantic-matching"
  - "multilingual"
  - "query-expansion"
  - "facts-retrieval"

related_issues: []
---

# Fix Knowledge Graph Retrieval: Tokenization, Facts Search, and Query Expansion

## Problem

User stored "J'habite au 9 rue la Paix a Montigny-le-Bretonneux" in the Knowledge Graph. The KG had the entity, facts, and `LIVES_IN` relation. But in a new conversation, asking "Ou est-ce que j'habite?" failed to retrieve it. The agent asked for GPS coordinates instead of using the stored address.

The KG pre-query mechanism existed (`agent_loop.dart:91-106`) -- it calls `queryRelevant(userMessage)` before each LLM call. The problem was in the FTS5 query pipeline inside `knowledge_service.dart`.

## Root Cause Analysis

### Bug 1: Unicode tokenization mismatch

**File**: `lib/core/knowledge/services/knowledge_service.dart` -- `_buildFtsQuery()`

The original implementation used ASCII-only regex:

```dart
// BROKEN: [^\w\s] strips ALL punctuation, merging words
final tokens = text
    .replaceAll(RegExp(r'[^\w\s]'), '')
    .split(RegExp(r'\s+'))
    .where((t) => t.length > 1)
    .toList();
```

This strips punctuation and merges words across hyphens/apostrophes. But FTS5's `unicode61` tokenizer splits on them:

- Input: `"j'habite"` -> ASCII regex: `"jhabite"` (merged) vs FTS5: `["j", "habite"]` (split)
- Input: `"Montigny-le-Bretonneux"` -> ASCII: `"MontignyleBretonneux"` vs FTS5: `["Montigny", "le", "Bretonneux"]`

Result: no FTS5 MATCH because tokenized query differs from indexed tokens.

### Bug 2: Facts table never searched

**File**: `lib/core/knowledge/services/knowledge_service.dart` -- `queryRelevant()`

The `searchFacts` named query was defined in `schema.drift` (lines 184-189) with a proper FTS5 query on `facts_fts` (fact_key + fact_value), but it was **dead code** -- never called from `KnowledgeService.queryRelevant()`.

Only `db.searchEntities()` was called, which searches entity name, summary, and type. The user's address was stored as a **fact** (`address = "9 rue la Paix, Montigny-le-Bretonneux"`), making it completely invisible to retrieval.

### Bug 3: Semantic gap with zero token overlap

Even with perfect tokenization and fact search, `"Ou est-ce que j'habite?"` has zero token overlap with:
- Entity names: `"User"`, `"Montigny-le-Bretonneux"`
- Fact keys: `"address"`, `"coordinates"`
- Fact values: `"9 rue la Paix"`, `"48.77, 2.04"`

After stopword removal, the query reduces to `"habite"` -- which doesn't match any stored term. FTS5 is purely lexical and cannot bridge this gap.

## Solution

### Fix 1: Unicode-aware tokenization with stopword filtering

Replaced the ASCII regex with a unicode-aware split that matches FTS5 `unicode61` tokenizer behavior. Added multilingual stopwords and deduplication.

```dart
static String _buildFtsQuery(String text) {
  final tokens = text
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .map((t) => t.toLowerCase())
      .where((t) => t.length > 1 && !_stopwords.contains(t))
      .toSet() // deduplicate
      .toList();
  if (tokens.isEmpty) return '';
  return tokens.map((t) => '"$t"').join(' OR ');
}

static const _stopwords = <String>{
  // EN, FR, DE, ES, IT -- ~97 words
  'the', 'is', 'at', 'in', 'on', 'of', 'to', 'and', 'or', ...
  'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', ...
  'der', 'die', 'das', 'ein', 'eine', 'ist', 'und', ...
  'el', 'los', 'las', 'yo', 'mi', 'su', ...
  'lo', 'gli', 'io', 'lui', 'lei', ...
};
```

Key changes:
- `[^\p{L}\p{N}]+` splits on non-letter/non-digit boundaries (Unicode-aware)
- Stopwords for 5 languages (EN/FR/DE/ES/IT) reduce noise
- `.toSet()` deduplicates tokens

### Fix 2: Dual FTS search (entities + facts) with score merging

Added `db.searchFacts()` to the query pipeline and merged fact-sourced entity IDs into the BM25 candidate pool:

```dart
// 1. Entity FTS search
final ftsResults = await db.searchEntities(ftsQuery, limit * 3).get();

// 1b. Fact FTS search (NEW)
final factResults = await db.searchFacts(ftsQuery, limit * 3).get();

if (ftsResults.isEmpty && factResults.isEmpty) return [];

// Merge: map facts -> parent entity, keep best BM25 score
final bm25Scores = <int, double>{};
for (final r in ftsResults) {
  bm25Scores[r.id] = r.rank;
}
for (final f in factResults) {
  final entityId = f.entityId;
  if (bm25Scores.containsKey(entityId)) {
    if (f.rank < bm25Scores[entityId]!) {
      bm25Scores[entityId] = f.rank; // boost: better score wins
    }
  } else {
    bm25Scores[entityId] = f.rank;
  }
}
```

Also fixed:
- **Spreading activation seeds**: Now use merged BM25 scores (entity + fact combined) instead of only entity FTS results
- **Decay score computation**: Two-phase approach -- fast path from `ftsResults` data, slow path loads remaining fact-sourced entities from DB

### Fix 3: LLM-powered query expansion

Added a fast LLM call before FTS search to bridge the semantic gap:

```dart
Future<String> _expandQueryForKG(String userMessage) async {
  try {
    final response = await provider.chat(
      messages: [
        const Message(
          role: 'system',
          content: 'You are a keyword extractor for a knowledge graph search. '
              'Given a user message, output ONLY search keywords (single words) '
              'that would match stored entities, facts, or relations. '
              'Include: the original key terms, synonyms, translations (FR/EN/DE/ES/IT), '
              'and related concepts. Output one line of space-separated keywords. '
              'No punctuation, no explanations.',
        ),
        Message(role: 'user', content: userMessage),
      ],
      model: config.agent.model,
      options: {'max_tokens': 50, 'temperature': 0.0},
    );
    final keywords = response.content.trim();
    if (keywords.isNotEmpty) {
      return '$userMessage $keywords';
    }
  } catch (e) {
    AppLogger.instance.debug(LogSource.agent,
        'KG query expansion failed, using raw query: $e');
  }
  return userMessage;
}
```

Example transformation:
```
Input:  "Ou est-ce que j'habite?"
Output: "Ou est-ce que j'habite? address home residence habite domicile lieu habitation"
```

Design choices:
- `max_tokens: 50`, `temperature: 0.0` -- cheap, deterministic
- Multilingual: includes synonyms + translations
- Graceful fallback: if expansion fails, uses raw query
- Augmentation: `"$userMessage $keywords"` preserves original terms

## Verification

**On-device test**: Fresh conversation, asked "ou est ce que j habite" -> Response: "Votre adresse est 9 rue la Paix a Montigny-le-Bretonneux."

**Build**: `flutter analyze` 0 issues, release APK builds clean.

## Prevention Strategies

### Tokenization
- **Always test regex patterns against actual FTS5 tokenizer behavior**. The regex must split on the same boundaries as the configured tokenizer (`unicode61`).
- **Use unicode-aware regex by default** (`[^\p{L}\p{N}]+` with `unicode: true` flag). ASCII-only `\w` silently breaks names like "O'Brien" and non-English text.
- **Document the tokenizer contract** in code comments next to the regex pattern.

### Search Coverage
- **Audit schema queries for orphaned code**. When adding a new FTS table, verify every query method is called somewhere. Dead code silently rots.
- **Test each FTS table independently**: entity-only matches, fact-only matches, merged results, deduplication.

### Semantic Matching
- **Log failed searches** (0 results) with the original query, expanded keywords, and tokenized search string. These logs reveal semantic blind spots over time.
- **Consider caching query expansions** to reduce LLM call latency for repeated queries.

## Key Lessons

1. **Assumptions about tokenizers are dangerous.** `[^\w\s]` is not equivalent to `unicode61`. Always validate empirically.
2. **Orphaned code is a silent killer.** `searchFacts()` existed in the Drift schema but was never wired up. Without integration tests, dead code goes unnoticed.
3. **Natural language != structured data.** Users ask "Ou est-ce que j'habite?" but facts are stored as `{key: "address", value: "9 rue la Paix"}`. Query expansion via LLM bridges this vocabulary gap.
4. **FTS + entity linking is a multi-step pipeline.** Each step (expansion -> tokenization -> FTS -> merge -> ranking) must be tested independently.
5. **Multilingual stopwords matter.** A French question is mostly stopwords -- without filtering, the FTS query is overwhelmed with noise tokens.

## Cross-References

- [i18n with dual-isolate support](../architecture/implement-i18n-with-dual-isolate-support.md) -- locale-aware text processing patterns
- [LLM agent locale prompt engineering](llm-agent-locale-prompt-engineering.md) -- system prompt instruction positioning
- [Decouple cron from Telegram](../architecture/decouple-cron-from-telegram-autonomous-service.md) -- ServiceAgentFactory pattern, service isolate KG constraints
- [KG system plan](../../plans/2026-02-24-feat-local-knowledge-graph-memory-system-plan.md) -- full KG architecture, schema, algorithms
- [KG retrieval fix plan](../../plans/2026-02-25-fix-knowledge-graph-retrieval-plan.md) -- detailed investigation and plan for this fix
