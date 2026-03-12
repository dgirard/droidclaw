---
title: "feat: Add ProofEditor.ai Collaborative Document Tool"
type: feat
date: 2026-03-12
---

# feat: Add ProofEditor.ai Collaborative Document Tool

## Enhancement Summary

**Deepened on:** 2026-03-12
**Sections enhanced:** 9
**Research agents used:** architecture-strategist, agent-native-reviewer, code-simplicity-reviewer, security-sentinel, performance-oracle, pattern-recognition-specialist, agent-native-architecture-skill, learnings-researcher, best-practices-researcher

### Key Improvements from Deep Research
1. **Reduced scope from 11 to 7 operations** — cut append, insert, suggest, events, rename (YAGNI for v1)
2. **Renamed `action` to `operation`** — matches CalendarTool/FileTool/DirectionsTool codebase convention
3. **Added `delete` operation** — CRUD completeness (unregister document from local store)
4. **Added ContextBuilder integration** — inject active document list into system prompt (survives summarization)
5. **Atomic file writes** — write-to-tmp + rename pattern from AppLogger (cross-isolate safety)
6. **Async mutex** — protect read-modify-write within a single isolate
7. **Token sanitization** — never expose tokens in error messages, use Uri.parse() instead of regex
8. **Slug validation** — strict allowlist regex prevents SSRF via path manipulation
9. **Store JSON file outside workspace** — prevents token leakage via `file` tool side channel
10. **Removed presence system** — YAGNI; DroidClaw is typically sole editor in v1
11. **Richer write outputs** — return excerpt around edit point so agent can verify without re-reading
12. **Shorter tool description** — 2-3 sentences instead of 12 lines (JSON Schema carries the detail)
13. **Consolidated i18n keys** — 5 keys instead of 10 (generic `proofActionApplied`)
14. **Fixed `workspacePathProvider` reference** — uses actual `storageServiceProvider` pattern

### New Risks Discovered
- Token leakage via `file` tool reading `proof_documents.json` from workspace (mitigated: store in Hive directory)
- Token in LLM tool call arguments when URL is passed (inherent; mitigated by schema design with no `token` param)
- HTTP exception messages containing tokens in URLs (mitigated: sanitize all error outputs)
- Slug loss after summarization (mitigated: ContextBuilder injection)

---

## Overview

Add a `proof_editor` tool to DroidClaw that integrates with [ProofEditor.ai](https://proofeditor.ai) — a collaborative markdown editor for agents and humans. This enables the agent to create, read, edit, comment, and suggest changes on shared documents, enabling a collaborative writing workflow between the user and DroidClaw.

**Example workflows:**
- "Write me a LinkedIn post about X" → agent creates a Proof document, writes the content, returns the shareable URL
- "Read my Proof document" → agent fetches and displays the current content
- "Change this sentence in the doc" → agent edits specific content
- "Add a comment on paragraph 2" → agent adds a comment via track changes
- "Suggest replacing X with Y" → agent creates a suggestion the user can accept/reject

## Problem Statement / Motivation

DroidClaw currently has no way to produce long-form, collaboratively editable documents. Chat messages are ephemeral — the user can't iterate on a draft, share it externally, or maintain a persistent document alongside the conversation. ProofEditor.ai solves this by providing:

- **Shared editing**: agent and human see the same document in real-time
- **Provenance**: every character is attributed to who wrote it (agent vs human)
- **Track changes**: suggestions, comments, accept/reject workflow
- **No login required**: documents are created via API, shared via URL + token
- **Free**: no API key or account needed

## Proposed Solution

A single `proof_editor` tool with operation-based dispatch, following the existing tool patterns (CalendarTool, FileTool, DirectionsTool). Since ProofEditor uses per-document share tokens (not a global API key), the architecture differs slightly from API-key-based tools.

### Architecture Summary

```
proof_editor tool (operation-based dispatch)
├── create   → POST /share/markdown
├── read     → GET /api/agent/<slug>/state
├── edit     → POST /api/agent/<slug>/edit (v1, simple)
├── rewrite  → POST /api/agent/<slug>/ops (rewrite.apply)
├── comment  → POST /api/agent/<slug>/ops (comment.add)
├── list     → read local document registry
└── delete   → remove from local document registry
```

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Single vs multiple tools** | Single `proof_editor` with `operation` param | Matches CalendarTool/FileTool pattern; 7 operations is comparable to CalendarTool (3) and DirectionsTool (2) |
| **Parameter name** | `operation` (not `action`) | Every multi-operation tool in the codebase uses `operation` (CalendarTool, ContactsTool, FileTool, DirectionsTool) |
| **v1 scope** | 7 operations (create, read, edit, rewrite, comment, list, delete) | Cuts 4 YAGNI operations: append/insert (redundant with edit/rewrite), suggest (no reviewer in v1), events (no collaborators in v1), rename (doable in web UI) |
| **Edit API version** | v1 (`/edit`) for simplicity | DroidClaw is typically the sole editor; v2 adds complexity for little benefit in v1 |
| **Token storage** | JSON file in **Hive directory** (NOT workspace) | Prevents token leakage via `file` tool side channel; Hive dir is not exposed to any tool |
| **Tokens in forLLM** | Never — lookup by slug internally | Security: tokens are auth credentials, must not leak to LLM provider |
| **Document disambiguation** | By slug; if omitted, use most recent | Explicit slug preferred; fallback to last-used avoids LLM confusion |
| **Large doc truncation** | 15K chars (matching web_scrape) | Prevents context window exhaustion |
| **Disabled by default** | Yes | External service dependency, opt-in |
| **Service isolate** | Compatible (pure HTTP) | Enables cron-based document workflows |
| **Presence** | Deferred to v2 | YAGNI — DroidClaw is sole editor in v1; adds 2 extra HTTP calls per write for nobody to see |
| **i18n** | Localized status messages in forUser | Follows WeatherTool/DateTimeTool pattern |
| **ContextBuilder** | Inject active docs into system prompt | Survives summarization; agent always knows which documents exist |

### Research Insights: Architecture

**From architecture-strategist:**
- The 11-action design was flagged as 3x the surface area of the largest existing tool. Reducing to 7 operations keeps it within reasonable bounds.
- SharedPreferences was suggested as alternative to JSON file, but JSON file in Hive directory is cleaner for unbounded document count.
- ContextBuilder injection is the single most important addition: without it, the agent loses document awareness after summarization (20+ messages).

**From agent-native-reviewer:**
- The `delete` operation was identified as a critical gap — every CRUD system needs the D.
- The tool description should be 2-3 sentences (not 12 lines) — JSON Schema already carries parameter docs.
- Consider adding `ack_events` in v2 to prevent event re-reporting.

**From code-simplicity-reviewer:**
- `append`, `insert`, `suggest`, `events`, `rename` are all YAGNI for v1.
- Presence adds 2 HTTP calls per write for a feature nobody watches. Remove for v1.
- STALE_BASE auto-retry is over-engineering. Return error, let agent loop handle naturally.

---

## Technical Approach

### Phase 1: Document Storage Layer

A lightweight JSON registry for document metadata and tokens, with atomic writes and async mutex for dual-isolate safety.

**New file**: `lib/core/tools/proof_document_store.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProofDocument {
  final String slug;
  final String token;
  final String title;
  final String shareUrl;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

  ProofDocument({
    required this.slug,
    required this.token,
    required this.title,
    required this.shareUrl,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  // Manual fromJson/toJson (no codegen)
  factory ProofDocument.fromJson(Map<String, dynamic> json) => ProofDocument(
    slug: json['slug'] as String,
    token: json['token'] as String,
    title: json['title'] as String? ?? '',
    shareUrl: json['shareUrl'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    lastAccessedAt: DateTime.tryParse(json['lastAccessedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'token': token,
    'title': title,
    'shareUrl': shareUrl,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
  };

  ProofDocument copyWith({DateTime? lastAccessedAt}) => ProofDocument(
    slug: slug,
    token: token,
    title: title,
    shareUrl: shareUrl,
    createdAt: createdAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
}

class ProofDocumentStore {
  final String _filePath;
  Completer<void>? _mutex;

  ProofDocumentStore(this._filePath);

  /// Async mutex to prevent interleaved read-modify-write within one isolate.
  Future<T> _protect<T>(Future<T> Function() fn) async {
    while (_mutex != null) {
      await _mutex!.future;
    }
    _mutex = Completer<void>();
    try {
      return await fn();
    } finally {
      final lock = _mutex!;
      _mutex = null;
      lock.complete();
    }
  }

  Future<List<ProofDocument>> loadAll() async {
    final file = File(_filePath);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list.map((e) => ProofDocument.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Corrupted file — log and return empty (defensive)
      print('[ProofDocStore] Failed to parse: $e');
      return [];
    }
  }

  /// Atomic write: write to .tmp then rename (safe across isolates).
  Future<void> _writeDocs(List<ProofDocument> docs) async {
    final json = jsonEncode(docs.map((d) => d.toJson()).toList());
    final tmpFile = File('$_filePath.tmp');
    await tmpFile.writeAsString(json, flush: true);
    await tmpFile.rename(_filePath);
  }

  Future<void> save(ProofDocument doc) => _protect(() async {
    final docs = await loadAll();
    final idx = docs.indexWhere((d) => d.slug == doc.slug);
    if (idx >= 0) {
      docs[idx] = doc;
    } else {
      docs.add(doc);
    }
    await _writeDocs(docs);
  });

  Future<ProofDocument?> getBySlug(String slug) async {
    final docs = await loadAll();
    try {
      return docs.firstWhere((d) => d.slug == slug);
    } catch (_) {
      return null;
    }
  }

  Future<ProofDocument?> getMostRecent() async {
    final docs = await loadAll();
    if (docs.isEmpty) return null;
    docs.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return docs.first;
  }

  Future<void> remove(String slug) => _protect(() async {
    final docs = await loadAll();
    docs.removeWhere((d) => d.slug == slug);
    await _writeDocs(docs);
  });

  Future<void> updateLastAccessed(String slug) => _protect(() async {
    final docs = await loadAll();
    final idx = docs.indexWhere((d) => d.slug == slug);
    if (idx >= 0) {
      docs[idx] = docs[idx].copyWith(lastAccessedAt: DateTime.now());
      await _writeDocs(docs);
    }
  });
}
```

**Storage location**: `<hivePath>/proof_documents.json` — in the Hive directory (NOT the workspace), so the `file` tool cannot read it. Accessible from both isolates since both know the Hive directory path.

### Research Insights: Storage

**From security-sentinel (Finding 7):**
> The `file` tool allows the LLM to read any file in the workspace via `read_file`. If the tool calls `file` with `path: "proof_documents.json"`, the entire contents including all tokens would be returned. Store the JSON file outside the workspace directory.

**From learnings-researcher (Learning #3: cron-sessions-hive-path-mismatch):**
> The workspace path is the same from both isolates (after the bug fix). But `getApplicationDocumentsDirectory()` already returns the `app_flutter` dir — never nest it again. Use the Hive path directly.

**From best-practices-researcher:**
> Use write-to-temp-then-rename (atomic on POSIX/Android). `File.rename()` is atomic on the same filesystem. Always `flush: true` before rename. This matches the `AppLogger.purge()` pattern already in the codebase.

**From performance-oracle:**
> Add an in-memory cache to avoid full JSON parse on every invocation. However, for v1 with < 50 documents, the overhead is negligible (~1ms). Add caching in v2 if needed.

### Phase 2: Core Tool Implementation

**New file**: `lib/core/tools/proof_editor_tool.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tool.dart';
import 'proof_document_store.dart';
import '../../l10n/generated/app_localizations.dart';

class ProofEditorTool extends Tool {
  final ProofDocumentStore store;
  final String locale;
  static const _baseUrl = 'https://www.proofeditor.ai';
  static const _slugPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  static const _maxContentLength = 15000;

  ProofEditorTool({required this.store, this.locale = 'en'});

  @override String get name => 'proof_editor';

  @override String get description =>
      'Collaborative document editor via ProofEditor.ai. '
      'Create, read, edit, comment on, and manage shared markdown documents. '
      'Documents persist across sessions and are accessible via shareable URLs. '
      'Use operation "list" to see known documents, "create" to start a new one.';

  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'operation': {
        'type': 'string',
        'enum': ['create', 'read', 'edit', 'rewrite', 'comment', 'list', 'delete'],
        'description': 'The operation to perform on a Proof document',
      },
      'slug': {
        'type': 'string',
        'description': 'Document slug. If omitted for read/edit, uses most recently accessed document.',
      },
      'title': {
        'type': 'string',
        'description': 'Document title (for create)',
      },
      'content': {
        'type': 'string',
        'description': 'Markdown content (for create, rewrite)',
      },
      'search': {
        'type': 'string',
        'description': 'Text to find in document (for edit)',
      },
      'replace': {
        'type': 'string',
        'description': 'Replacement text (for edit)',
      },
      'quote': {
        'type': 'string',
        'description': 'Text to anchor comment on (for comment)',
      },
      'text': {
        'type': 'string',
        'description': 'Comment body (for comment)',
      },
      'url': {
        'type': 'string',
        'description': 'ProofEditor URL to import (registers document from shared URL)',
      },
    },
    'required': ['operation'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) return ToolResult.error('Missing required parameter: operation');

    try {
      return switch (operation) {
        'create'  => await _create(arguments),
        'read'    => await _read(arguments),
        'edit'    => await _edit(arguments),
        'rewrite' => await _rewrite(arguments),
        'comment' => await _comment(arguments),
        'list'    => await _list(),
        'delete'  => await _delete(arguments),
        _         => ToolResult.error('Unknown operation: $operation'),
      };
    } catch (e) {
      // SECURITY: Never expose raw exception (may contain tokens in URLs)
      return ToolResult.error('ProofEditor operation failed. Check network connection.');
    }
  }

  /// Validate slug format to prevent path traversal / SSRF.
  String? _validateSlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    if (!_slugPattern.hasMatch(slug)) return null;
    return slug;
  }

  /// Resolve document: by slug, by URL import, or most recent.
  Future<ProofDocument?> _resolveDocument(Map<String, dynamic> args) async {
    // URL import takes priority
    final url = args['url'] as String?;
    if (url != null && url.isNotEmpty) {
      final doc = _importFromUrl(url);
      if (doc != null) {
        await store.save(doc);
        return doc;
      }
    }

    final slug = _validateSlug(args['slug'] as String?);
    if (slug != null) {
      final doc = await store.getBySlug(slug);
      if (doc != null) {
        await store.updateLastAccessed(slug);
        return doc;
      }
      return null; // slug provided but not found
    }

    return await store.getMostRecent(); // fallback
  }

  /// Parse ProofEditor URL safely using Uri.parse (not regex).
  ProofDocument? _importFromUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      // Validate host
      if (uri.host != 'proofeditor.ai' && uri.host != 'www.proofeditor.ai') {
        return null;
      }
      // Extract slug from path segments (e.g., /d/<slug> or /share/<slug>)
      final segments = uri.pathSegments;
      if (segments.length < 2) return null;
      final slug = segments[1];
      if (!_slugPattern.hasMatch(slug)) return null;

      final token = uri.queryParameters['token'];
      if (token == null || token.isEmpty) return null;

      return ProofDocument(
        slug: slug,
        token: token,
        title: '',
        shareUrl: rawUrl.split('?').first, // Strip token from stored URL
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  // ... operation methods (_create, _read, _edit, _rewrite, _comment, _list, _delete)
  // Each follows the pattern:
  // 1. Validate required parameters → ToolResult.error() if missing
  // 2. Resolve document (if needed)
  // 3. HTTP call with sanitized error handling
  // 4. Return ToolResult.dual(forLLM: ..., forUser: ...)
}
```

### Research Insights: Tool Design

**From pattern-recognition-specialist (Critical Fix):**
> Every multi-operation tool in the codebase uses `operation`, not `action`. CalendarTool, ContactsTool, FileTool, DirectionsTool all use `operation`. Rename to `operation` for pattern consistency.

**From agent-native-reviewer:**
> The tool description should be 2-3 sentences. The LLM already gets the JSON Schema with per-parameter descriptions — it doesn't need the action list duplicated in the description string. Existing tools (weather, calendar, get_directions) use short descriptions.

**From security-sentinel (Finding 3, P0):**
> NEVER use `ToolResult.error('HTTP error: $e')` where `$e` might contain the URL with token. The `/ops` endpoint uses `?token=<token>` in the URL. If the Dart `http` package exception includes the request URL, the token leaks. Always catch exceptions and return sanitized messages.

**From security-sentinel (Finding 4-5, P0):**
> Use `Uri.parse()` instead of regex for URL parsing. Validate host is `proofeditor.ai` or `www.proofeditor.ai`. Validate slug matches `^[a-zA-Z0-9_-]+$` to prevent SSRF via slug injection like `../../admin`.

**From agent-native-architecture skill:**
> After write operations, return an excerpt of surrounding context (~200 chars around the edit point) in `forLLM`. This lets the agent verify without a separate `read` call, reducing round-trips.

### Phase 3: API Client Methods

Inside `ProofEditorTool.execute()`, operation-based dispatch:

#### Create Document
```
POST https://www.proofeditor.ai/share/markdown
Body: {"title": "...", "markdown": "..."}
→ Response: {slug, accessToken, shareUrl, tokenUrl, _links}
→ Save to ProofDocumentStore
→ forUser: localized "Document created: [title](shareUrl)"
→ forLLM: "Document created. Slug: <slug>, URL: <shareUrl>. Use slug '<slug>' for subsequent operations."
```

**Required params**: `title`, `content`. Returns error if missing.

#### Read Document
```
GET https://www.proofeditor.ai/api/agent/<slug>/state
Headers: Authorization: Bearer <token>, X-Agent-Id: droidclaw
→ Parse markdown content + marks (comments/suggestions)
→ Truncate at 15K chars if needed
→ forUser: first 500 chars preview + "[Read full doc at URL]"
→ forLLM: "Document: <title> (slug: <slug>)\nURL: <shareUrl>\n---\n<content>" + comment summaries
```

**Research insight (performance-oracle):** For `read`, return full content (expected). For `edit`/`rewrite`/`comment` responses, return only a confirmation + the changed region (200 chars of context). Saves ~4,000 tokens per edit cycle.

#### Edit (Replace)
```
POST https://www.proofeditor.ai/api/agent/<slug>/edit
Headers: Authorization: Bearer <token>, X-Agent-Id: droidclaw
Body: {
  "by": "ai:droidclaw",
  "operations": [{"op": "replace", "search": "old text", "content": "new text"}]
}
→ Handle 409 ANCHOR_NOT_FOUND → return error "Text not found. Re-read the document."
→ forUser: localized "Edit applied"
→ forLLM: "Edit applied in document <slug>: replaced '<old>' with '<new>'. Context: '...<surrounding 200 chars>...'"
```

**Required params**: `search`, `replace`. Returns error if missing.

**Research insight (architecture-strategist):** Add per-operation parameter validation in `execute()` that returns clear `ToolResult.error()` messages when required params are missing for a given operation (e.g., "edit operation requires 'search' and 'replace' parameters").

#### Rewrite
```
POST /api/agent/<slug>/ops?token=<token>
Headers: X-Agent-Id: droidclaw
Body: {"type": "rewrite.apply", "by": "ai:droidclaw", "content": "# Full new markdown..."}
```

**Required params**: `content`. Returns error if missing.

#### Comment
```
POST /api/agent/<slug>/ops?token=<token>
Headers: X-Agent-Id: droidclaw
Body: {"type": "comment.add", "by": "ai:droidclaw", "quote": "text", "text": "comment"}
```

**Required params**: `quote`, `text`. Returns error if missing.

#### List
```
Read ProofDocumentStore → return all stored documents with title, slug, URL, last accessed
```

No params required. Returns empty list message if no documents.

#### Delete
```
Remove document from local ProofDocumentStore by slug.
→ forUser: localized "Document removed from list"
→ forLLM: "Document <slug> removed from local registry. The document still exists at <shareUrl>."
```

**Required params**: `slug`. Returns error if missing.

### Research Insights: HTTP Client

**From best-practices-researcher:**
> Use a scoped `http.Client` per `execute()` call to reuse TCP/TLS connections across multiple HTTP calls within a single invocation. Create in try block, close in finally:
> ```dart
> final client = http.Client();
> try {
>   // all HTTP calls use client.get() / client.post()
> } finally {
>   client.close();
> }
> ```

**From best-practices-researcher (retry pattern):**
> Follow the `BaseCloudEmbeddingProvider` inline retry loop (2 retries, 500ms * 2^attempt) for 429 and 5xx errors. Do NOT retry 401/403/404.

**From architecture-strategist:**
> The tool uses three different auth mechanisms across endpoints:
> - `Authorization: Bearer <token>` header (for `/state`, `/edit`)
> - `?token=<token>` query param (for `/ops`)
> - No auth (for `/share/markdown`)
>
> Centralize this in a private `_request()` helper that takes an auth mode enum rather than spreading token handling across 7 operation methods.

### Phase 4: URL Import

When the LLM receives a ProofEditor URL from the user, it should call the tool with `operation: "read"` and `url: "https://www.proofeditor.ai/d/<slug>?token=<token>"`. The tool:

1. Parses slug and token using `Uri.parse()` (NOT regex — security)
2. Validates host is `proofeditor.ai` or `www.proofeditor.ai`
3. Validates slug matches `^[a-zA-Z0-9_-]+$`
4. Saves the document to `ProofDocumentStore`
5. Reads the document state
6. Returns the content (forLLM never includes the raw URL with token)

### Research Insights: URL Import Security

**From security-sentinel (Finding 4):**
> The original regex `/d/([^/?]+)\?.*token=([^&]+)` has issues: no host validation (SSRF risk), no slug sanitization (path traversal), fragment-based bypass. Use `Uri.parse()` + `pathSegments` + `queryParameters` — Dart's built-in parser handles all edge cases.

**From security-sentinel (Findings 1-2):**
> When the LLM passes a `url` parameter containing `?token=<token>`, that URL with token is stored in Hive session as part of the `ToolCall` arguments. This is inherent — the LLM decides tool call arguments. The mitigation is: (1) no `token` parameter in the schema (only `url`), (2) `forLLM` for URL import says "Imported document <slug>" — never echoes the raw URL, (3) the tool description instructs the LLM to use slugs for subsequent operations.

### Phase 5: ContextBuilder Integration (NEW — Critical)

**New modification**: `lib/core/agent/context_builder.dart`

Add a section to the system prompt that lists active ProofEditor documents, so the agent retains document awareness after summarization.

```dart
// In ContextBuilder.buildSystemPrompt(), after the tools listing:
if (proofDocumentStore != null) {
  final docs = await proofDocumentStore!.loadAll();
  if (docs.isNotEmpty) {
    buffer.writeln('\n## Active ProofEditor Documents');
    for (final doc in docs) {
      final age = DateTime.now().difference(doc.lastAccessedAt);
      final ageStr = age.inHours < 1 ? '${age.inMinutes}m ago'
                   : age.inDays < 1 ? '${age.inHours}h ago'
                   : '${age.inDays}d ago';
      buffer.writeln('- "${doc.title}" (slug: ${doc.slug}, last edited: $ageStr)');
    }
    buffer.writeln('Use proof_editor with the slug to read or edit these documents.');
  }
}
```

### Research Insights: ContextBuilder

**From architecture-strategist (Must Fix):**
> Summarization drops early messages. After 20+ messages, the slug from a `create` response is lost. Without ContextBuilder injection, the agent literally cannot reference documents. This is the single most important addition to the plan.

**From agent-native-reviewer (Critical):**
> This is the plan's biggest agent-native gap. `ContextBuilder` already injects workspace files, knowledge graph context, etc. Adding 2-3 lines per document is lightweight and high-value.

**From agent-native-architecture skill:**
> "System prompt includes what exists (files, data, types)." Inject available capabilities at runtime. This is a core agent-native principle.

### Phase 6: Error Handling

| HTTP Status | Meaning | Tool Response |
|---|---|---|
| 401/403 | Token invalid/expired | `ToolResult.error("Document access denied. The share token may be invalid or expired. Ask the user for a new URL.")` + remove from store |
| 404 | Document not found | `ToolResult.error("Document not found. It may have been deleted.")` + remove from store |
| 409 ANCHOR_NOT_FOUND | Search text not found in doc | `ToolResult.error("Text not found in document. Re-read the document to see current content.")` |
| 409 STALE_BASE | Concurrent edit conflict | `ToolResult.error("Document was modified by another editor. Re-read and try again.")` (no auto-retry in v1) |
| 429 | Rate limited | Retry with backoff (500ms * 2^attempt, max 2 retries). If still 429: `ToolResult.error(...)` |
| 5xx | Server error | Retry with backoff (same pattern). If still 5xx: `ToolResult.error("ProofEditor service is temporarily unavailable.")` |
| Network error | Timeout/connectivity | `ToolResult.error("Could not reach ProofEditor. Check internet connection.")` |

### Research Insights: Error Handling

**From security-sentinel (P0):**
> NEVER pass `e.toString()` to `ToolResult.error()` when the request URL contained a token. The `/ops` endpoint uses `?token=<token>` in the URL. Use generic messages:
> ```dart
> } catch (e) {
>   // SECURITY: e.toString() may contain URL with token
>   return ToolResult.error('ProofEditor request failed');
> }
> ```

**From code-simplicity-reviewer:**
> STALE_BASE auto-retry (re-read + rebuild operation + retry) is over-engineering for v1. Just return an error. The agent loop will naturally re-read and retry on the next turn.

**From best-practices-researcher:**
> Follow the `BaseCloudEmbeddingProvider` retry pattern: 2 retries, 500ms * 2^attempt, only on 429/5xx. Never retry 401/403/404.

### Phase 7: Registration & Settings

Follow the standard tool registration pattern:

#### Files to modify:

1. **`lib/core/tools/proof_document_store.dart`** (new) — Document registry with atomic writes + async mutex
2. **`lib/core/tools/proof_editor_tool.dart`** (new) — Tool implementation with 7 operations
3. **`lib/core/agent/context_builder.dart`** — Inject active documents into system prompt
4. **`lib/providers/app_providers.dart`** — Register tool in `toolRegistryProvider`
   ```dart
   // No API key needed — ProofEditor uses per-document tokens
   if (!disabled.contains('proof_editor')) {
     final storage = ref.watch(storageServiceProvider);
     final hivePath = await storage.hivePath; // NOT workspacePath — token security
     final proofStore = ProofDocumentStore('$hivePath/proof_documents.json');
     registry.register(ProofEditorTool(store: proofStore, locale: config.resolvedLocale));
   }
   ```

   **Note**: The original plan used `ref.watch(workspacePathProvider)` which does NOT exist. The actual pattern is `ref.watch(storageServiceProvider)` + `await storage.workspacePath` (line 145 of `app_providers.dart`). For this tool, we use `hivePath` instead to keep tokens out of the workspace.

5. **`lib/features/settings/tools_config_screen.dart`** — Add toggle
   ```dart
   _ToolInfo(
     name: 'proof_editor',
     label: l.toolProofEditor,
     description: l.toolProofEditorDesc,
     icon: Icons.edit_document,
   ),
   ```
6. **`lib/core/config/app_config.dart`** — Add to `_defaultDisabledTools`
7. **`lib/core/agent/service_agent_factory.dart`** — Register for service isolate (pure HTTP, compatible)
   ```dart
   if (!disabled.contains('proof_editor')) {
     final proofStore = ProofDocumentStore('$hivePath/proof_documents.json');
     registry.register(ProofEditorTool(store: proofStore, locale: locale));
   }
   ```
8. **`lib/l10n/app_en.arb`** + `app_fr.arb` + `app_es.arb` + `app_de.arb` + `app_it.arb` — Add i18n keys:
   - `toolProofEditor`: "Proof Editor" / "Editeur Proof" / "Editor Proof" / "Proof-Editor" / "Editor Proof"
   - `toolProofEditorDesc`: "Create and edit collaborative documents"
   - `proofDocCreated`: "Document created"
   - `proofDocNotFound`: "Document not found"
   - `proofActionApplied`: "Done" (generic confirmation for edit/rewrite/comment/delete)
   - `proofDocTruncated`: "Document truncated ({length} chars shown of {total})"

#### Files NOT modified (no global API key needed):
- `lib/core/config/config_storage.dart` — No global API key
- `lib/shared/constants.dart` — No cached key constant
- `lib/providers/background_service_provider.dart` — No `_cacheSecretsForService()` entry
- `lib/core/services/background_task_handler.dart` — No key to pass through
- No new settings screen — No configuration beyond the tool toggle

### Research Insights: Registration

**From pattern-recognition-specialist:**
> The `workspacePathProvider` reference in the original plan would cause a compile error. The actual pattern is `ref.watch(storageServiceProvider)` + `await storage.workspacePath` (line 145 of `app_providers.dart`).

**From learnings-researcher (Learning #2: enable-location-tools):**
> The tool is pure HTTP — register it in service isolate without hesitation. Checklist: No UI? No platform channels? Pure HTTP? No permissions? → Service-safe.

**From learnings-researcher (Learning #4: i18n-with-dual-isolate):**
> Locale via constructor is the correct pattern. `ToolResult.forLLM` stays English, `forUser` is localized. Service isolate receives locale via SharedPreferences (already cached). ARB keys in all 5 locale files.

---

## Acceptance Criteria

### Functional Requirements

- [x] `proof_editor` tool registered and available in tool registry
- [x] **Create**: `operation: "create"` creates a document on ProofEditor.ai and returns the shareable URL
- [x] **Read**: `operation: "read"` fetches document content from ProofEditor.ai and returns it
- [x] **Edit**: `operation: "edit"` replaces text in a document using search/replace
- [x] **Rewrite**: `operation: "rewrite"` replaces full document content
- [x] **Comment**: `operation: "comment"` adds a comment anchored to a text quote
- [x] **List**: `operation: "list"` shows all stored documents
- [x] **Delete**: `operation: "delete"` removes document from local registry
- [x] **URL import**: Tool parses ProofEditor URLs and registers slug+token (via `url` param)
- [x] **Persistence**: Document registry survives app restart (JSON file in Hive directory)
- [x] **Dual ToolResult**: forLLM has full data (never tokens), forUser has clean localized summaries
- [x] **ContextBuilder**: Active documents injected into system prompt (survives summarization)
- [x] **Per-operation validation**: Clear error messages for missing required parameters

### Non-Functional Requirements

- [x] Disabled by default in `_defaultDisabledTools`
- [x] Tool toggle in settings screen
- [x] Service isolate compatible (registered in `ServiceAgentFactory`)
- [x] i18n: status messages localized in all 5 locales (EN/FR/ES/DE/IT)
- [x] Large documents truncated at 15K chars
- [x] Error handling for all HTTP error codes (401, 403, 404, 409, 429, 5xx)
- [x] Tokens never appear in `forLLM` content
- [x] Tokens never appear in error messages (sanitized exceptions)
- [x] JSON file stored in Hive directory (not workspace — prevents `file` tool leakage)
- [x] Slug validation: `^[a-zA-Z0-9_-]+$` (prevents SSRF)
- [x] URL parsing via `Uri.parse()` with host validation (not regex)
- [x] Atomic file writes (write-to-tmp + rename)
- [x] Async mutex for within-isolate concurrent access
- [x] Retry with backoff for 429/5xx (2 retries, 500ms * 2^attempt)
- [x] `flutter analyze` passes with 0 issues

### Quality Gates

- [ ] All 7 operations manually tested via chat
- [ ] URL import tested with real ProofEditor URL
- [ ] Document created in DroidClaw visible and editable in ProofEditor web UI
- [ ] Comment added by DroidClaw visible in ProofEditor web UI
- [ ] Service isolate: cron can create/edit a Proof document
- [ ] Summarization test: create doc, chat 20+ messages, verify agent can still reference it via ContextBuilder
- [ ] Security test: verify tokens do not appear in any forLLM output or error messages
- [ ] Security test: verify `file` tool cannot read `proof_documents.json`

---

## Implementation Phases

### Phase 1: Foundation (ProofDocumentStore + create + read + list + delete)
- `proof_document_store.dart` — JSON file read/write with atomic writes + async mutex
- `proof_editor_tool.dart` — skeleton with create, read, list, delete operations
- `context_builder.dart` — inject active documents into system prompt
- Register in `app_providers.dart` (with `hivePath`, not workspace)
- Add toggle in `tools_config_screen.dart`
- Add to `_defaultDisabledTools`
- i18n: add 6 ARB keys to all 5 locale files
- Test: create a document, read it back, list it, delete it

### Phase 2: Editing (edit + rewrite)
- Implement edit (search/replace) and rewrite operations
- Error handling for 409 ANCHOR_NOT_FOUND
- Retry logic for 429/5xx with backoff
- Test: full edit cycle (read → edit → read to verify)

### Phase 3: Collaboration + Service Isolate (comment + service isolate + URL import)
- Implement comment operation
- URL parsing and document import (with Uri.parse + host/slug validation)
- Register in `service_agent_factory.dart`
- Test: add comment visible in ProofEditor UI
- Test: cron can create/edit a Proof document
- Update README tools table

### Phase 4 (v2 — Future): Extended Operations
Deferred operations, to be added based on user feedback:
- `append`: Add content to a section (`POST /edit` with `op: append`)
- `insert`: Insert after anchor text (`POST /edit` with `op: insert`)
- `suggest`: Add suggestion via track changes (`POST /ops` with `suggestion.add`)
- `rename`: Update title (`PUT /documents/<slug>/title`)
- `events`: Poll for pending events (`GET /events/pending`)
- `ack_events`: Acknowledge events (`POST /events/ack`)
- Presence updates on write operations
- `/edit/v2` with revision locking for concurrent editing

---

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ProofEditor API changes | Low | High | Pin to known API surface, handle unknown errors gracefully |
| ProofEditor downtime (502 errors) | Medium | Medium | Retry with backoff for transient errors, graceful error messages |
| Token expiry (undocumented) | Unknown | Medium | Handle 401/403 by removing stale entries, prompt user for new URL |
| Token leakage in error messages | Medium | High | **Sanitize all exceptions** — never pass `$e` to ToolResult when URL contained token |
| Token leakage via `file` tool | Low | High | **Store JSON in Hive dir** (not workspace) — file tool is sandboxed to workspace only |
| Slug loss after summarization | High | High | **ContextBuilder injection** — active docs in system prompt survive summarization |
| Large documents exhaust context | Low | High | 15K char truncation; write responses return only 200-char context excerpt |
| SSRF via slug injection | Low | Medium | **Slug validation** — `^[a-zA-Z0-9_-]+$` allowlist |
| Concurrent file access (dual-isolate) | Low | Medium | **Atomic writes** (write-to-tmp + rename) + **async mutex** (within-isolate) |
| Workspace file corruption | Low | Medium | Validate JSON on load, fallback to empty list |

## Future Considerations

- **v2 edit API**: Switch to `/edit/v2` with revision locking for concurrent editing support
- **Extended operations**: append, insert, suggest, rename, events, ack_events (see Phase 4)
- **Presence**: Show "DroidClaw is editing" in ProofEditor UI on write operations
- **Cron-based event polling**: Monitor documents for new comments/suggestions, notify via Telegram
- **Block-level reads**: Use `/snapshot` to read specific sections of large documents
- **Document templates**: Pre-built templates for LinkedIn posts, blog articles, meeting notes
- **Telegram integration**: Share document URLs directly in Telegram conversations
- **Knowledge Graph integration**: Auto-store document metadata as KG entities for cross-session discovery
- **In-memory cache**: Add cache to ProofDocumentStore when document count exceeds 50
- **Accept/reject suggestions**: If ProofEditor API supports it, add agent-side accept/reject

## References & Research

### ProofEditor API Documentation
- Agent docs: https://www.proofeditor.ai/agent-docs
- Agent setup: https://www.proofeditor.ai/agent-setup
- Discovery: https://www.proofeditor.ai/.well-known/agent.json
- SDK: https://github.com/EveryInc/proof-sdk
- Skill file: https://www.proofeditor.ai/proof.SKILL.md

### Internal References
- Tool base class: `lib/core/tools/tool.dart`
- Reference HTTP tool: `lib/core/tools/directions_tool.dart` (API key + HTTP pattern)
- Reference no-key tool: `lib/core/tools/weather_tool.dart` (HTTP without API key)
- Reference action-dispatch: `lib/core/tools/calendar_tool.dart` (operation enum, switch expression)
- Reference atomic writes: `lib/core/services/app_logger.dart` (write-to-tmp + rename)
- Reference retry: `lib/core/providers/embedding_provider.dart` (BaseCloudEmbeddingProvider, 2 retries, 500ms * 2^n)
- Tool registration: `lib/providers/app_providers.dart`
- Service factory: `lib/core/agent/service_agent_factory.dart`
- Context builder: `lib/core/agent/context_builder.dart`
- Settings toggle: `lib/features/settings/tools_config_screen.dart`
- Disabled defaults: `lib/core/config/app_config.dart`

### Institutional Learnings Applied
- `docs/solutions/architecture/decouple-cron-from-telegram-autonomous-service.md` — Service isolate tool registration pattern
- `docs/solutions/architecture/enable-location-tools-in-service-isolate.md` — Pure HTTP → service-safe checklist
- `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md` — Cross-isolate file access, atomic writes
- `docs/solutions/architecture/implement-i18n-with-dual-isolate-support.md` — Locale via constructor, tr(), 5 ARB files

### ProofEditor API Endpoints Summary

| Endpoint | Method | Auth | Purpose | v1 Scope |
|---|---|---|---|---|
| `/share/markdown` | POST | None | Create document | Yes |
| `/api/agent/<slug>/state` | GET | Bearer token | Read document state + comments | Yes |
| `/api/agent/<slug>/edit` | POST | Bearer token | Simple edits (replace) | Yes |
| `/api/agent/<slug>/ops` | POST | Token (query param) | Comments, rewrites | Yes |
| `/api/agent/<slug>/snapshot` | GET | Bearer token | Block-focused view with refs | v2 |
| `/api/agent/<slug>/edit/v2` | POST | Bearer token + Idempotency-Key | Block-based edits with revision lock | v2 |
| `/api/documents/<slug>/title` | PUT | Bearer token | Update title | v2 |
| `/api/agent/<slug>/events/pending` | GET | Bearer token | Poll for events | v2 |
| `/api/agent/<slug>/events/ack` | POST | Bearer token | Acknowledge events | v2 |
| `/api/agent/<slug>/presence` | POST | None | Update agent presence | v2 |

### Research Agents Summary

| Agent | Key Finding |
|---|---|
| **architecture-strategist** | ContextBuilder injection is critical; fix `workspacePathProvider` reference; centralize auth in `_request()` helper |
| **agent-native-reviewer** | Add `delete` operation; shorten description; inject docs into system prompt |
| **code-simplicity-reviewer** | Cut to 6-7 operations; remove presence; remove auto-retry |
| **security-sentinel** | Store JSON outside workspace; sanitize error messages; validate slugs; use Uri.parse() |
| **performance-oracle** | Scoped http.Client; atomic writes; reduce forLLM payload for non-read operations |
| **pattern-recognition-specialist** | Rename `action` to `operation`; fix workspacePathProvider |
| **agent-native-architecture skill** | CRUD completeness (delete); richer write outputs; context injection |
| **learnings-researcher** | Atomic writes from AppLogger; 5 ARB files; service-isolate-safe (pure HTTP) |
| **best-practices-researcher** | Async mutex; retry pattern from BaseCloudEmbeddingProvider; write-to-tmp+rename |
