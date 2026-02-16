---
title: "feat: Add Google Gemini as LLM provider via API key"
type: feat
date: 2026-02-16
---

# Add Google Gemini as LLM provider via API key

## Overview

Add Google Gemini as a first-class LLM provider in DroidClaw. Gemini is not currently supported — only OpenRouter, Anthropic, OpenAI, and Groq are. The addition is trivial because Google provides an OpenAI-compatible endpoint (`https://generativelanguage.googleapis.com/v1beta/openai`) that speaks the same protocol as the existing `HttpProvider`.

**No new Dart files are needed.** The `HttpProvider` already handles Gemini traffic. It just needs to be registered as a named provider in 3-4 files.

## Problem Statement / Motivation

- Gemini offers a **generous free tier** (15 req/min on Gemini 2.0 Flash) — ideal for new users who want to try DroidClaw without paying
- Gemini 2.5 Pro/Flash are very capable models with native tool calling support
- PicoClaw Go supported Gemini via its generic provider — DroidClaw should do the same
- A user can already use Gemini via OpenRouter, but direct access avoids OpenRouter fees and simplifies onboarding

## Proposed Solution

Add `'gemini'` to existing provider lists and configure the API base + default model. The `HttpProvider` handles everything else (Bearer auth, OpenAI format, tool calling).

### Files to modify

| File | Change |
|---|---|
| `lib/core/providers/provider_factory.dart` | Add `'gemini'` to `_defaultApiBase` and `_defaultModel` |
| `lib/features/onboarding/onboard_screen.dart` | Add the Gemini tuple to `_providers` |
| `lib/features/settings/provider_config_screen.dart` | Add `'gemini'` to `_providers` |
| `lib/shared/constants.dart` | Add `geminiApiBase` (optional, for consistency) |

### Detailed changes

#### `provider_factory.dart`

```dart
// _defaultApiBase switch — add:
'gemini' => 'https://generativelanguage.googleapis.com/v1beta/openai',

// _defaultModel switch — add:
'gemini' => 'gemini-2.0-flash',
```

The default model `gemini-2.0-flash` is the safest choice:
- Stable (GA, not preview)
- Fast and affordable
- Supports tool/function calling
- Free tier available

#### `onboard_screen.dart`

```dart
static const _providers = [
    ('openrouter', 'OpenRouter', 'Access many models with one API key'),
    ('anthropic', 'Anthropic', 'Direct access to Claude models'),
    ('openai', 'OpenAI', 'Access to GPT models'),
    ('groq', 'Groq', 'Fast inference for open models'),
    ('gemini', 'Google Gemini', 'Google AI models with free tier'),
  ];
```

#### `provider_config_screen.dart`

```dart
static const _providers = ['openrouter', 'anthropic', 'openai', 'groq', 'gemini'];
```

#### `constants.dart` (optional)

```dart
static const String geminiApiBase = 'https://generativelanguage.googleapis.com/v1beta/openai';
```

## Technical Considerations

### Confirmed compatibility

Gemini's OpenAI-compatible endpoint:
- Accepts `Authorization: Bearer <API_KEY>` (confirmed by Google docs)
- Supports `role: "system"` in messages
- Supports tool/function calling in OpenAI format (`tool_calls` with `function.name` and `function.arguments` as JSON string)
- Accepts `max_tokens` in the request body
- Returns `usage` with `prompt_tokens` / `completion_tokens` (OpenAI format)

### Points to watch

1. **Free tier rate limiting**: Gemini free tier = 15 req/min on Flash. A conversation with many tool calls can hit this limit. The 429 error will be shown as "LLM call failed: API error 429". No automatic retry — this is a future enhancement that would benefit all providers.

2. **Safety filters**: Gemini may block responses for safety reasons. The `finish_reason` would be `"content_filter"`. The current code treats this as a normal stop — the response will be empty or partial. Acceptable for v1.

3. **ToolCall parsing**: `ToolCall.fromJson` in `llm_response.dart` already handles both formats (OpenAI `function.arguments` as string, and Anthropic `input` as map). Gemini via the compatible endpoint should return the OpenAI format, but the parser is resilient for both cases.

4. **`max_tokens` vs `max_completion_tokens`**: The compatible endpoint should accept `max_tokens`. To be verified during testing. If there's an issue, it's a one-line fix in `http_provider.dart`.

### Out of scope

- Retry/backoff on 429 (future enhancement, all providers)
- Safety filter block detection (future enhancement)
- Human-readable names in the settings dropdown (pre-existing, all providers)
- Dynamic model picker per provider (future feature)

## Acceptance Criteria

- [x] Gemini appears in onboarding (5th provider)
- [x] Gemini appears in the Settings > Provider Config dropdown
- [x] `flutter analyze` passes without errors
- [ ] Test connection with a Gemini API key succeeds
- [ ] Simple chat (no tools) works with Gemini
- [ ] Chat with tool calling (web_search) works with Gemini
- [x] Default model is `gemini-2.0-flash` (not `gpt-4o`)

## Files to Create/Modify

| File | Change |
|---|---|
| `lib/core/providers/provider_factory.dart` | Add `'gemini'` to `_defaultApiBase` + `_defaultModel` switches |
| `lib/features/onboarding/onboard_screen.dart` | Add Gemini tuple to `_providers` list |
| `lib/features/settings/provider_config_screen.dart` | Add `'gemini'` to `_providers` list |
| `lib/shared/constants.dart` | Add `geminiApiBase` constant |

## References

### Internal References
- Provider factory: `lib/core/providers/provider_factory.dart:49-61`
- HttpProvider (handles all non-Anthropic): `lib/core/providers/http_provider.dart`
- ToolCall dual-format parser: `lib/core/providers/llm_response.dart:78-104`
- Onboarding providers list: `lib/features/onboarding/onboard_screen.dart:27-32`
- Settings providers list: `lib/features/settings/provider_config_screen.dart:28`

### External References
- Gemini OpenAI-compatible endpoint: https://ai.google.dev/gemini-api/docs/openai
- Gemini models list: https://ai.google.dev/gemini-api/docs/models
- Gemini free tier limits: https://ai.google.dev/pricing
