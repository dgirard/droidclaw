---
title: ProofEditor server API drift silently broke all mutating operations
date: 2026-06-10
category: integration-issues
module: proof_editor
problem_type: integration_issue
component: tooling
symptoms:
  - "Integration test failed at step 3 (append) with HTTP 404 from POST /api/agent/{slug}/edit"
  - "Live /ops calls rejected with \"rewrite.apply only accepts baseToken on the public agent contract\""
  - "After any 404, the local document token was purged and the tool reported \"Document not found. It may have been deleted.\" for a healthy document"
root_cause: wrong_api
resolution_type: code_fix
severity: high
tags: [proof-editor, api-drift, basetoken, optimistic-concurrency, http-404, external-api]
---

# ProofEditor server API drift silently broke all mutating operations

## Problem

The proofeditor.ai server evolved its public agent contract without versioning: the v1 `POST /api/agent/{slug}/edit` route was removed entirely (404 "Unsupported agent route"), and `POST /api/agent/{slug}/ops` stopped accepting `baseRevision` as an optimistic-concurrency precondition — only `baseToken` (the `mt1:` schema from `state.mutationBase.token`) is accepted. Every mutating ProofEditor operation (rewrite, prepend, append, edit, insert) was broken in production while unit tests stayed green against mocks.

## Symptoms

- `test/proof_editor_integration_test.dart` (tagged `integration`, runs against the live API) failed at the append step with HTTP 404; steps 4–7 cascaded because the 404 evicted the doc from the local store.
- Probing `/ops` with `baseRevision` returned a structured rejection: `rewrite.apply only accepts baseToken on the public agent contract` — meaning the optimistic-concurrency precondition had been **silently ignored or rejected** for an unknown period.
- A 404 from the dead `/edit` route was classified by `_checkHttpError` as "document deleted", purging the access token of a perfectly healthy document.

## What Didn't Work

- **Trusting mock-based unit tests as API coverage.** The 80-test unit suite passed throughout because mocks encoded the old contract. Only the live integration test caught the drift — and it had been failing without anyone noticing, because it is excluded from the default gate (`flutter test --exclude-tags integration`).
- **Treating every 404 as document-deleted.** The token-purge-on-404 heuristic was correct for `GET /state` but wrong for removed routes: a 404 can mean "this endpoint no longer exists", not "this resource no longer exists".

## Solution

In `lib/core/tools/proof_editor/proof_editor_client.dart`:

1. **Precondition migration**: rewrite/prepend/append send `baseToken: state.mutationBase.token` (never `baseRevision`). The client doc comment records the contract: `supportedPreconditions == ["baseToken"]`.
2. **Append rerouted off the dead route**: append now uses the same verified flow as prepend — `GET /state` → local section splice → `POST /ops rewrite.apply` — instead of the removed `/edit` route. Section-not-found is detected locally before any write.
3. **404 reclassification for legacy routes**: `_legacyEdit` (still used by the deprecated `edit`/`insert` operations) intercepts 404 **before** `_checkHttpError` and returns a non-purging failure telling the LLM the operation is unsupported and to use `rewrite`, `append`, or `suggest`. The tool schema marks both operations DEPRECATED so the model is steered away.
4. **Live verification, not assumption**: each fix was probed against proofeditor.ai with a throwaway document before landing (Bearer-auth on `/ops` → 200; no auth → 403; integration test 7/7).

## Why This Works

The root cause was an unversioned external contract consumed through assumptions frozen in mocks. The fix re-derives the contract from the live server (probe calls), aligns the client with what the server actually accepts, and makes the one remaining dead-route path fail loudly and harmlessly instead of destroying local state.

## Prevention

- **Run the live integration test periodically** — it is the only drift detector: `flutter test --tags integration test/proof_editor_integration_test.dart`. A green unit suite says nothing about an external API.
- **Never purge local credentials/state on 404 without distinguishing "route gone" from "resource gone"** — check the response body (`Unsupported agent route`) or restrict purge to endpoints known to exist.
- **When an external API rejects a request, capture the structured error body** — the `supportedPreconditions` field in the rejection is what revealed the `baseToken`-only contract.
- Tests pin the new behavior: 404 on `/edit` → `isError`, alternatives named, token NOT purged (`test/proof_editor_tool_test.dart`, "Legacy /edit 404" group).

## Related Issues

- `docs/solutions/security-issues/proof-editor-code-review-security-and-robustness-fixes.md` — the client-side 409/concurrency hardening this drift partially invalidated (its P3-8 snippet still says `baseRevision` is acceptable; flagged for refresh).
