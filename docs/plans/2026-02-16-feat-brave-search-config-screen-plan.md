---
title: "feat: Add Brave Search API key configuration screen"
type: feat
date: 2026-02-16
---

# Add Brave Search API key configuration screen

## Overview

Add a Settings screen to configure the Brave Search API key. Currently, `braveApiKey` exists in `ToolsConfig` but **no UI allows it to be entered**. Without a Brave key, `web_search` uses the DuckDuckGo HTML fallback which is less reliable and slower than the Brave API.

## Problem Statement / Motivation

- The `web_search` tool is a core tool of the agent — it needs to work reliably
- Brave Search API offers much higher quality results than the DuckDuckGo fallback
- The Brave key is currently stored in plain text in the JSON config (`ToolsConfig.braveApiKey`) — it should be in SecureStorage like the LLM provider keys
- The user has no way to configure this key without manually editing the JSON

## Proposed Solution

### 1. New `WebSearchConfigScreen`

A simple screen accessible from Settings > Web Search, modeled after the `provider_config_screen.dart` pattern:
- TextField for the Brave API key (obscurable, like the provider API Key field)
- "Test" button that performs a real Brave search and displays the result
- "Save" button in the AppBar
- Explanatory note: search works without a key (DuckDuckGo fallback) but Brave gives better results

### 2. Migrate Brave key storage

Move `braveApiKey` from `ToolsConfig` (plain text JSON) to `FlutterSecureStorage`:
- Add `getSecure('brave_api_key')` / `setSecure('brave_api_key')` to `ConfigStorage`
- Remove `braveApiKey` from `ToolsConfig`
- `toolRegistryProvider` loads the key from SecureStorage instead of `config.tools.braveApiKey`

### 3. Wire into Settings + routes

- Add a "Web Search" entry in `settings_screen.dart` (Tools section)
- Add the `/settings/web-search` route in `app.dart`

## Files to modify

| File | Change |
|---|---|
| `lib/features/settings/web_search_config_screen.dart` | **New** — Brave API key config screen |
| `lib/features/settings/settings_screen.dart` | Add "Tools" section with "Web Search" entry |
| `lib/app.dart` | Add route `/settings/web-search` + import |
| `lib/core/config/config_storage.dart` | Add `getBraveApiKey()` / `setBraveApiKey()` (SecureStorage) |
| `lib/core/config/app_config.dart` | Remove `braveApiKey` from `ToolsConfig` |
| `lib/providers/app_providers.dart` | `toolRegistryProvider`: load braveApiKey from ConfigStorage |

## Detailed changes

### `web_search_config_screen.dart` (new)

Same pattern as `provider_config_screen.dart`:
- `ConsumerStatefulWidget` with `_apiKeyController`
- `_loadCurrentKey()` at `initState` via `configStorage.getBraveApiKey()`
- `_testSearch()`: creates a `WebSearchTool(braveApiKey: key)`, calls `execute({'query': 'test'})`, displays the result
- `_save()`: `configStorage.setBraveApiKey(key)`, updates the provider, pops

### `config_storage.dart`

```dart
Future<String?> getBraveApiKey() => _storage.getSecure('brave_api_key');
Future<void> setBraveApiKey(String apiKey) => _storage.setSecure('brave_api_key', apiKey);
```

### `app_config.dart` — `ToolsConfig`

Remove `braveApiKey` from the model:
```dart
class ToolsConfig {
  final int webSearchMaxResults;
  // braveApiKey removed — stored in SecureStorage
}
```

### `app_providers.dart` — `toolRegistryProvider`

```dart
final toolRegistryProvider = FutureProvider<ToolRegistry>((ref) async {
  final config = ref.watch(appConfigProvider);
  final configStorage = ref.watch(configStorageProvider);
  final storage = ref.watch(storageServiceProvider);
  final workspacePath = await storage.workspacePath;
  final braveApiKey = await configStorage.getBraveApiKey();
  final registry = ToolRegistry();

  registry.register(WebSearchTool(
    braveApiKey: braveApiKey,
    maxResults: config.tools.webSearchMaxResults,
  ));
  // ... rest unchanged
});
```

### `settings_screen.dart`

Add between the "Agent" and "Channels" sections:

```dart
const Divider(),
_SectionHeader(title: 'Tools'),
ListTile(
  leading: const Icon(Icons.search_outlined),
  title: const Text('Web Search'),
  subtitle: const Text('Configure Brave Search API'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.pushNamed(context, '/settings/web-search'),
),
```

### `app.dart`

```dart
'/settings/web-search': (context) => const WebSearchConfigScreen(),
```

## Points to watch

1. **After save, the toolRegistry must refresh** — since `toolRegistryProvider` is a `FutureProvider` that `ref.watch(appConfigProvider)`, we need to either invalidate the provider or force a rebuild. Simplest approach: call `ref.invalidate(toolRegistryProvider)` after save, or add a reactive `braveApiKeyProvider`.

2. **Existing config migration** — if a user already has a `brave_api_key` in the JSON config, we could migrate it to SecureStorage on first launch. But since nobody has been able to configure it via the UI, this is unlikely — we can simply ignore the old field.

3. **The test must handle failure gracefully** — 401 error (bad key), timeout, etc.

## Acceptance Criteria

- [x] "Web Search" screen accessible from Settings > Tools > Web Search
- [x] Obscurable API key field with visibility toggle
- [x] "Test" button that performs a real Brave search and shows success/failure
- [x] "Save" button that persists the key in SecureStorage
- [x] Explanatory note visible when no key is configured
- [x] `braveApiKey` removed from `ToolsConfig` (no longer in plain text JSON)
- [x] `flutter analyze` passes without errors
- [ ] web_search works with a Brave key configured via the screen

## References

### Internal References
- Pattern to follow: `lib/features/settings/provider_config_screen.dart`
- Config storage: `lib/core/config/config_storage.dart:24-33`
- Current ToolsConfig: `lib/core/config/app_config.dart:144-173`
- WebSearchTool: `lib/core/tools/web_search_tool.dart:45-46`
- Tool registry wiring: `lib/providers/app_providers.dart:80-83`
- Settings screen: `lib/features/settings/settings_screen.dart`
- App routes: `lib/app.dart:29-36`

### External References
- Brave Search API: https://brave.com/search/api/
