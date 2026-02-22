---
title: "feat: Add Spanish, German, and Italian locales"
type: feat
date: 2026-02-22
---

# feat: Add Spanish, German, and Italian locales

## Overview

Extend DroidClaw's i18n from 2 locales (EN/FR) to 5 (EN/FR/ES/DE/IT). The architecture is already in place — this is purely additive: new ARB files, expanded locale switcher, and updated system locale resolution.

## Files to Modify

| File | Change |
|------|--------|
| `lib/l10n/app_es.arb` | **New** — Spanish translations (~380 keys) |
| `lib/l10n/app_de.arb` | **New** — German translations (~380 keys) |
| `lib/l10n/app_it.arb` | **New** — Italian translations (~380 keys) |
| `lib/core/config/app_config.dart` | Update `_resolveSystemLocale()` to handle `es`, `de`, `it` |
| `lib/features/chat/chat_screen.dart` | Add ES/DE/IT to `_LocaleSwitcher` (`_locales`, `_flag`, `_label`) |
| `lib/features/settings/locale_config_screen.dart` | Add ES/DE/IT radio options |
| `README.md` | Update i18n badge, stats, and tool descriptions |

## Implementation

### Phase 1: Create ARB files

Copy `app_en.arb` as the base for each new locale. Translate all ~380 keys.

Key translation areas:
- **UI strings** (~300 keys): settings labels, buttons, screen titles, error messages
- **Tool output strings** (~50 keys): weather conditions (WMO codes), transit modes, date/time periods
- **Agent strings** (~30 keys): system prompt instructions (`agentRespondInstructions`), notification text

#### `lib/l10n/app_es.arb`
```json
{
  "@@locale": "es",
  ...
}
```

#### `lib/l10n/app_de.arb`
```json
{
  "@@locale": "de",
  ...
}
```

#### `lib/l10n/app_it.arb`
```json
{
  "@@locale": "it",
  ...
}
```

After creating the files, run:
```bash
flutter gen-l10n
```

This auto-generates the lookup classes — `supportedLocales` in `AppLocalizations` will automatically include the new locales.

### Phase 2: Update locale resolution

#### `lib/core/config/app_config.dart:75-78`

Current:
```dart
static String _resolveSystemLocale() {
  final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
  return deviceLocale == 'fr' ? 'fr' : 'en';
}
```

New:
```dart
static const _supportedLocales = {'en', 'fr', 'es', 'de', 'it'};

static String _resolveSystemLocale() {
  final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
  return _supportedLocales.contains(deviceLocale) ? deviceLocale : 'en';
}
```

This is future-proof — adding more locales later only requires adding to the set.

### Phase 3: Update locale switcher

#### `lib/features/chat/chat_screen.dart` — `_LocaleSwitcher`

```dart
static const _locales = ['system', 'en', 'fr', 'es', 'de', 'it'];

static String _flag(String locale) => switch (locale) {
  'fr' => '\u{1F1EB}\u{1F1F7}',
  'en' => '\u{1F1EC}\u{1F1E7}',
  'es' => '\u{1F1EA}\u{1F1F8}',
  'de' => '\u{1F1E9}\u{1F1EA}',
  'it' => '\u{1F1EE}\u{1F1F9}',
  _ => '\u{1F310}',
};

static String _label(String locale) => switch (locale) {
  'fr' => 'Français',
  'en' => 'English',
  'es' => 'Español',
  'de' => 'Deutsch',
  'it' => 'Italiano',
  _ => 'System',
};
```

#### `lib/features/settings/locale_config_screen.dart`

Add three new `RadioListTile` entries for ES/DE/IT (same pattern as existing EN/FR).

### Phase 4: Update docs

- `README.md`: badge `EN_|_FR_|_ES_|_DE_|_IT`, stats table, weather tool description
- `MEMORY.md`: update locale count

## Acceptance Criteria

- [x] `app_es.arb` — all ~380 keys translated to Spanish
- [x] `app_de.arb` — all ~380 keys translated to German
- [x] `app_it.arb` — all ~380 keys translated to Italian
- [x] `flutter gen-l10n` succeeds
- [x] `_resolveSystemLocale()` returns correct locale for es/de/it device languages
- [x] Locale switcher shows 5 flags + system option
- [x] Locale settings screen shows 5 language radio buttons + system
- [x] Switching to ES/DE/IT updates all UI strings, tool outputs, and notifications
- [x] `agentRespondInstructions` prompts the LLM to respond in the selected language
- [x] Service isolate receives new locales via SharedPreferences cache
- [x] `flutter analyze` passes with 0 issues
- [x] Build and install APK — verify all 5 locales work on device
- [x] README updated

## Notes

- `flutter gen-l10n` handles everything — no manual registration of locales needed
- `AppLocalizations.supportedLocales` (used in `app.dart:48`) auto-includes new locales from ARB files
- `l10n.yaml` doesn't need `synthetic-package: false` listed — it's already configured
- The `tr(languageCode)` helper in `lib/l10n/l10n.dart` works automatically for new locales since it calls `lookupAppLocalizations(Locale(languageCode))`
