---
title: "feat: Add missing ProofEditor.ai API operations"
type: feat
date: 2026-03-13
---

# feat: Add missing ProofEditor.ai API operations

## Overview

Add 6 new operations to the `proof_editor` tool to cover the remaining ProofEditor.ai API surface: `suggest`, `append`, `insert`, `rename`, `snapshot`, and `edit_v2`. These complement the existing 7 operations (create, read, edit, rewrite, comment, list, delete) and enable richer collaborative workflows — suggestions with human approval, block-level editing, section-aware content insertion, and document renaming.

## Problem Statement / Motivation

The current proof_editor tool implements the core CRUD operations but misses several ProofEditor.ai capabilities:

- **No suggestion workflow** — the LLM can only apply edits directly. There's no way to propose changes the user can accept/reject in the ProofEditor UI.
- **No section-aware insertion** — the LLM must rewrite whole sections instead of appending to or inserting within them.
- **No document renaming** — titles are frozen at creation time.
- **No block-level editing** — text-level search/replace is fragile when the same text appears multiple times. Block refs from snapshot provide unambiguous targeting.

## Proposed Solution

Add 6 new operations to `proof_editor_tool.dart`, following the existing operation dispatch pattern (switch expression, per-operation validation, shared HTTP helpers).

### New Operations

#### 1. `suggest` — Propose an edit for user review

- **Endpoint**: `POST /api/agent/<slug>/ops` (same as comment/rewrite)
- **Auth**: Query-param token + `X-Agent-Id` (matching `_comment` pattern)
- **Body**: `{type: "suggestion.add", kind: "replace", quote, content, by: "ai:droidclaw"}`
- **Parameters**: `quote` (text to replace), `content` (replacement text)
- **Use case**: "Suggest rewording this paragraph" — user sees suggestion in ProofEditor UI and can accept/reject

#### 2. `append` — Add content to end of a section

- **Endpoint**: `POST /api/agent/<slug>/edit` (same as existing `edit`)
- **Auth**: Bearer token (matching `_edit` pattern)
- **Body**: `{by: "ai:droidclaw", operations: [{op: "append", section: "...", content: "..."}]}`
- **Parameters**: `content` (required), `section` (optional — markdown heading text, e.g. "## Methods"; omit to append to document end)
- **Use case**: "Add this point to the conclusion"

#### 3. `insert` — Insert content after anchor text

- **Endpoint**: `POST /api/agent/<slug>/edit` (same as existing `edit`)
- **Auth**: Bearer token (matching `_edit` pattern)
- **Body**: `{by: "ai:droidclaw", operations: [{op: "insert", target: {anchor: "..."}, content: "..."}]}`
- **Parameters**: `content` (required), `quote` (required — reuse existing param as anchor text)
- **Use case**: "Insert a new paragraph after the introduction"

#### 4. `rename` — Update document title

- **Endpoint**: `PUT /api/documents/<slug>/title`
- **Auth**: Bearer token
- **Body**: `{title: "..."}`
- **Parameters**: `title` (required)
- **Side effect**: Updates `ProofDocumentStore` title on success via `store.save(doc.copyWith(title: newTitle))`
- **Use case**: "Rename this doc to 'Q1 Report'"

#### 5. `snapshot` — Read document as ordered blocks with stable refs

- **Endpoint**: `GET /api/agent/<slug>/snapshot`
- **Auth**: Bearer token
- **Response contains**: Ordered blocks with stable refs (`b1`, `b2`...) and `mutationBase.token` (version identifier — safe for forLLM, NOT a credential)
- **forLLM format**:
  ```
  Document: "Title" (slug: xxx)
  mutationBase: <token>
  ---
  [b1] # Introduction
  [b2] First paragraph text...
  [b3] ## Methods
  [b4] Methods paragraph...
  ```
- **Truncation**: Same `_maxContentLength` (15K chars) as `_read`
- **Use case**: "Show me the document structure" or preparatory step before `edit_v2`

#### 6. `edit_v2` — Block-level edits using stable refs

- **Endpoint**: `POST /api/agent/<slug>/edit/v2`
- **Auth**: Bearer token
- **Headers**: `Idempotency-Key: <uuid>` (generated per invocation)
- **Body**: `{baseToken: "...", operations: [{op: "replace_block", ref: "b3", content: "..."}, {op: "insert_after", ref: "b2", blocks: [{content: "..."}]}]}`
- **Parameters**: `base_token` (required — from prior snapshot), `operations` (required — JSON array)
- **Error handling**: 409 with stale baseToken → "Document changed since snapshot. Use operation 'snapshot' to get current state."
- **Use case**: Multi-block batch edits with precise targeting

## Technical Approach

### Files to modify

Only **1 file** needs changes (plus ARB files for i18n):

| File | Changes |
|------|---------|
| `lib/core/tools/proof_editor_tool.dart` | Add 6 operations, update enum/switch/description/schema, add `_putJson` helper |
| `lib/l10n/app_{en,fr,es,de,it}.arb` | Add `proofDocRenamed` key (1 new key) |
| `lib/l10n/generated/app_localizations*.dart` | Regenerated |

No changes needed to: `app_providers.dart`, `service_agent_factory.dart`, `tools_config_screen.dart`, `app_config.dart`, `context_builder.dart`, `proof_document_store.dart`.

### Implementation details

#### JSON Schema additions (`parameters` getter)

New properties to add:
- `section`: `{type: 'string', description: 'Markdown heading text to target (for append; omit to append to document end)'}`
- `base_token`: `{type: 'string', description: 'Mutation base token from a prior snapshot (required for edit_v2)'}`
- `operations`: `{type: 'array', description: 'Block-level operations array (for edit_v2). Each item: {op: "replace_block", ref: "bN", content: "..."} or {op: "insert_after", ref: "bN", blocks: [{content: "..."}]}'}`

Existing properties to update:
- `quote` description: add "for suggest, insert" alongside "for comment"
- `content` description: add "suggest, append, insert" alongside "create, rewrite"
- `operation` enum: add `'suggest', 'append', 'insert', 'rename', 'snapshot', 'edit_v2'`

#### HTTP helpers

Add `_putJson` helper (same pattern as `_postJson` but with `client.put`):

```dart
Future<http.Response> _putJson(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  required Map<String, dynamic> body,
}) async {
  return client.put(
    uri,
    headers: {'Content-Type': 'application/json', ...?headers},
    body: jsonEncode(body),
  );
}
```

For `edit_v2`, generate idempotency key per invocation (no `uuid` package needed):

```dart
String _idempotencyKey() =>
    DateTime.now().microsecondsSinceEpoch.toString();
```

#### Auth patterns per operation

| Operation | Endpoint | Auth | Pattern follows |
|-----------|----------|------|-----------------|
| `suggest` | `/api/agent/<slug>/ops` | Query-param `?token=` + `X-Agent-Id` | `_comment` |
| `append` | `/api/agent/<slug>/edit` | Bearer + `X-Agent-Id` | `_edit` |
| `insert` | `/api/agent/<slug>/edit` | Bearer + `X-Agent-Id` | `_edit` |
| `rename` | `/api/documents/<slug>/title` | Bearer + `X-Agent-Id` | `_read` (new endpoint) |
| `snapshot` | `/api/agent/<slug>/snapshot` | Bearer + `X-Agent-Id` | `_read` |
| `edit_v2` | `/api/agent/<slug>/edit/v2` | Bearer + `X-Agent-Id` + `Idempotency-Key` | New |

#### Error handling additions

- `suggest`, `insert`: 409 + `ANCHOR_NOT_FOUND` → "Text not found in document. Re-read the document to see current content." (reuse existing edit 409 pattern)
- `append`: 409 + section not found → "Section not found. Re-read the document to see sections."
- `edit_v2`: 409 + stale base → "Document changed since snapshot. Use operation 'snapshot' to get current state."
- `rename`: Standard `_checkHttpError` (401/403/404/429/5xx)

#### i18n

- Reuse `proofActionApplied` ("Changes applied") for: suggest, append, insert, edit_v2
- Add `proofDocRenamed` with `{title}` placeholder: "Title updated: {title}" / "Titre mis à jour : {title}" / etc.
- Snapshot `forUser`: reuse plain text preview (first 500 chars), same as `_read`

#### Tool description update

```dart
'Collaborative document editor via ProofEditor.ai. '
'Create, read, edit, suggest changes, comment on, and manage shared markdown documents. '
'Use "snapshot" + "edit_v2" for precise block-level edits. '
'Use "suggest" to propose changes the user can accept/reject. '
'Documents persist across sessions and are accessible via shareable URLs.'
```

### Implementation order

Update schema, description, and switch first so the tool compiles at every step:

- [x] 1. Update `parameters` getter: add 6 values to `operation` enum, add new properties (`section`, `base_token`, `operations`), update `quote`/`content` descriptions
- [x] 2. Update `description` getter to mention new capabilities
- [x] 3. Add `_putJson` helper method
- [x] 4. Add `_suggest` + switch case (follows `_comment` pattern)
- [x] 5. Add `_append` + switch case (follows `_edit` pattern)
- [x] 6. Add `_insert` + switch case (follows `_edit` pattern)
- [x] 7. Add `_rename` + switch case (PUT, updates local store title)
- [x] 8. Add `_snapshot` + switch case (GET with block-ref formatting + truncation)
- [x] 9. Add `_editV2` + switch case (POST with idempotency key + baseToken)
- [x] 10. Update default error message to list all 13 operations
- [x] 11. Add `proofDocRenamed` to all 5 ARB files + regenerate
- [x] 12. Run `flutter analyze` — must pass with 0 errors

## Acceptance Criteria

### Functional
- [ ] `suggest`: Creates a suggestion visible in ProofEditor UI that user can accept/reject
- [ ] `append`: Adds content to end of specified section (or document if no section)
- [ ] `insert`: Inserts content after anchor text
- [ ] `rename`: Updates title in ProofEditor AND local store
- [ ] `snapshot`: Returns block-ref formatted view with mutationBase token
- [ ] `edit_v2`: Applies block-level edits with idempotency key
- [ ] All 6 operations appear in `operation` enum and work end-to-end
- [ ] Existing 7 operations remain unchanged and functional

### Non-Functional
- [ ] Tokens never in `forLLM` or error messages (share tokens — baseToken IS allowed)
- [ ] All errors go through `_checkHttpError` or operation-specific 409 handling
- [ ] Snapshot truncated at `_maxContentLength`
- [ ] `proofDocRenamed` localized in all 5 locales
- [ ] `flutter analyze` passes with 0 errors
- [ ] Service isolate compatible (all pure HTTP)

## Dependencies & Risks

- **ProofEditor API availability**: All endpoints are documented at proofeditor.ai/agent-docs. If any endpoint behaves differently than documented (auth scheme, error codes), may need runtime adjustment.
- **No new dependencies**: Uses existing `http` package. No `uuid` package needed (timestamp-based idempotency key).
- **Backward compatible**: Only adds operations, no breaking changes.

## References

- ProofEditor API docs: https://www.proofeditor.ai/agent-docs
- Existing tool: `lib/core/tools/proof_editor_tool.dart`
- Existing store: `lib/core/tools/proof_document_store.dart`
- Plan for v1: `docs/plans/2026-03-12-feat-proofeditor-collaborative-document-tool-plan.md`
