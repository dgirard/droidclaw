---
title: "feat: Add Brave Search API key configuration screen"
type: feat
date: 2026-02-16
---

# Add Brave Search API key configuration screen

## Overview

Ajouter un ecran Settings pour configurer la cle API Brave Search. Actuellement, `braveApiKey` existe dans `ToolsConfig` mais **aucune UI ne permet de la saisir**. Sans cle Brave, `web_search` utilise le fallback DuckDuckGo HTML qui est moins fiable et plus lent que l'API Brave.

## Problem Statement / Motivation

- Le `web_search` tool est un outil central de l'agent — il doit fonctionner de maniere fiable
- Brave Search API offre des resultats de bien meilleure qualite que le fallback DuckDuckGo
- La cle Brave est actuellement stockee en clair dans le JSON config (`ToolsConfig.braveApiKey`) — elle devrait etre dans SecureStorage comme les cles LLM
- L'utilisateur n'a aucun moyen de configurer cette cle sans editer manuellement le JSON

## Proposed Solution

### 1. Nouvel ecran `WebSearchConfigScreen`

Un ecran simple accessible depuis Settings > Web Search, calque sur le pattern de `provider_config_screen.dart` :
- TextField pour la cle API Brave (obscurable, comme le champ API Key du provider)
- Bouton "Test" qui fait une vraie recherche Brave et affiche le resultat
- Bouton "Save" dans l'AppBar
- Note explicative : la recherche fonctionne sans cle (fallback DuckDuckGo) mais Brave donne de meilleurs resultats

### 2. Migration du stockage de la cle Brave

Deplacer `braveApiKey` de `ToolsConfig` (JSON en clair) vers `FlutterSecureStorage` :
- Ajouter `getSecure('brave_api_key')` / `setSecure('brave_api_key')` dans `ConfigStorage`
- Supprimer `braveApiKey` de `ToolsConfig`
- Le `toolRegistryProvider` charge la cle depuis SecureStorage au lieu de `config.tools.braveApiKey`

### 3. Wiring dans Settings + routes

- Ajouter une entree "Web Search" dans `settings_screen.dart` (section Tools)
- Ajouter la route `/settings/web-search` dans `app.dart`

## Fichiers a modifier

| Fichier | Changement |
|---|---|
| `lib/features/settings/web_search_config_screen.dart` | **Nouveau** — ecran de config Brave API key |
| `lib/features/settings/settings_screen.dart` | Ajouter section "Tools" avec entree "Web Search" |
| `lib/app.dart` | Ajouter route `/settings/web-search` + import |
| `lib/core/config/config_storage.dart` | Ajouter `getBraveApiKey()` / `setBraveApiKey()` (SecureStorage) |
| `lib/core/config/app_config.dart` | Retirer `braveApiKey` de `ToolsConfig` |
| `lib/providers/app_providers.dart` | `toolRegistryProvider` : charger braveApiKey depuis ConfigStorage |

## Changements detailles

### `web_search_config_screen.dart` (nouveau)

Pattern identique a `provider_config_screen.dart` :
- `ConsumerStatefulWidget` avec `_apiKeyController`
- `_loadCurrentKey()` au `initState` via `configStorage.getBraveApiKey()`
- `_testSearch()` : cree un `WebSearchTool(braveApiKey: key)`, appelle `execute({'query': 'test'})`, affiche le resultat
- `_save()` : `configStorage.setBraveApiKey(key)`, met a jour le provider, pop

### `config_storage.dart`

```dart
Future<String?> getBraveApiKey() => _storage.getSecure('brave_api_key');
Future<void> setBraveApiKey(String apiKey) => _storage.setSecure('brave_api_key', apiKey);
```

### `app_config.dart` — `ToolsConfig`

Retirer `braveApiKey` du modele :
```dart
class ToolsConfig {
  final int webSearchMaxResults;
  // braveApiKey supprime — stocke dans SecureStorage
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
  // ... reste inchange
});
```

### `settings_screen.dart`

Ajouter entre la section "Agent" et "Channels" :

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

## Points de vigilance

1. **Apres save, le toolRegistry doit se rafraichir** — comme `toolRegistryProvider` est un `FutureProvider` qui `ref.watch(appConfigProvider)`, il faut soit invalider le provider soit forcer un rebuild. Le plus simple : faire un `ref.invalidate(toolRegistryProvider)` apres le save, ou ajouter un `braveApiKeyProvider` reactif.

2. **Migration des configs existantes** — si un utilisateur a deja un `brave_api_key` dans le JSON config, on pourrait le migrer vers SecureStorage au premier lancement. Mais comme personne n'a pu le configurer via l'UI, c'est peu probable — on peut simplement ignorer l'ancien champ.

3. **Le test doit gerer l'echec gracieusement** — erreur 401 (mauvaise cle), timeout, etc.

## Acceptance Criteria

- [x] Ecran "Web Search" accessible depuis Settings > Tools > Web Search
- [x] Champ API key obscurable avec toggle visibility
- [x] Bouton "Test" qui fait une vraie recherche Brave et affiche succes/echec
- [x] Bouton "Save" qui persiste la cle dans SecureStorage
- [x] Note explicative visible quand pas de cle configuree
- [x] `braveApiKey` retire de `ToolsConfig` (plus en clair dans le JSON)
- [x] `flutter analyze` passe sans erreur
- [ ] web_search fonctionne avec une cle Brave configuree via l'ecran

## References

### Internal References
- Pattern a suivre : `lib/features/settings/provider_config_screen.dart`
- Config storage : `lib/core/config/config_storage.dart:24-33`
- ToolsConfig actuel : `lib/core/config/app_config.dart:144-173`
- WebSearchTool : `lib/core/tools/web_search_tool.dart:45-46`
- Tool registry wiring : `lib/providers/app_providers.dart:80-83`
- Settings screen : `lib/features/settings/settings_screen.dart`
- App routes : `lib/app.dart:29-36`

### External References
- Brave Search API : https://brave.com/search/api/
