---
title: "Code review fixes: ProofEditor concurrency, chat security, and performance"
slug: proof-editor-code-review-security-and-robustness-fixes
category: security-issues
tags:
  - proof-editor
  - chat-ui
  - security
  - performance
  - concurrency
  - url-handling
  - pii-leak
date: 2026-03-13
last_updated: 2026-06-10
component:
  - lib/core/tools/proof_editor_tool.dart
  - lib/features/chat/message_bubble.dart
  - lib/providers/chat_provider.dart
severity: P2
symptom: "Multiple issues: missing 409 conflict handling on prepend/rewrite, unbounded tool result text in chat bubbles, unrestricted URL schemes in launchUrl, PII leaked in error logs, regex recompilation on every build, missing optimistic concurrency on rewrite"
root_cause: "Incomplete error handling for HTTP conflict responses, missing input sanitization on URL schemes and display length, eager regex compilation patterns, and absent concurrency guards on state-mutating API calls"
---

# Code Review Fixes: ProofEditor Concurrency, Chat Security, and Performance

After a multi-agent code review of ProofEditorTool and chat bubble URL clickability features, 8 findings were identified (4 P2 Important, 4 P3 Nice-to-have) and all fixed in a single pass.

## Problem

The code review surfaced issues across three files spanning security, performance, and robustness:

- **Security**: `launchUrl` accepted any URI scheme (including `javascript:`, `intent://`), and HTTP error logs printed full `response.body` potentially containing PII or tokens
- **Performance**: URL linkification regex compiled on every call, and `linkifyUrls()` ran on every widget build frame
- **Robustness**: Prepend and rewrite operations lacked 409 conflict handling and optimistic concurrency, tool results displayed unbounded text in chat UI

## Solution

Eight code review findings were fixed across three source files and one test file.

### Security (P2)

#### P2-3: URL scheme restriction in message bubbles

`lib/features/chat/message_bubble.dart` — Tappable links in rendered Markdown were previously unconstrained. A static `_onTapLink` handler now gates `launchUrl` to `http` and `https` only:

```dart
static void _onTapLink(String text, String? href, String title) {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    launchUrl(uri);
  }
}
```

#### P2-4: Sanitize HTTP error logs

`lib/core/tools/proof_editor_tool.dart` — `_checkHttpError` previously logged `response.body`, which could contain document content or PII. The body is now omitted from print statements, logging only the status code and slug.

### Performance (P3)

#### P3-5: Cached linkified content

`lib/providers/chat_provider.dart` — `MessageBubble.linkifyUrls()` was called on every widget build. The result is now memoized as a `late final` field on `ChatMessage`:

```dart
late final String linkifiedContent = MessageBubble.linkifyUrls(content);
```

#### P3-6: Static regex compilation

`lib/features/chat/message_bubble.dart` — The bare-URL regex moved to `static final` on the class, compiled once:

```dart
static final _bareUrlPattern = RegExp(r'(?<!\]\()https?://[^\s\)<>\]]+');
```

#### P2-2: Tool result truncation

`lib/features/chat/message_bubble.dart` — Large tool results capped at 300 characters before rendering:

```dart
static const _toolResultMaxChars = 300;

final displayContent = message.content.length > _toolResultMaxChars
    ? '${message.content.substring(0, _toolResultMaxChars)}...'
    : message.content;
```

### Robustness (P2/P3)

#### P2-1: Prepend 409 conflict handling

`lib/core/tools/proof_editor_tool.dart` — Added 409 check after the rewrite POST in `_prepend`:

```dart
if (response.statusCode == 409) {
  return ToolResult.error(
      'Prepend conflict — document was modified. '
      'Re-read the document and try again.');
}
```

#### P3-8: Rewrite concurrency (optimistic locking)

`lib/core/tools/proof_editor_tool.dart` — Rewrite now fetches document state before writing, sending `baseRevision` or `baseToken`:

```dart
final stateResponse = await _getWithRetry(client,
    Uri.parse('$_baseUrl/api/agent/${doc.slug}/state'),
    headers: _bearerHeaders(doc.token));
int? revision;
String? updatedAt;
if (stateResponse.statusCode >= 200 && stateResponse.statusCode < 300) {
  final stateData = jsonDecode(stateResponse.body) as Map<String, dynamic>;
  revision = stateData['revision'] as int?;
  updatedAt = stateData['updatedAt'] as String?;
}
// rewriteBody includes baseRevision or baseToken
if (response.statusCode == 409) {
  return ToolResult.error('Rewrite conflict — document was modified. '
      'Re-read the document and try again.');
}
```

> **Correction (2026-06-10):** the live public agent contract accepts ONLY `baseToken` (`state.contract.supportedPreconditions == ["baseToken"]`, schema `mt1:...` from `state.mutationBase.token`); `baseRevision` is rejected by the server. The snippet above reflects the original fix, not the current code — see `lib/core/tools/proof_editor/proof_editor_client.dart` and [proof-editor-api-drift-basetoken-and-removed-edit-route](../integration-issues/proof-editor-api-drift-basetoken-and-removed-edit-route.md).

#### P3-7: fetchBaseUpdatedAt doc comment

Added clarifying comment that `_fetchBaseUpdatedAt` is scoped to the `/edit` endpoint only (not `/ops`).

> **Note (2026-06-10):** the `/edit` route was since removed server-side (404 "Unsupported agent route"); the edit/insert operations that used it are deprecated. See [proof-editor-api-drift-basetoken-and-removed-edit-route](../integration-issues/proof-editor-api-drift-basetoken-and-removed-edit-route.md).

### Test update

`test/proof_editor_tool_test.dart` — The rewrite test was updated to mock GET `/state` before POST `/ops`, matching the new concurrency flow. All 67 unit tests pass.

## Prevention

### API & Concurrency

- **All mutating API calls must handle 409 Conflict.** Any endpoint that writes server-side state must check for 409 and return an actionable error.
- **Optimistic concurrency is mandatory for read-modify-write operations.** Use a version token, ETag, or revision ID. Document the mechanism in the tool's class-level doc comment.

### Security

- **Allowlist URL schemes before launching.** Only permit `https`, `http`, `mailto`, `tel`. Reject `javascript`, `intent`, `file`, and unknown schemes.
- **Never log HTTP response bodies at INFO level or above.** Log only status code, URL path, and content-length. Gate body logging behind debug-level checks.

### Performance — Build Methods

- **Never compile `RegExp` inside a function that runs per-call or per-build.** Declare as `static final`.
- **Never run text transformation inside `build()`.** Cache in state layer or use `late final` getters.

### Pre-merge checklist additions

- [ ] Mutating HTTP calls handle 409 and conflict responses
- [ ] Read-modify-write flows use optimistic concurrency
- [ ] No raw URL launching — restricted to http/https
- [ ] No response bodies in persisted logs
- [ ] No `RegExp()` allocations inside `build()` or hot paths
- [ ] Tool result display is length-bounded

## Related Documentation

- `docs/plans/2026-03-12-feat-proofeditor-collaborative-document-tool-plan.md` — ProofEditor v1 architecture (token sanitization, 409 handling, async mutex)
- `docs/plans/2026-03-13-feat-proofeditor-missing-apis-plan.md` — ProofEditor v2 operations (suggest, append, insert, edit_v2 with idempotency)
- `docs/plans/2026-03-13-fix-clickable-urls-in-chat-bubbles-plan.md` — URL linkification plan
- `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md` — Atomic writes pattern

## Files Changed

- `lib/core/tools/proof_editor_tool.dart` — P2-1, P2-4, P3-7, P3-8
- `lib/features/chat/message_bubble.dart` — P2-2, P2-3, P3-6
- `lib/providers/chat_provider.dart` — P3-5
- `test/proof_editor_tool_test.dart` — P3-8 test update

> **Note (2026-06-10):** the HTTP transport (including the 409/concurrency handling above) now lives in `lib/core/tools/proof_editor/proof_editor_client.dart`, extracted from `proof_editor_tool.dart`.
