---
title: "fix: Agent responds in wrong language despite locale selection"
type: fix
date: 2026-02-22
---

# fix: Agent responds in wrong language despite locale selection

## Overview

When the user selects English as the app locale, the LLM agent still responds in French. The locale propagation code is mechanically correct — `ContextBuilder` does emit `"Respond in English."` in the system prompt — but the instruction is too weak to reliably control the LLM's response language in practice.

## Problem Statement

Three compounding weaknesses make the language instruction unreliable:

### 1. Single weak instruction buried in system prompt

The language instruction is a single short sentence (`"Respond in English."`) placed at the end of the identity block (line 76 of `context_builder.dart`). After it comes: bootstrap files, skills summary, memory context, and tools listing — potentially thousands of tokens. LLMs weight recent context more heavily than instructions buried deep in a system prompt.

```
System prompt structure:
├─ Identity (with "Respond in English." at end)  ← line 76
├─ Bootstrap files (potentially large)
├─ Skills summary
├─ Memory context
└─ Tools listing
```

### 2. Conversation history momentum overrides instruction

When the user switches locale from French to English mid-session, the existing session still contains all prior French messages. The LLM sees:

```
[system: "...Respond in English."]
[user: "Quelle heure est-il ?"]
[assistant: "Il est 14h30."]
[user: "What's the weather?"]   ← new message after locale switch
```

The conversational inertia from French messages easily overrides a single instruction line.

### 3. Summarization is language-unaware

`agent_loop.dart:196-201` — the summarization prompt is always English and doesn't instruct the LLM to produce the summary in any specific language:

```dart
'Summarize the following conversation concisely, preserving key facts, decisions, and context.'
```

If the conversation was in French, the summary will be in French. That French summary then becomes persistent context for all future calls, reinforcing French responses even in new sessions.

## Fixes

### Fix 1: Strengthen and reposition the language instruction

**File**: `lib/core/agent/context_builder.dart`

Move the language instruction from the identity block to the **end of the entire system prompt**, where it has maximum influence. Make it more authoritative:

```dart
// In buildSystemPrompt(), after all sections:
buffer.writeln();
buffer.writeln('IMPORTANT: ${tr(locale).agentRespondInstructions}');
```

Remove it from `_buildIdentity()`.

- [ ] Remove `${tr(locale).agentRespondInstructions}` from `_buildIdentity()` (line 76)
- [ ] Append `IMPORTANT: ${tr(locale).agentRespondInstructions}` at the very end of `buildSystemPrompt()` (after tools listing, line 61)

### Fix 2: Update ARB instructions to be stronger

**Files**: `lib/l10n/app_en.arb`, `app_fr.arb`, `app_es.arb`, `app_de.arb`, `app_it.arb`

Make the instruction more explicit and authoritative. Currently it's a mild `"Respond in English."`. Change to include the explicit constraint that applies regardless of conversation history:

| Locale | Current | Proposed |
|--------|---------|----------|
| EN | `"Respond in English."` | `"Always respond in English, regardless of the language used in previous messages."` |
| FR | `"Réponds en français."` | `"Réponds toujours en français, quelle que soit la langue utilisée dans les messages précédents."` |
| ES | `"Respond in Spanish."` | `"Responde siempre en español, independientemente del idioma usado en los mensajes anteriores."` |
| DE | `"Respond in German."` | `"Antworte immer auf Deutsch, unabhängig von der Sprache in vorherigen Nachrichten."` |
| IT | `"Respond in Italian."` | `"Rispondi sempre in italiano, indipendentemente dalla lingua usata nei messaggi precedenti."` |

- [ ] Update `agentRespondInstructions` in all 5 ARB files
- [ ] Run `flutter gen-l10n`

### Fix 3: Make summarization locale-aware

**File**: `lib/core/agent/agent_loop.dart`

The summarization prompt (line 196-201) should instruct the LLM to produce the summary in the target language. The `AgentLoop` already has access to `config.resolvedLocale`.

```dart
final summaryLang = tr(config.resolvedLocale).agentSummarizeInstructions;
final response = await provider.chat(
  messages: [
    Message(
      role: 'system',
      content: 'Summarize the following conversation concisely, '
          'preserving key facts, decisions, and context. $summaryLang',
    ),
    Message(role: 'user', content: summaryContent),
  ],
  ...
);
```

New ARB key `agentSummarizeInstructions`:

| Locale | Value |
|--------|-------|
| EN | `"Write the summary in English."` |
| FR | `"Rédige le résumé en français."` |
| ES | `"Escribe el resumen en español."` |
| DE | `"Schreibe die Zusammenfassung auf Deutsch."` |
| IT | `"Scrivi il riassunto in italiano."` |

- [ ] Add `agentSummarizeInstructions` key to all 5 ARB files
- [ ] Run `flutter gen-l10n`
- [ ] Update `_summarize()` in `agent_loop.dart` to include the locale-aware instruction

## Files

| File | Change |
|------|--------|
| `lib/core/agent/context_builder.dart` | Move language instruction to end of system prompt, prefix with `IMPORTANT:` |
| `lib/core/agent/agent_loop.dart` | Add locale-aware instruction to summarization prompt |
| `lib/l10n/app_en.arb` | Strengthen `agentRespondInstructions`, add `agentSummarizeInstructions` |
| `lib/l10n/app_fr.arb` | Same |
| `lib/l10n/app_es.arb` | Same |
| `lib/l10n/app_de.arb` | Same |
| `lib/l10n/app_it.arb` | Same |

## Verification

1. `flutter gen-l10n` succeeds
2. `flutter analyze` passes with 0 issues
3. Build APK, install on device
4. Set locale to English, start a **new session**, send a message in French → agent should respond in English
5. Set locale to French, start a new session, send a message in English → agent should respond in French
6. Switch locale mid-session (FR → EN) → next response should be in English
7. Trigger summarization (20+ messages) → summary should be in the target language
8. Check `adb logcat` to verify the system prompt ends with `IMPORTANT: Always respond in English...`

## Out of Scope

- Clearing session history on locale switch (too destructive, user may want to keep conversation)
- Translating existing session messages (complex, low value)
- The `'system'` default locale resolving to French on French devices is **correct behavior** — the user explicitly has a locale selector to override it
