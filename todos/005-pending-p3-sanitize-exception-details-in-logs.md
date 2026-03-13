---
status: pending
priority: p3
issue_id: "005"
tags: [code-review, security, logging]
dependencies: []
---

# Sanitize Exception Details in Logs

## Problem Statement

The session manager logs exception details with `$e` which could include corrupted session JSON containing user conversation data. On-device logs are lower risk than server logs, but still worth sanitizing.

## Findings

- **security-sentinel**: Exception messages from JSON parse failures can contain fragments of corrupted session data (user messages, tool results). Recommend using `${e.runtimeType}` instead of `$e`.

## Proposed Solutions

### Option A: Log runtimeType only (Recommended)
```dart
AppLogger.instance.warning(LogSource.app,
    'Failed to load session $key: ${e.runtimeType}');
```
- **Pros**: No data leakage, still useful for debugging
- **Cons**: Less detail for troubleshooting
- **Effort**: Trivial
- **Risk**: None

### Option B: Truncate exception message
```dart
final msg = e.toString();
AppLogger.instance.warning(LogSource.app,
    'Failed to load session $key: ${msg.substring(0, min(50, msg.length))}');
```
- **Pros**: Some detail preserved
- **Cons**: 50 chars could still contain PII
- **Effort**: Small
- **Risk**: Low

## Technical Details

**Affected files:**
- `lib/core/session/session_manager.dart` — catch blocks in `init()` and `reload()`

## Acceptance Criteria

- [ ] Exception logs do not contain raw session/message content
- [ ] Logs still identify the type of error for debugging

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-03-13 | Created from code review | On-device logs still warrant data sanitization |
