---
title: "Gemini Flash Ignores System Prompt Language Instructions"
date: 2026-02-27
category: runtime-errors
tags:
  - gemini-flash
  - language-compliance
  - system-prompt
  - conversation-history-bias
  - user-message-tagging
  - internationalization
  - prompt-engineering
component: "AgentLoop, ContextBuilder, i18n ARB files"
severity: high
symptoms:
  - "Agent responds in English despite French locale being set"
  - "Language directive in system prompt ignored by Gemini 2.0 Flash"
  - "Problem worsens with longer conversation history in English"
  - "New sessions may work briefly but revert to English with history"
root_cause_type:
  - model-specific-behavior
  - conversation-pattern-following
  - instruction-weight
---

# Gemini Flash Ignores System Prompt Language Instructions

## Problem

With the app locale set to French (`locale=fr`), the LLM agent responds in English. The system prompt contains correct French language directives (`agentLanguageDirective`, `agentRespondInstructions`), and `ContextBuilder` emits the locale properly. Despite bilingual directives and structured markers (`=== LANGUAGE REQUIREMENT ===`), the agent consistently responds in English.

This is the **converse** of a prior bug ([LLM Agent Ignoring Language Preference in System Prompt](../logic-errors/llm-agent-locale-prompt-engineering.md)) where the agent responded in French when English was selected. That fix (instruction repositioning + strengthening) was necessary but insufficient for Gemini Flash.

## Investigation Steps

### Step 1: Verify locale propagation (confirmed correct)

- Screenshot showed agent responding in English with FR flag visible
- `AppConfig.resolvedLocale` returns `'fr'` when French is selected
- `contextBuilderProvider` passes `locale: config.resolvedLocale` correctly
- `tr('fr').agentLanguageDirective` returns the correct bilingual French directive
- Generated `app_localizations_fr.dart` confirmed correct output

### Step 2: Bilingual directives (insufficient alone)

Updated all 5 ARB files with bilingual directives (English + target language):

```
"RESPONSE LANGUAGE: FRENCH. You MUST always respond in French. Vous DEVEZ toujours repondre en francais."
```

Added structured `=== LANGUAGE REQUIREMENT ===` marker in context_builder.dart. Built, deployed, tested. **Still English.**

### Step 3: Debug logging reveals root cause

Added temporary debug print in `context_builder.dart`:

```dart
print('[ContextBuilder] locale=$locale, '
    'directive="${tr(locale).agentLanguageDirective.substring(0, 40)}..."');
```

Logcat output:
```
[ContextBuilder] locale=fr, directive="RESPONSE LANGUAGE: FRENCH. You MUST alwa..."
iter=0, msgs=13, model=gemini-2.0-flash
```

**Key findings:**
- `locale=fr` -- correct, locale propagation works
- `model=gemini-2.0-flash` -- small/fast model, weaker instruction following
- `msgs=13` -- 11 historical messages in English from previous turns

### Step 4: Identify the real root cause

Gemini 2.0 Flash prioritizes **conversation pattern continuation** over system prompt instructions. With 11+ English messages in the session history, the model follows the dominant language pattern regardless of what the system prompt says. Stronger models (Claude, GPT-4) handle this; Flash-class models do not.

## Root Cause

**Model-specific behavior**: Gemini 2.0 Flash (and likely other small/fast models) follows conversation history language patterns over system prompt language directives. When the session contains predominantly English messages, the model responds in English even with explicit French language instructions in the system prompt.

Three compounding factors:
1. **Conversation inertia**: English-dominant message history (11+ messages) creates overwhelming pattern
2. **System prompt distance**: Language directive in system prompt is far from the actual user message the model is answering
3. **Model capability**: Flash-class models have weaker instruction-following for "meta" instructions like language choice

## Working Solution

Three-layer language enforcement, where Layer 3 is the critical fix:

### Layer 1: Bilingual language directives in ARB files

**Files**: `lib/l10n/app_*.arb` (all 5 locales)

Both English AND target language in every directive, so the model sees the target language tokens:

| Locale | `agentLanguageDirective` |
|--------|--------------------------|
| EN | `RESPONSE LANGUAGE: ENGLISH. You MUST always respond in English.` |
| FR | `RESPONSE LANGUAGE: FRENCH. You MUST always respond in French. Vous DEVEZ toujours repondre en francais.` |
| ES | `RESPONSE LANGUAGE: SPANISH. You MUST always respond in Spanish. DEBES responder siempre en espanol.` |
| DE | `RESPONSE LANGUAGE: GERMAN. You MUST always respond in German. Du MUSST immer auf Deutsch antworten.` |
| IT | `RESPONSE LANGUAGE: ITALIAN. You MUST always respond in Italian. DEVI sempre rispondere in italiano.` |

Same bilingual pattern for `agentRespondInstructions`.

### Layer 2: Structured language section in system prompt

**File**: `lib/core/agent/context_builder.dart`

```dart
// 7. Language instruction -- positioned last for maximum LLM influence
buffer.writeln('=== LANGUAGE REQUIREMENT ===');
buffer.writeln(tr(locale).agentRespondInstructions);
```

The `=== LANGUAGE REQUIREMENT ===` marker creates a visually distinct section that models parse as high-priority.

### Layer 3: User message language tag (THE KEY FIX)

**File**: `lib/core/agent/agent_loop.dart`

Append a language hint **in the target language** to the last user message. This is applied to the LLM copy only -- not stored in the session.

```dart
// For non-English locales, tag the last user message with a language hint
// in the target language. This improves compliance with weaker models
// (e.g. Gemini Flash) that tend to follow conversation patterns over
// system instructions. The tag is on the copy, not the stored session.
if (resolvedLocale != 'en') {
  final hint = _languageHint(resolvedLocale);
  for (var i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role == 'user') {
      messages[i] = messages[i].copyWith(
        content: '${messages[i].content}\n\n[$hint]',
      );
      break;
    }
  }
}
```

```dart
/// Brief language hint in the target language.
/// Appended to the last user message to nudge weaker models.
static String _languageHint(String locale) => switch (locale) {
      'fr' => 'Reponds en francais',
      'es' => 'Responde en espanol',
      'de' => 'Antworte auf Deutsch',
      'it' => 'Rispondi in italiano',
      _ => 'Reply in English',
    };
```

**Why this works**: The hint appears immediately before the model generates its response (recency bias), uses the target language tokens (priming), and bypasses the conversation history pattern by being part of the user turn the model is directly answering.

**Why copy-only**: The tag is cosmetic for the LLM. Storing it in the session would pollute the conversation history and compound with each turn.

## Files Changed

| File | Change |
|------|--------|
| `lib/core/agent/agent_loop.dart` | Added `_languageHint()` method + message tagging logic in `processMessage()` |
| `lib/core/agent/context_builder.dart` | Added `=== LANGUAGE REQUIREMENT ===` structured marker |
| `lib/l10n/app_en.arb` | Bilingual `agentLanguageDirective` + `agentRespondInstructions` |
| `lib/l10n/app_fr.arb` | Same (French bilingual) |
| `lib/l10n/app_es.arb` | Same (Spanish bilingual) |
| `lib/l10n/app_de.arb` | Same (German bilingual) |
| `lib/l10n/app_it.arb` | Same (Italian bilingual) |

## Verification

All tests performed on physical device with `gemini-2.0-flash`:

| Test | Result |
|------|--------|
| New session (msgs=2), locale=FR, "ou est-ce que j'habite?" | French response |
| Old session with English history (msgs=15), locale=FR, "quelle heure?" | "Il est 17h47." (French) |
| After tool call (get_datetime), locale=FR | French response |
| locale=EN, new session | English response (unchanged) |

## Prevention Strategies

### 1. Always test language compliance with Flash-class models

Large models (Claude Opus, GPT-4) may follow system prompt language directives perfectly while Flash/Lite models fail. Test with the weakest supported model.

### 2. User message proximity > system prompt distance

For meta-instructions (language, format, persona), proximity to the generation point matters more than instruction strength. A short hint at the end of the user message beats a verbose directive at the start of the system prompt.

### 3. Use target language tokens for language instructions

Writing "Respond in French" in English is less effective than writing "Reponds en francais" in French. The target language tokens prime the model's language generation.

### 4. Separate LLM copy from stored session

When adding hints/tags to messages for model compliance, always operate on a copy. Storing them would compound across turns and pollute the conversation.

### 5. Test with conversation history, not just fresh sessions

Language compliance may work perfectly in a new session (2 messages) but fail in an existing session (15+ messages). Always test with realistic conversation lengths.

### 6. Multi-layer defense for critical instructions

No single technique reliably controls model behavior across all models. Use layered enforcement:
- Layer 1: System prompt directive (works for strong models)
- Layer 2: Structured markers for parsing priority
- Layer 3: User message proximity for weak models

### Testing checklist for future locale changes

- [ ] New session, target locale, simple question
- [ ] Existing session with 10+ messages in different language
- [ ] After tool call returns English data
- [ ] After summarization trigger (20+ messages)
- [ ] With each supported model (especially Flash-class)

## Related Documentation

- [LLM Agent Ignoring Language Preference](../logic-errors/llm-agent-locale-prompt-engineering.md) -- Covers the inverse problem (EN selected, responds in FR) from 2026-02-22. Fix: instruction repositioning + strengthening + locale-aware summarization. Necessary foundation but insufficient for Gemini Flash.
- [Implement i18n with dual-isolate support](../architecture/implement-i18n-with-dual-isolate-support.md) -- Full i18n architecture
- [Fix plan: Agent language and tool aggression](../../plans/2026-02-27-fix-agent-language-and-tool-aggression-plan.md) -- Original plan that included this fix
