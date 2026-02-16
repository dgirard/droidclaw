---
title: "feat: Add Google Gemini as LLM provider via API key"
type: feat
date: 2026-02-16
---

# Add Google Gemini as LLM provider via API key

## Overview

Ajouter Google Gemini comme provider LLM de premier plan dans DroidClaw. Gemini n'est pas supporte actuellement — seuls OpenRouter, Anthropic, OpenAI et Groq le sont. L'ajout est trivial car Google fournit un endpoint OpenAI-compatible (`https://generativelanguage.googleapis.com/v1beta/openai`) qui parle le meme protocole que le `HttpProvider` existant.

**Aucun nouveau fichier Dart n'est necessaire.** Le `HttpProvider` gere deja le trafic Gemini. Il faut simplement l'enregistrer comme provider nomme dans 3-4 fichiers.

## Problem Statement / Motivation

- Gemini propose un **free tier genereux** (15 req/min sur Gemini 2.0 Flash) — ideal pour les nouveaux utilisateurs qui veulent tester DroidClaw sans payer
- Gemini 2.5 Pro/Flash sont des modeles tres capables, avec support natif du tool calling
- PicoClaw Go supportait Gemini via son provider generique — DroidClaw devrait faire de meme
- Un utilisateur peut deja utiliser Gemini via OpenRouter, mais un acces direct evite les frais OpenRouter et simplifie l'onboarding

## Proposed Solution

Ajouter `'gemini'` aux listes de providers existantes et configurer le API base + modele par defaut. Le `HttpProvider` gere tout le reste (auth Bearer, format OpenAI, tool calling).

### Fichiers a modifier

| Fichier | Changement |
|---|---|
| `lib/core/providers/provider_factory.dart` | Ajouter `'gemini'` dans `_defaultApiBase` et `_defaultModel` |
| `lib/features/onboarding/onboard_screen.dart` | Ajouter le tuple Gemini dans `_providers` |
| `lib/features/settings/provider_config_screen.dart` | Ajouter `'gemini'` dans `_providers` |
| `lib/shared/constants.dart` | Ajouter `geminiApiBase` (optionnel, pour consistance) |

### Changements detailles

#### `provider_factory.dart`

```dart
// _defaultApiBase switch — ajouter :
'gemini' => 'https://generativelanguage.googleapis.com/v1beta/openai',

// _defaultModel switch — ajouter :
'gemini' => 'gemini-2.0-flash',
```

Le modele par defaut `gemini-2.0-flash` est le choix le plus sur :
- Stable (GA, pas preview)
- Rapide et economique
- Supporte le tool/function calling
- Free tier disponible

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

#### `constants.dart` (optionnel)

```dart
static const String geminiApiBase = 'https://generativelanguage.googleapis.com/v1beta/openai';
```

## Technical Considerations

### Compatibilite confirmee

L'endpoint OpenAI-compatible de Gemini :
- Accepte `Authorization: Bearer <API_KEY>` (confirme par la doc Google)
- Supporte `role: "system"` dans les messages
- Supporte le tool/function calling au format OpenAI (`tool_calls` avec `function.name` et `function.arguments` en JSON string)
- Accepte `max_tokens` dans le body de la requete
- Retourne `usage` avec `prompt_tokens` / `completion_tokens` (format OpenAI)

### Points de vigilance

1. **Rate limiting free tier** : Gemini free tier = 15 req/min sur Flash. Une conversation avec beaucoup de tool calls peut atteindre cette limite. L'erreur 429 sera affichee comme "LLM call failed: API error 429". Pas de retry automatique — c'est un enhancement futur qui beneficierait a tous les providers.

2. **Safety filters** : Gemini peut bloquer des reponses pour raisons de securite. Le `finish_reason` serait `"content_filter"`. Le code actuel traite ca comme un stop normal — la reponse sera vide ou partielle. Acceptable pour v1.

3. **Parsing ToolCall** : `ToolCall.fromJson` dans `llm_response.dart` gere deja les deux formats (OpenAI `function.arguments` en string, et Anthropic `input` en map). Gemini via l'endpoint compatible devrait retourner le format OpenAI, mais le parser est resilient dans les deux cas.

4. **`max_tokens` vs `max_completion_tokens`** : L'endpoint compatible devrait accepter `max_tokens`. A verifier lors du test. Si probleme, c'est un fix d'une ligne dans `http_provider.dart`.

### Ce qui n'est PAS dans le scope

- Retry/backoff sur 429 (enhancement futur, tous providers)
- Detection des safety filter blocks (enhancement futur)
- Noms human-readable dans le dropdown settings (pre-existant, tous providers)
- Model picker dynamique par provider (feature futur)

## Acceptance Criteria

- [ ] Gemini apparait dans l'onboarding (5e provider)
- [ ] Gemini apparait dans le dropdown Settings > Provider Config
- [ ] `flutter analyze` passe sans erreur
- [ ] Test connection avec une cle API Gemini reussit
- [ ] Chat simple (sans tools) fonctionne avec Gemini
- [ ] Chat avec tool calling (web_search) fonctionne avec Gemini
- [ ] Le modele par defaut est `gemini-2.0-flash` (pas `gpt-4o`)

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
