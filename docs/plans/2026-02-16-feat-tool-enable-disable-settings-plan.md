---
title: "feat: Add tool enable/disable settings"
type: feat
date: 2026-02-16
---

# Add Tool Enable/Disable Settings

## Overview

Allow users to enable or disable individual tools (web_search, web_fetch, file, get_location, subagent) from a dedicated settings screen. Each tool gets a toggle switch. Disabled tools are not registered in the ToolRegistry, so the LLM never sees them and cannot call them.

## How It Works

The Riverpod dependency cascade already handles this:
1. User toggles a tool off in settings → `ToolsConfig.disabledTools` updated → `AppConfig` saved
2. `appConfigProvider` state changes → `toolRegistryProvider` rebuilds (it `ref.watch`es appConfig)
3. Disabled tools are simply not registered → `ContextBuilder` and `AgentLoop` only see enabled tools
4. No changes needed in `ContextBuilder`, `AgentLoop`, or individual tool files

## Implementation

### 1. Add `disabledTools` to `ToolsConfig`

**`lib/core/config/app_config.dart`** — in `ToolsConfig`:

```dart
class ToolsConfig {
  final int webSearchMaxResults;
  final Set<String> disabledTools;

  const ToolsConfig({
    this.webSearchMaxResults = AppConstants.webSearchMaxResults,
    this.disabledTools = const {},
  });

  factory ToolsConfig.fromJson(Map<String, dynamic> json) => ToolsConfig(
    webSearchMaxResults: json['web_search_max_results'] as int? ?? AppConstants.webSearchMaxResults,
    disabledTools: (json['disabled_tools'] as List<dynamic>?)
        ?.map((e) => e as String).toSet() ?? const {},
  );

  Map<String, dynamic> toJson() => {
    'web_search_max_results': webSearchMaxResults,
    'disabled_tools': disabledTools.toList(),
  };

  ToolsConfig copyWith({int? webSearchMaxResults, Set<String>? disabledTools}) => ToolsConfig(
    webSearchMaxResults: webSearchMaxResults ?? this.webSearchMaxResults,
    disabledTools: disabledTools ?? this.disabledTools,
  );
}
```

Using `disabledTools` (not enabledTools) so new tools added in future are enabled by default — no migration needed.

### 2. Gate tool registration

**`lib/providers/app_providers.dart`** — in `toolRegistryProvider`:

```dart
final disabled = config.tools.disabledTools;

if (!disabled.contains('web_search')) {
  registry.register(WebSearchTool(braveApiKey: braveApiKey, maxResults: config.tools.webSearchMaxResults));
}
if (!disabled.contains('web_fetch')) {
  registry.register(WebFetchTool());
}
if (!disabled.contains('file')) {
  registry.register(FileTool(workspacePath: workspacePath));
}
// message tool is always registered (internal UI mechanism)
registry.register(MessageTool());
if (!disabled.contains('get_location')) {
  registry.register(LocationTool());
}
if (!disabled.contains('subagent')) {
  registry.register(SubagentTool());
}
```

Note: `MessageTool` is always registered — it's an internal communication mechanism, not a user-facing tool.

### 3. Create tools settings screen

**`lib/features/settings/tools_config_screen.dart`** — NEW file:

A `ConsumerStatefulWidget` with a `SwitchListTile` per tool. Define a constant list of tool metadata:

```dart
const _toolInfo = [
  (name: 'web_search', label: 'Web Search', description: 'Search the web via Brave API', icon: Icons.search),
  (name: 'web_fetch', label: 'Web Fetch', description: 'Fetch and read web pages', icon: Icons.language),
  (name: 'file', label: 'File Access', description: 'Read and write files in workspace', icon: Icons.folder),
  (name: 'get_location', label: 'GPS Location', description: 'Access device GPS coordinates', icon: Icons.location_on),
  (name: 'subagent', label: 'Sub-agent', description: 'Spawn sub-tasks for complex queries', icon: Icons.account_tree),
];
```

Each toggle immediately saves config (same pattern as other settings screens):
```dart
void _toggle(String toolName, bool enabled) {
  final config = ref.read(appConfigProvider);
  final disabled = Set<String>.from(config.tools.disabledTools);
  if (enabled) {
    disabled.remove(toolName);
  } else {
    disabled.add(toolName);
  }
  final newConfig = config.copyWith(
    tools: config.tools.copyWith(disabledTools: disabled),
  );
  ref.read(configStorageProvider).save(newConfig);
  ref.read(appConfigProvider.notifier).update(newConfig);
}
```

### 4. Add navigation from settings screen

**`lib/features/settings/settings_screen.dart`** — in the "Tools" section, add a ListTile:

```dart
ListTile(
  leading: const Icon(Icons.build),
  title: const Text('Manage Tools'),
  subtitle: const Text('Enable or disable agent tools'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const ToolsConfigScreen(),
  )),
),
```

### 5. No other changes needed

- `ToolRegistry` already supports selective registration
- `ContextBuilder._buildToolsListing()` iterates only registered tools
- `AgentLoop` sends only registered tool definitions to LLM
- `SubagentTool` executor wiring gracefully handles `tools.get('subagent')` returning null
- `ConfigStorage.save/load` already serialize full `AppConfig`

## Acceptance Criteria

- [ ] `disabledTools` field added to `ToolsConfig` with `fromJson`/`toJson`/`copyWith`
- [ ] Tool registration in `toolRegistryProvider` gated by `disabledTools`
- [ ] `MessageTool` always registered (non-disableable)
- [ ] New `ToolsConfigScreen` with `SwitchListTile` per tool
- [ ] "Manage Tools" link added to settings screen
- [ ] Toggling a tool off immediately saves config and rebuilds tool registry
- [ ] Disabled tool does not appear in LLM system prompt
- [ ] LLM cannot call a disabled tool
- [ ] Re-enabling a tool makes it available again immediately
- [ ] `flutter analyze` passes
- [ ] APK builds and installs

## Files Changed

| File | Change |
|------|--------|
| `lib/core/config/app_config.dart` | Add `disabledTools` to `ToolsConfig` |
| `lib/providers/app_providers.dart` | Gate `registry.register()` on disabled check |
| `lib/features/settings/tools_config_screen.dart` | **NEW** — toggle screen |
| `lib/features/settings/settings_screen.dart` | Add "Manage Tools" navigation |

## References

- `lib/core/tools/tool.dart` — Tool, ToolRegistry
- `lib/providers/app_providers.dart:75-93` — current tool registration
- `lib/features/settings/settings_screen.dart:55-70` — Tools section
- `lib/core/agent/context_builder.dart:94-104` — tools in system prompt
