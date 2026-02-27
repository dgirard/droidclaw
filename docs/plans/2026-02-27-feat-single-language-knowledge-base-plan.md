---
title: "feat: Single-Language Knowledge Base"
type: feat
date: 2026-02-27
---

# feat: Single-Language Knowledge Base

## Overview

The Knowledge Base (KG) must store all data in a single language — the user's language when the KG is first enabled. Even if the user later changes the app's display language, all stored entities, facts, relations, and summaries remain in the original creation language. Translation is applied during ingestion (conversation → KB language) and retrieval (query → KB language keywords).

## Problem Statement

Currently, the `EntityExtractor` uses a hardcoded English system prompt (`entity_extractor.dart:77`). It extracts entities in whatever language the conversation happens to be in — a French conversation produces French entities, an English one produces English entities. This creates a mixed-language KG that degrades FTS5 search quality and makes entity resolution unreliable across languages.

**Example:** A user who speaks French and English alternately ends up with both "dentiste" and "dentist" as separate entities, and FTS5 queries in one language miss results stored in the other.

## Proposed Solution

Lock the KG to a single language at creation time. All data flows through language-aware extraction and query translation to maintain consistency.

**Key principle:** The LLM handles all translation work — no external translation API needed. The extraction prompt instructs the LLM to translate extracted data to the KB language. The query expansion prompt translates search keywords to the KB language.

## Technical Approach

### Phase 1: Config & Data Model

- [x] Add `kbLanguage` field (`String?`) to `KnowledgeConfig` in `app_config.dart:293`
  - `null` = not yet set (KG never enabled or reset after "Forget All")
  - Set to `resolvedLocale` on first KG enable
  - Immutable once set (until "Forget All" resets it)
- [x] Update `KnowledgeConfig.fromJson()` / `toJson()` / `copyWith()` for the new field
- [x] Add `cachedKbLanguageKey` constant to `AppConstants` in `shared/constants.dart`
- [x] Cache `kbLanguage` in `_cacheSecretsForService()` (`background_service_provider.dart:201`) for service isolate access
- [x] Add helper `kbLanguageName(String code)` → full language name map (`'en'` → `'English'`, `'fr'` → `'French'`, etc.) for use in LLM prompts

### Phase 2: Language-Aware Entity Extraction

- [x] Add `kbLanguage` parameter to `EntityExtractor` constructor (`entity_extractor.dart:75`)
- [x] Replace `static const _systemPrompt` with an instance getter that injects the KB language:
  ```
  "All entity names, fact keys, fact values, relation predicates, and entity
  summaries MUST be in {languageName}. If the conversation is in a different
  language, translate all extracted data to {languageName}."
  ```
  Appended at the end of the extraction prompt (recency bias — per `docs/solutions/logic-errors/llm-agent-locale-prompt-engineering.md`)
- [x] Update `IngestionPipeline` constructor to accept and pass `kbLanguage` to `EntityExtractor`
- [x] Update wiring in `app_providers.dart` (`agentLoopProvider`) to pass `config.knowledge.kbLanguage` through `EntityExtractor` → `IngestionPipeline`
- [x] Update `ServiceAgentFactory.create()` to read `kbLanguage` from SharedPreferences and pass to `EntityExtractor` + `IngestionPipeline`

### Phase 3: Language-Aware Query Translation

- [x] Modify `_expandQueryForKG()` prompt in `agent_loop.dart:257` to target KB language specifically:
  ```
  "Translate the user's message to {languageName} if it is not already in
  that language. Then extract search keywords in {languageName} only."
  ```
  Instead of the current "Include: translations (FR/EN/DE/ES/IT)" which spreads across all languages
- [x] Pass `kbLanguage` to `AgentLoop` (already has `config` access — read from `config.knowledge.kbLanguage`)
- [x] Update `_expandQueryForKG()` in `ServiceAgentFactory`'s agent loop creation (same change)

### Phase 4: Tool Description Updates

- [x] Update `KnowledgeStoreTool` (`knowledge_store_tool.dart`):
  - Add `kbLanguage` constructor parameter
  - Update tool `description` to include: `"IMPORTANT: All entity names, keys, and values MUST be in {languageName}. Translate if the conversation is in a different language."`
  - Register with `kbLanguage` in `app_providers.dart` and `service_agent_factory.dart`
- [x] Update `KnowledgeSearchTool` (`knowledge_search_tool.dart`):
  - Add `kbLanguage` constructor parameter
  - Update tool `description` to include: `"Formulate your search query in {languageName} for best results."`
  - Register with `kbLanguage` in `app_providers.dart` and `service_agent_factory.dart`

### Phase 5: KG Enable/Reset Flow

- [x] Modify KG enable logic in `knowledge_config_screen.dart`:
  - When toggling KG ON and `kbLanguage == null`: set `kbLanguage = config.resolvedLocale`
  - Save updated config via `configStorage.save()`
- [x] Modify "Forget All" flow in `knowledge_config_screen.dart`:
  - After deleting all data, also reset `kbLanguage` to `null` in `KnowledgeConfig`
  - Next enable will set a fresh `kbLanguage` from current locale
- [x] Handle existing KGs (data exists but `kbLanguage == null`):
  - On first access after update, set `kbLanguage = 'en'` (all prior data was extracted in English due to hardcoded prompt)
  - Show one-time info dialog explaining the KB is locked to English, with option to "Forget All & restart in {currentLocale}"

### Phase 6: UI — KB Language Display

- [x] Add read-only `ListTile` to `KnowledgeConfigScreen` showing KB language when `kbLanguage != null`:
  - Icon: `Icons.language`
  - Title: localized "Knowledge language" label
  - Subtitle: full language name (e.g., "Francais", "English")
  - No tap action (read-only)
- [x] Add ARB keys for the new UI strings (all 5 locales):
  - `kbLanguageLabel`: "Knowledge language"
  - `kbLanguageLockedNotice`: "All knowledge is stored in {language}. Change via Forget All."
  - `kbExistingDataEnglishNotice`: "Your existing knowledge data is in English (from before this update)."
  - `kbResetAndRestart`: "Forget All & restart in {language}"
- [x] Add note in `ContextBuilder` system prompt KG preamble: `"The knowledge data below is stored in {languageName}."`

### Phase 7: Validate & Build

- [x] `flutter analyze` — 0 issues
- [x] `flutter build apk --release --split-per-abi`
- [x] Manual test scenarios:
  - Enable KG with FR locale → extract from FR conversation → verify entities in FR
  - Switch locale to EN → send EN message → verify extraction still in FR
  - Query in EN → verify `_expandQueryForKG` translates to FR → verify FTS5 matches
  - `knowledge_store` called by LLM → verify entity stored in FR
  - `knowledge_search` called by LLM → verify query in FR
  - "Forget All" → re-enable with DE locale → verify `kbLanguage` = DE
  - Existing KG (no `kbLanguage`) → verify defaults to EN with notice

## Acceptance Criteria

- [x] `KnowledgeConfig.kbLanguage` persisted and immutable after first KG enable
- [x] Entity extraction always produces KB-language data regardless of conversation language
- [x] Query expansion translates to KB language for FTS5 matching
- [x] `knowledge_store` and `knowledge_search` tool descriptions include KB language instructions
- [x] "Forget All" resets `kbLanguage`, enabling language change on re-enable
- [x] Existing KGs default to English with user notification
- [x] KB language displayed on config screen (read-only)
- [x] Service isolate receives `kbLanguage` and uses it correctly
- [x] `flutter analyze` passes, APK builds

## Dependencies & Risks

**No external dependencies.** All translation is done by the LLM (already available).

**Risks:**
- **LLM compliance:** The LLM may not always translate perfectly to the KB language, especially for `knowledge_store` where it generates the data directly. Mitigation: strong prompt positioning (end of prompt, imperative language).
- **Embedding cross-language similarity:** Query embeddings in user language vs entity embeddings in KB language may have reduced cosine similarity. Mitigation: `_expandQueryForKG()` translates the query first, and the expanded text is used for both FTS5 and as the embedding query input.
- **Mixed-language existing data:** Users with existing KGs will have English-only data. Mitigation: default to English, offer "Forget All & restart."

## Files to Modify

| File | Change |
|---|---|
| `lib/core/config/app_config.dart` | Add `kbLanguage` to `KnowledgeConfig` |
| `lib/shared/constants.dart` | Add `cachedKbLanguageKey` |
| `lib/core/knowledge/services/entity_extractor.dart` | Add `kbLanguage` param, dynamic prompt |
| `lib/core/knowledge/services/ingestion_pipeline.dart` | Pass `kbLanguage` to extractor |
| `lib/core/agent/agent_loop.dart` | Update `_expandQueryForKG()` for KB language |
| `lib/core/tools/knowledge_store_tool.dart` | Add `kbLanguage`, update description |
| `lib/core/tools/knowledge_search_tool.dart` | Add `kbLanguage`, update description |
| `lib/providers/app_providers.dart` | Wire `kbLanguage` through providers |
| `lib/core/agent/service_agent_factory.dart` | Read + pass `kbLanguage` |
| `lib/providers/background_service_provider.dart` | Cache `kbLanguage` for service isolate |
| `lib/features/settings/knowledge_config_screen.dart` | Set `kbLanguage` on enable, reset on Forget All, display |
| `lib/core/agent/context_builder.dart` | Add KB language note in KG preamble |
| `lib/l10n/app_en.arb` | Add ARB keys |
| `lib/l10n/app_fr.arb` | Add ARB keys |
| `lib/l10n/app_es.arb` | Add ARB keys |
| `lib/l10n/app_de.arb` | Add ARB keys |
| `lib/l10n/app_it.arb` | Add ARB keys |

## References

- `docs/solutions/logic-errors/llm-agent-locale-prompt-engineering.md` — instruction positioning for LLM language control
- `docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md` — multilingual query expansion patterns
- `docs/solutions/architecture/implement-i18n-with-dual-isolate-support.md` — locale propagation, service isolate caching
- `docs/plans/2026-02-24-feat-local-knowledge-graph-memory-system-plan.md` — KG architecture context
