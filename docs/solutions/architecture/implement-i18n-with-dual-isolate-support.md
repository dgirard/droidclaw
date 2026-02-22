---
title: Implement i18n with Dual-Isolate Support
date: 2026-02-22
category: architecture
tags:
  - localization
  - i18n
  - dual-isolate
  - service-isolate
  - arb
  - flutter
severity: major
component:
  - lib/l10n/
  - lib/core/agent/
  - lib/core/tools/
  - lib/core/services/
  - lib/features/
  - lib/providers/
symptom: >
  Mixed language output across the app: weather WMO descriptions in French,
  transit labels in French, datetime hardcoded fr_FR, UI strings in English.
  No locale configuration. Service isolate (background Telegram + crons) has
  no BuildContext — standard Flutter Localizations.of(context) unavailable.
status: solved
related_docs:
  - docs/solutions/architecture/decouple-cron-from-telegram-autonomous-service.md
  - docs/solutions/architecture/enable-location-tools-in-service-isolate.md
  - docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md
---

# Implement i18n with Dual-Isolate Support

## Problem

The codebase had a mixed-language problem with no systematic localization:

- Weather WMO descriptions hardcoded in French (`Ciel dégagé`, `Pluie légère`)
- Transit labels hardcoded in French (`correspondance`, `Durée`, `Départ`)
- DateTimeTool hardcoded `fr_FR` locale
- All UI strings hardcoded in English
- No user-facing locale selection

The dual-isolate architecture compounds the problem: the service isolate runs on a separate FlutterEngine with **no BuildContext**. Standard Flutter `Localizations.of(context)` doesn't work there.

## Root Cause

No i18n infrastructure existed. ~380 strings were scattered across 40+ files in two languages with no extraction, no translation files, and no locale-aware rendering.

## Solution

### Core Innovation: Context-Free Localization

Flutter's `flutter_localizations` code generator produces **pure Dart classes** — no platform channels needed. The key design: a `tr(languageCode)` static function that works everywhere without BuildContext.

**`lib/l10n/l10n.dart`**:
```dart
import 'dart:ui';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Get localized strings without BuildContext.
/// Works in both main isolate and service isolate.
AppLocalizations tr(String languageCode) {
  return lookupAppLocalizations(Locale(languageCode));
}
```

**Two access patterns**:
- `lib/features/` (has BuildContext) → `AppLocalizations.of(context)`
- `lib/core/` (no BuildContext) → `tr(locale)`

### Locale Configuration

**`AppConfig`** stores locale as `'system'`, `'en'`, or `'fr'`:

```dart
String get resolvedLocale {
  if (locale == 'system') {
    final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
    return deviceLocale == 'fr' ? 'fr' : 'en';
  }
  return locale;
}
```

**Provider cascade**: changing `appConfigProvider` rebuilds everything:
```
appConfigProvider (locale) → toolRegistryProvider → contextBuilderProvider → agentLoopProvider
                           → llmProviderProvider ↗
```

### Tool Locale Injection

Tools receive locale via constructor — same pattern as API keys:

```dart
class WeatherTool extends Tool {
  final String locale;
  WeatherTool({this.locale = 'en'});

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final l = tr(locale);
    return ToolResult.dual(
      forLLM: 'English structured data for LLM reasoning',
      forUser: '${l.weatherToday(date)}: ${l.weatherClearSky}',
    );
  }
}
```

Registration in `app_providers.dart`:
```dart
final locale = config.resolvedLocale;
registry.register(WeatherTool(locale: locale));
registry.register(TransitTool(sncfApiKey: sncfApiKey, primApiKey: primApiKey, locale: locale));
registry.register(DateTimeTool(locale: locale));
registry.register(DeviceInfoTool(locale: locale));
```

### Service Isolate Locale Propagation

Follows the existing secret caching pattern from `_cacheSecretsForService()`:

```dart
// Main isolate caches locale
await prefs.setString(AppConstants.cachedLocaleKey, config.resolvedLocale);

// Service isolate reads it
_locale = prefs.getString(AppConstants.cachedLocaleKey) ?? 'en';

// Passed to ServiceAgentFactory
_agentLoop = await ServiceAgentFactory.create(
  locale: prefs.getString(AppConstants.cachedLocaleKey) ?? 'en',
);
```

### System Prompt

The system prompt body stays English (for LLM reasoning). A locale-aware response instruction is appended:

```dart
// In ContextBuilder._buildIdentity()
'${tr(locale).agentRespondInstructions}'
// EN: "Respond in English."
// FR: "Réponds en français."
```

## Implementation Phases

| Phase | Scope | Commit |
|-------|-------|--------|
| 1. Foundation | l10n.yaml, ARB files, `tr()` helper, AppConfig locale, MaterialApp wiring | `ce1df85` |
| 2. UI strings | ~160 strings across 15 feature screens | `c69fede` |
| 3. Tool outputs | 4 tools (weather, transit, datetime, device_info) + service isolate propagation | `06dae3c` |
| 4. Agent/notifications | System prompt, AgentLoop errors, Telegram messages, notification text | `e796128` |
| 5. Cron display | `CronSchedule.localizedDisplayText(l)` | `129e5f8` |
| 6. Locale switcher | Flag icon in chat AppBar with popup menu | `e8eb5be` |

## What NOT to Localize

| Component | Example | Reason |
|-----------|---------|--------|
| Tool `name` fields | `web_search`, `weather` | LLM schema identifiers |
| Tool parameter names | `latitude`, `origin_lat` | JSON Schema for LLM |
| `ToolResult.forLLM` | Structured English data | LLM reasoning context |
| System prompt body | "You are DroidClaw..." | LLM instruction consistency |
| Provider names | `anthropic`, `openrouter` | API identifiers |
| Log messages | `[AgentLoop] LLM error: $e` | Developer diagnostics |

## Files Modified

### Foundation
- `l10n.yaml`, `lib/l10n/l10n.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`
- `lib/core/config/app_config.dart` — `locale` field + `resolvedLocale`
- `lib/app.dart` — MaterialApp `locale` + `localizationsDelegates`
- `lib/shared/constants.dart` — `cachedLocaleKey`

### Tools & Agent
- `lib/core/tools/weather_tool.dart`, `transit_tool.dart`, `datetime_tool.dart`, `device_info_tool.dart`
- `lib/core/agent/context_builder.dart`, `agent_loop.dart`, `service_agent_factory.dart`
- `lib/providers/app_providers.dart`

### Service & Telegram
- `lib/providers/background_service_provider.dart`, `telegram_provider.dart`
- `lib/core/services/background_task_handler.dart`
- `lib/features/telegram/telegram_bot_manager.dart`

### UI (15+ screens)
- `lib/features/chat/chat_screen.dart`, `input_bar.dart`, `message_bubble.dart`, `agent_status_indicator.dart`, `history_screen.dart`
- `lib/features/settings/settings_screen.dart`, `provider_config_screen.dart`, `telegram_config_screen.dart`, `tools_config_screen.dart`, `web_search_config_screen.dart`, `routing_config_screen.dart`, `cron_config_screen.dart`, `cron_edit_screen.dart`, `skills_screen.dart`, `locale_config_screen.dart`
- `lib/features/onboarding/onboard_screen.dart`

## Prevention: Adding New Localized Content

### New Tool Checklist

```
[ ] Constructor accepts `locale` parameter (default 'en')
[ ] execute() uses `final l = tr(locale);` for user-facing strings
[ ] ToolResult.dual() — forLLM stays English, forUser uses l.keyName
[ ] Tool.name stays English snake_case (never localized)
[ ] ARB keys added to BOTH app_en.arb AND app_fr.arb
[ ] Registered in app_providers.dart with `locale: locale`
[ ] If service-compatible: registered in service_agent_factory.dart with locale
[ ] Run `flutter gen-l10n` after ARB changes
```

### New Screen Checklist

```
[ ] Import `../../l10n/l10n.dart`
[ ] Use `final l = AppLocalizations.of(context);` in build()
[ ] All Text() widgets use l.keyName
[ ] ARB keys added to BOTH app_en.arb AND app_fr.arb
[ ] Run `flutter gen-l10n` after ARB changes
```

### ARB Sync Validation

```bash
# Quick check: key counts should match
jq 'keys | map(select(startswith("@") | not)) | length' lib/l10n/app_en.arb
jq 'keys | map(select(startswith("@") | not)) | length' lib/l10n/app_fr.arb
```

## Key Patterns Reference

| Pattern | Where | How |
|---------|-------|-----|
| Context-free localization | `lib/core/` | `tr(locale).keyName` |
| Context localization | `lib/features/` | `AppLocalizations.of(context).keyName` |
| Tool locale injection | Tool constructors | `WeatherTool(locale: config.resolvedLocale)` |
| Service isolate propagation | SharedPreferences | `cachedLocaleKey` in `_cacheSecretsForService()` |
| Locale selection | AppConfig | `'system'` / `'en'` / `'fr'` with `resolvedLocale` getter |
| LLM response language | ContextBuilder | `agentRespondInstructions` ARB key appended to system prompt |
