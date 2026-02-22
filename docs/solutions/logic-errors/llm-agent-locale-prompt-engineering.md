---
title: "LLM Agent Ignoring Language Preference in System Prompt"
date: 2026-02-22
category: logic-errors
tags:
  - system-prompt
  - language-preference
  - context-ordering
  - summarization
  - llm-instruction-weight
  - internationalization
component: "Agent system prompt construction, i18n/locale system"
severity: high
symptoms:
  - "User selects English locale, but LLM agent responds in French"
  - "Language preference ignored despite correct locale configuration"
  - "Problem worsens over long conversations (summarization reinforces wrong language)"
root_cause_type:
  - instruction-placement
  - instruction-strength
  - localization-gap
---

# LLM Agent Ignoring Language Preference in System Prompt

## Problem

When the user selects English as the app locale, the LLM agent still responds in French. The locale propagation code is mechanically correct — `ContextBuilder` does emit `"Respond in English."` in the system prompt — but the instruction is too weak and poorly positioned to reliably control the LLM's response language.

## Root Cause Analysis

Three compounding weaknesses:

### 1. Language instruction buried in system prompt

The `agentRespondInstructions` string ("Respond in English.") was placed at line 76 of `_buildIdentity()` in `context_builder.dart` — early in the system prompt. After it came: bootstrap files, skills summary, memory context, and tools listing (potentially thousands of tokens).

LLMs exhibit **recency bias** — they weight end-of-prompt instructions more heavily than instructions buried deep under context.

```
System prompt structure (BEFORE):
├─ Identity (with "Respond in English." at end)  <- line 76
├─ Bootstrap files (potentially large)
├─ Skills summary
├─ Memory context
└─ Tools listing
```

### 2. Weak instruction text

The instruction "Respond in English." was a single mild sentence, easily overridden by conversation history momentum. When users switched locale mid-session, prior messages in the old language created inertia the LLM followed instead.

### 3. Summarization language-unaware

The `_summarize()` method in `agent_loop.dart` used a fixed English prompt with no language instruction:

```dart
'Summarize the following conversation concisely, preserving key facts, decisions, and context.'
```

If the conversation was in French, the summary would be produced in French. That French summary then became persistent context for all future calls, reinforcing French responses even after locale switch.

## Working Solution

### Fix 1: Reposition language instruction to end of system prompt

**File**: `lib/core/agent/context_builder.dart`

Removed from `_buildIdentity()`:
```dart
// BEFORE:
Be concise and helpful. Use markdown formatting in your responses.
${tr(locale).agentRespondInstructions}

// AFTER:
Be concise and helpful. Use markdown formatting in your responses.
```

Added at the very end of `buildSystemPrompt()`, after all sections:
```dart
// 6. Language instruction — positioned last for maximum LLM influence
buffer.writeln('IMPORTANT: ${tr(locale).agentRespondInstructions}');
```

New prompt structure:
```
System prompt structure (AFTER):
├─ Identity
├─ Bootstrap files
├─ Skills summary
├─ Memory context
├─ Tools listing
└─ IMPORTANT: Always respond in English, ...  <- LAST position
```

### Fix 2: Strengthen ARB language instructions

**Files**: All 5 ARB files in `lib/l10n/`

| Locale | Before | After |
|--------|--------|-------|
| EN | `"Respond in English."` | `"Always respond in English, regardless of the language used in previous messages."` |
| FR | `"Réponds en français."` | `"Réponds toujours en français, quelle que soit la langue utilisée dans les messages précédents."` |
| ES | `"Respond in Spanish."` | `"Responde siempre en español, independientemente del idioma usado en los mensajes anteriores."` |
| DE | `"Respond in German."` | `"Antworte immer auf Deutsch, unabhängig von der Sprache in vorherigen Nachrichten."` |
| IT | `"Respond in Italian."` | `"Rispondi sempre in italiano, indipendentemente dalla lingua usata nei messaggi precedenti."` |

The strengthened text uses imperative "always" and explicitly addresses conversation history override.

### Fix 3: Locale-aware summarization

**File**: `lib/core/agent/agent_loop.dart`

New ARB key `agentSummarizeInstructions` added to all 5 locales (EN: "Write the summary in English.", FR: "Rédige le résumé en français.", etc.).

```dart
// BEFORE:
const Message(
  role: 'system',
  content: 'Summarize the following conversation concisely, '
      'preserving key facts, decisions, and context.',
),

// AFTER:
final summaryLang = tr(config.resolvedLocale).agentSummarizeInstructions;
Message(
  role: 'system',
  content: 'Summarize the following conversation concisely, '
      'preserving key facts, decisions, and context. $summaryLang',
),
```

## Files Changed

| File | Change |
|------|--------|
| `lib/core/agent/context_builder.dart` | Move language instruction from `_buildIdentity()` to end of `buildSystemPrompt()` with `IMPORTANT:` prefix |
| `lib/core/agent/agent_loop.dart` | Add locale-aware instruction to `_summarize()` |
| `lib/l10n/app_en.arb` | Strengthen `agentRespondInstructions`, add `agentSummarizeInstructions` |
| `lib/l10n/app_fr.arb` | Same |
| `lib/l10n/app_es.arb` | Same |
| `lib/l10n/app_de.arb` | Same |
| `lib/l10n/app_it.arb` | Same |

## Verification

1. `flutter gen-l10n` succeeds
2. `flutter analyze` passes with 0 issues
3. Build APK, install on device
4. Set locale to English, start a new session, send a message in French — agent should respond in English
5. Set locale to French, start a new session, send a message in English — agent should respond in French
6. Switch locale mid-session (FR to EN) — next response should be in English
7. Trigger summarization (20+ messages) — summary should be in the target language
8. `adb logcat -s flutter` — system prompt ends with `IMPORTANT: Always respond in English...`

## Prevention Strategies

### Prompt instruction positioning
Critical instructions (language, format, guardrails) must appear at the **end** of the system prompt, after all context. LLM recency bias makes end-of-prompt instructions more influential than buried ones.

### Instruction strength
Use imperative, absolute language: "Always X, regardless of Y". Avoid passive ("Respond in X.") which is easily overridden by conversation momentum.

### Summarization as a locale boundary
Any prompt sent to the LLM (not just the main agent loop) must include locale instructions. Summarization, title generation, and any other LLM call that produces persistent text must be locale-aware.

### When adding new system prompt sections
New sections added to `ContextBuilder.buildSystemPrompt()` must be inserted **before** the language instruction at the end. The language enforcement must always remain the last thing in the prompt.

## Related Documentation

- [Implement i18n with dual-isolate support](../architecture/implement-i18n-with-dual-isolate-support.md) — Full i18n architecture
- [Fix plan: Agent response language not following locale](../../plans/2026-02-22-fix-agent-response-language-not-following-locale-plan.md) — Original plan for this fix
- [i18n French/English locales plan](../../plans/2026-02-22-feat-i18n-french-english-locales-plan.md) — Initial locale implementation
- [Add Spanish/German/Italian locales plan](../../plans/2026-02-22-feat-add-spanish-german-italian-locales-plan.md) — Multi-locale expansion
