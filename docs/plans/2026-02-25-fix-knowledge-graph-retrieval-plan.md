---
title: "fix: Knowledge Graph Retrieval — FTS5 query fails for semantic queries"
type: fix
date: 2026-02-25
---

# Fix: Knowledge Graph Pre-Query Retrieval

## Problem

The user stored "J'habite au 9 rue la Paix à Montigny-le-Bretonneux" in a conversation. The KG correctly contains:
- Entity "Montigny-le-Bretonneux" (PLACE) with latitude/longitude facts
- Entity "User" (PERSON) with a LIVES_IN relation to Montigny
- Fact: address = "9 rue la Paix"

But in a **new conversation**, asking "Où est-ce que j'habite?" the agent asks for GPS coordinates instead of answering from KG.

## Root Cause Analysis

The KG pre-query already exists (`agent_loop.dart:91-106`) — it runs `knowledgeService.queryRelevant(userMessage)` before each LLM call. The problem is in `_buildFtsQuery()` and the query pipeline itself.

### Bug 1: Tokenization mismatch (punctuation stripping)

**`_buildFtsQuery()`** (`knowledge_service.dart:342-351`) strips ALL punctuation with `RegExp(r'[^\w\s]')`:
- `"j'habite"` → `"jhabite"` (apostrophe merges words)
- `"Montigny-le-Bretonneux"` → `"MontignyleBretonneux"` (hyphens merge words)

But **FTS5 `unicode61` tokenizer** treats hyphens and apostrophes as word separators:
- `"Montigny-le-Bretonneux"` is indexed as tokens: `montigny`, `le`, `bretonneux`
- `"j'habite"` would be indexed as: `j`, `habite`

So `_buildFtsQuery("j'habite")` produces `"jhabite"` which doesn't match `"habite"` in the index.

### Bug 2: No fact search in queryRelevant

`queryRelevant()` only calls `db.searchEntities()` — it never calls `db.searchFacts()`. The `facts_fts` table IS defined in the schema with `searchFacts` named query, but it's unused during retrieval. So even if the query matched on fact values like `"rue la Paix"`, it wouldn't find them.

### Bug 3: Semantic gap — no query expansion

The query "Où est-ce que j'habite?" has ZERO token overlap with stored data:
- Query tokens (after fix): `où`, `est`, `ce`, `que`, `habite` (all French stopwords + verb)
- Stored entity names: `Montigny`, `Bretonneux`, `User`
- Stored fact values: `rue`, `la Paix`, `48.77`, `2.04`

FTS5 is a **lexical** search engine. It cannot understand that "habite" (live) is semantically related to a LIVES_IN relation or an address fact.

## Solution: LLM-based Query Expansion

Since the app already makes LLM API calls and doesn't have local embeddings, the most effective approach is to use the LLM itself to expand the user's query into search-friendly keywords before running FTS5. This is a well-known technique (sometimes called "HyDE" or "query rewriting").

### Approach

1. **Fix `_buildFtsQuery()` tokenization** — align with `unicode61` tokenizer behavior
2. **Add `searchFacts` to `queryRelevant`** — merge fact-based entity discovery into the candidate pool
3. **Add LLM query expansion** — before FTS5, ask the LLM (fast, cheap call) to produce search keywords
4. **Add French/multilingual stopword filtering** — remove noise tokens

## Implementation Steps

### Step 1: Fix `_buildFtsQuery()` tokenization

**File**: `lib/core/knowledge/services/knowledge_service.dart`

Replace the punctuation-stripping regex with one that mimics `unicode61` tokenizer behavior (split on non-alphanumeric, keeping individual words):

```dart
static String _buildFtsQuery(String text) {
  // Split on any non-alphanumeric character (matching unicode61 tokenizer behavior)
  final tokens = text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.length > 1)
      .where((t) => !_stopwords.contains(t))
      .toSet()  // deduplicate
      .toList();
  if (tokens.isEmpty) return '';
  return tokens.map((t) => '"$t"').join(' OR ');
}

static const _stopwords = <String>{
  // French
  'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une',
  'et', 'ou', 'est', 'ce', 'que', 'qui', 'ne', 'pas',
  'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils', 'elles',
  'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'son', 'sa', 'ses',
  'en', 'au', 'aux', 'se', 'si', 'sur', 'par', 'pour', 'dans',
  'avec', 'sans', 'mais',
  // English
  'the', 'is', 'at', 'in', 'on', 'to', 'of', 'and', 'or',
  'it', 'he', 'she', 'we', 'my', 'do', 'an', 'am', 'be',
  'this', 'that', 'was', 'are', 'has', 'had', 'have',
  'what', 'where', 'when', 'how', 'who', 'which',
};
```

This fixes: `"j'habite"` → tokens `["habite"]`, `"Montigny-le-Bretonneux"` → tokens `["montigny", "bretonneux"]`.

### Step 2: Add fact search to `queryRelevant`

**File**: `lib/core/knowledge/services/knowledge_service.dart`

After the entity FTS search, also search `facts_fts` and merge discovered entity IDs into the candidate pool:

```dart
// After entity FTS search, also search facts
final factResults = await db.searchFacts(ftsQuery, limit * 3).get();
for (final f in factResults) {
  // Add the owning entity to candidates with a synthetic BM25 score
  if (!bm25Scores.containsKey(f.entityId)) {
    bm25Scores[f.entityId] = f.rank;
  } else {
    // Boost: entity matched on BOTH name and facts
    bm25Scores[f.entityId] = bm25Scores[f.entityId]! + f.rank;
  }
}
```

This fixes: searching for "rue la Paix" now finds the entity that owns that fact.

### Step 3: Add LLM query expansion

**File**: `lib/core/knowledge/services/knowledge_service.dart`

Add a method that uses the LLM to expand a user query into search keywords. This is called from `agent_loop.dart` before the KG pre-query:

```dart
/// Expand a user query into search-friendly keywords using the LLM.
/// Returns the original query + expanded keywords concatenated.
static Future<String> expandQuery(
  String userQuery,
  LLMProvider provider,
  String model,
) async {
  final response = await provider.chat(
    messages: [
      Message(
        role: 'system',
        content: 'You are a search query expander. Given a user question, '
            'output a short list of keywords that should be searched in a '
            'knowledge graph. Include entity names, relation types, fact keys, '
            'and synonyms. Output ONLY the keywords, space-separated, no explanation.',
      ),
      Message(role: 'user', content: userQuery),
    ],
    tools: [],
    model: model,
  );
  return '$userQuery ${response.content}'.trim();
}
```

**File**: `lib/core/agent/agent_loop.dart`

Before the pre-query, expand the user message:

```dart
String kgQuery = userMessage;
if (knowledgeService != null) {
  try {
    kgQuery = await KnowledgeService.expandQuery(
      userMessage, provider, config.agent.model,
    );
  } catch (_) {}
  // ... then queryRelevant(kgQuery, limit: 10)
}
```

**Trade-off**: This adds one extra LLM call (~100 tokens) per user message. To minimize cost:
- Use the cheapest/fastest model (Haiku-class) if available
- Set `max_tokens: 50` to cap output
- Skip expansion if the query already contains entity-like tokens (proper nouns, numbers)

### Step 4: Increase `formatKnowledgeContext` budget (optional)

**File**: `lib/core/knowledge/models/ranked_result.dart`

Current `maxChars = 2000` may be too small if multiple entities are relevant. Consider raising to 4000.

## Implementation Order

- [x] Step 1: Fix `_buildFtsQuery()` tokenization + stopwords
- [x] Step 2: Add fact search to `queryRelevant`
- [ ] Step 3: Add LLM query expansion
- [ ] Step 4: Increase context budget (optional)
- [ ] Build & verify: `flutter analyze` + `flutter build apk`
- [ ] Test on device: new conversation, "Où est-ce que j'habite?" should retrieve KG data

## Key Files

| File | Action |
|------|--------|
| `lib/core/knowledge/services/knowledge_service.dart` | Fix tokenizer, add stopwords, add fact search, add query expansion |
| `lib/core/agent/agent_loop.dart` | Call query expansion before pre-query |
| `lib/core/knowledge/models/ranked_result.dart` | Optionally raise maxChars |

## Risk Assessment

- **Step 1-2**: Pure bug fixes, zero risk. Will immediately improve retrieval for queries that share any token with stored data.
- **Step 3**: Adds latency (one extra LLM call). Worth it for semantic queries. Can be gated behind a config flag if needed.
- **Step 4**: Minimal risk, just adjusts a budget constant.

## Why NOT Embeddings?

The architecture has a placeholder for vector similarity (Phase 4 comment in `queryRelevant`). Embeddings would be the best long-term solution, but:
- Requires an embedding model (API call per entity + per query, or a local model)
- Requires a vector store (sqlite-vss or similar)
- Much larger scope than this fix

The LLM query expansion approach gives 80% of the benefit for 10% of the work.
