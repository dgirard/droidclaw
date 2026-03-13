---
title: "fix: Sessions disparaissent de l'historique après redémarrage"
type: fix
date: 2026-03-13
deepened: 2026-03-13
---

# fix: Sessions disparaissent de l'historique après redémarrage

## Enhancement Summary

**Deepened on:** 2026-03-13
**Research agents used:** Hive best practices, framework docs, codebase validation, institutional learnings

### Key Improvements from Research
1. **Flush strategy refined** — `flush()` = `fsync()` coûte 10-50ms sur Android (pas 5ms). Stratégie tiered recommandée au lieu de flush systématique
2. **AppLifecycleListener** ajouté — `ref.onDispose()` ne couvre pas le force-kill. Un listener sur `paused`/`detached` est plus fiable
3. **`getMessages()` déjà partiellement safe** — retourne `List.of(_messages)` (copie), MAIS `_stripOrphanedLeadingMessages()` mutate `_messages` AVANT la copie. Le fix doit inverser l'ordre
4. **`compact()` confirmé atomique** — pattern temp-file + rename, safe contre les kills
5. **Multi-isolate Hive officiellement non supporté** — le pattern close+reopen existant est le meilleur possible pour Hive 2.x
6. **Hive crash recovery** — Hive détecte les écritures incomplètes au prochain `openBox()` et tronque au dernier frame valide. On perd au max 1 entrée

### Nouvelles découvertes
- La summarization n'a pas de `save()` après `_summarize()` — si crash entre summarization et réponse finale, la session revient à son état pré-summarization (20+ messages) → re-summarization au prochain message
- Le chemin d'erreur LLM (`agent_loop.dart:218`) ne save pas le message user ajouté à la ligne 120
- `deleteSession()` n'a pas de `flush()` non plus — une session supprimée peut réapparaître après force-kill

## Problem Statement

Certaines sessions de conversation disparaissent de l'écran History après un redémarrage de l'app. Seules certaines sessions sont affectées — d'autres survivent correctement.

## Root Causes

L'investigation a identifié **4 causes indépendantes** qui contribuent toutes au problème :

### 1. Hive box pas flushé sur kill de l'app (CRITIQUE)

`SessionManager.save()` appelle `_box?.put()` mais Hive utilise un buffer en mémoire avec écriture lazy. Si l'app est tuée avant que Hive flush sur disque, les sessions non-flushées sont perdues.

- **Pas de `flush()`** après `save()` dans `session_manager.dart`
- **Pas de `ref.onDispose()`** dans `sessionManagerProvider` (`app_providers.dart:84`)
- Android OOM killer / force-stop ne déclenche aucun cleanup Dart

#### Research Insights

**Hive `put()` n'est PAS durable** — `await box.put()` écrit dans le page cache de l'OS, pas sur le disque. Seul `flush()` appelle `fsync()` pour forcer l'écriture physique.

**Coût réel de `flush()` sur Android** : 10-50ms (pas 5ms comme initialement estimé) car `fsync()` force un write barrier sur eMMC/UFS. Pendant une chaîne de 5 tool calls, ça représente 50-250ms cumulés.

**Crash recovery de Hive** : au prochain `openBox()`, Hive lit le fichier séquentiellement. Chaque frame a un header de 4 bytes + CRC checksum. Si le dernier frame est incomplet, Hive tronque au dernier frame valide. On perd au max 1 entrée, pas de corruption.

**`ref.onDispose()` insuffisant** : un `FutureProvider` n'est disposé que quand le Riverpod container est détruit. Sur force-kill Android (SIGKILL), aucun code Dart n'est exécuté. Le dispose est un safety net pour les arrêts gracieux uniquement.

**Sources** : [Hive Issue #414](https://github.com/isar/hive/issues/414), [Box API docs](https://pub.dev/documentation/hive/latest/hive/Box-class.html)

### 2. La summarization peut vider complètement une session (HIGH)

Quand la summarization se déclenche (20+ messages), `truncateHistory(4)` garde les 4 derniers messages. Si ces 4 sont tous des tool results, `_stripOrphanedLeadingMessages()` dans `session.dart:89` les supprime **destructivement** (mutate la liste `_messages`), laissant une session vide.

```
[user, assistant+toolCall, tool, tool, tool, assistant+toolCall, tool, tool, tool, tool]
                                                    truncateHistory(4) →  [tool, tool, tool, tool]
                                              _stripOrphanedLeading() →  []  ← session vide !
```

#### Research Insights

**`getMessages()` (session.dart:37-51)** retourne `List.of(_messages)` — mais `_stripOrphanedLeadingMessages()` est appelé **avant** la copie, sur `_messages` directement. Chaque appel à `getMessages()` peut donc détruire des messages de manière permanente.

**Double risque** : `getMessages()` est appelé pendant les requêtes LLM (pour construire le contexte). Si appelé entre deux itérations de tools, il peut strip des tool results orphelins qui attendent leur réponse assistant dans l'itération suivante.

**Re-summarization d'une session déjà résumée** : quand `session.summary` existe déjà et qu'une nouvelle summarization se déclenche, l'ancien summary est écrasé (`session.summary = response.content`). L'ancien contexte résumé est perdu. Le prompt de summarization devrait inclure l'ancien summary.

### 3. JSON corrompu silencieusement ignoré (MEDIUM)

Dans `SessionManager.init()` (ligne 25) et `reload()` (ligne 46), le `catch (_) {}` avale les erreurs de désérialisation sans log. Une session avec du JSON partiel (crash pendant écriture) disparaît silencieusement du cache.

#### Research Insights

**Causes de corruption connues** (Hive GitHub issues) :
- Écriture partielle interrompue par kill → Hive crash recovery gère ce cas
- Deux isolates écrivant simultanément dans le même fichier → corruption des frame headers
- `Future.wait()` pour des puts parallèles sur la même box → offsets d'écriture en conflit

**Le JSON corrompu peut aussi venir de `Session.fromJson()`** : si un seul `Message` dans le tableau `messages` a un champ invalide (role null, DateTime mal parsé), toute la session est rejetée. Un parsing défensif message par message préserverait les messages valides.

### 4. Pas de save entre les itérations de tools dans l'agent loop (HIGH)

`AgentLoop.processMessage()` n'appelle `sessions.save()` qu'à la réponse finale (ligne 226) ou au max iterations (ligne 265). Si l'app est tuée pendant une chaîne de 3+ tool calls, tout le travail intermédiaire est perdu.

#### Research Insights

**Points de save manquants identifiés** (validation code) :
- **Après chaque tool result** (lignes 255-260) — accumulation en mémoire sans persistence
- **Sur le chemin d'erreur LLM** (ligne 218) — le message user ajouté à la ligne 120 n'est jamais persisté
- **Après la summarization** (ligne 88) — `_summarize()` truncate l'historique et set `session.summary` mais aucun `save()`. Si crash entre summarization et réponse, la session revient à son état d'avant (20+ messages)

## Proposed Solution

### Phase 1 : Persistence immédiate (empêche la perte)

#### `lib/core/session/session_manager.dart`

- Ajouter `await _box?.flush()` après chaque `_box?.put()` dans `save()` et après `_box?.delete()` dans `deleteSession()`
- Logger les sessions corrompues dans `init()` et `reload()` au lieu de `catch (_) {}`
- Ajouter `compact()` au démarrage de l'app (après `init()`, main isolate seulement)
- Exposer une méthode `flush()` publique pour l'AppLifecycleListener

```dart
// session_manager.dart — save()
Future<void> save(Session session) async {
  _cache[session.key] = session;
  await _box?.put(session.key, jsonEncode(session.toJson()));
  await _box?.flush();  // fsync — force sync to disk
}

// session_manager.dart — deleteSession()
Future<void> deleteSession(String key) async {
  _cache.remove(key);
  await _box?.delete(key);
  await _box?.flush();  // Prevent zombie sessions after force-kill
}

// session_manager.dart — flush() public
Future<void> flush() async {
  await _box?.flush();
}

// session_manager.dart — init() et reload() — les DEUX catch blocks
catch (e) {
  AppLogger.instance.warning(
    LogSource.app,
    'Corrupted session skipped: $key — $e',
  );
}
```

> **Note performance** : `flush()` = `fsync()` coûte 10-50ms sur Android. Acceptable pour DroidClaw car `save()` est appelé ~1 fois par tour d'agent loop (pas par frame UI). Pendant une chaîne de 5 tools, ça ajoute 50-250ms — invisible pour l'utilisateur car les tools prennent eux-mêmes des secondes.

#### `lib/providers/app_providers.dart`

- Ajouter `ref.onDispose()` pour flush sur arrêt gracieux (safety net seulement — ne protège PAS contre force-kill) :

```dart
final sessionManagerProvider = FutureProvider<SessionManager>((ref) async {
  final manager = SessionManager();
  await manager.init();
  ref.onDispose(() async {
    await manager.flush();
  });
  return manager;
});
```

#### `lib/app.dart` ou `lib/main.dart`

- Ajouter un `AppLifecycleListener` pour flush quand l'app passe en background — c'est le filet de sécurité le plus fiable car `paused` est appelé AVANT que Android ne puisse tuer le process :

```dart
AppLifecycleListener(
  onStateChange: (state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Fire-and-forget — best effort flush
      ref.read(sessionManagerProvider.future).then((sm) => sm.flush());
    }
  },
);
```

> **Pourquoi les deux** : `ref.onDispose()` couvre les arrêts gracieux du Riverpod container. `AppLifecycleListener` couvre le passage en background (avant que l'OOM killer ne puisse agir). `flush()` après `save()` couvre le cas nominal. Les trois ensemble forment une défense en profondeur.

#### `lib/core/agent/agent_loop.dart`

- Ajouter `sessions.save(session)` après chaque tool result (ligne ~260, dans la boucle)
- Ajouter `sessions.save(session)` sur le chemin d'erreur LLM (avant le `yield ErrorEvent`)
- Ajouter `sessions.save(session)` après la summarization (après `_summarize()`)

```dart
// Après chaque tool result (~ligne 260)
session.addMessage(Message(
  role: 'tool',
  content: result.forLLM,
  toolCallId: toolCall.id,
  name: toolCall.name,
));
await sessions.save(session);  // Persist after each tool result

// Sur le chemin d'erreur LLM (~ligne 218)
} catch (e) {
  await sessions.save(session);  // Persist user message before error
  yield ErrorEvent(e.toString());
  return;
}

// Après la summarization (~ligne 88)
await _summarize(session, sessions);
await sessions.save(session);  // Persist truncated state
```

### Phase 2 : Protection de la summarization (empêche les sessions vides)

#### `lib/core/session/session.dart`

- Rendre `_stripOrphanedLeadingMessages()` non-destructif : opère sur une **copie** dans `getMessages()`, garde `_messages` intact
- Ajouter un garde dans `truncateHistory()` : augmenter `keepLast` jusqu'à ce qu'au moins 1 message user ou assistant (sans tool_calls) soit retenu
- Lors de re-summarization, inclure l'ancien summary dans le prompt

```dart
// session.dart — truncateHistory()
void truncateHistory(int keepLast) {
  if (_messages.length <= keepLast) return;

  // Ensure at least one non-tool message survives
  int effectiveKeep = keepLast;
  while (effectiveKeep < _messages.length) {
    final kept = _messages.sublist(_messages.length - effectiveKeep);
    if (kept.any((m) => (m.role == 'user' || m.role == 'assistant')
        && m.toolCalls == null)) {
      break;
    }
    effectiveKeep++;
  }

  _messages.removeRange(0, _messages.length - effectiveKeep);
}

// session.dart — getMessages() : non-destructif
List<Message> getMessages() {
  final msgs = List<Message>.of(_messages);
  _stripOrphanedLeading(msgs);  // Opère sur la copie, pas _messages
  if (_summary != null && _summary!.isNotEmpty) {
    msgs.insert(0, Message(role: 'assistant', content: _summary!));
  }
  return msgs;
}
```

> **Pourquoi non-destructif** : `getMessages()` est appelé pendant les requêtes LLM pour construire le contexte. Si appelé entre deux itérations de tools, la version destructive peut strip des tool results orphelins qui attendent leur réponse dans l'itération suivante. En opérant sur une copie, `_messages` reste intact pour la prochaine itération et pour la persistence.

### Phase 3 : Observabilité

- Logger les sessions corrompues avec la clé et l'erreur (niveau `warning`, persisté)
- Sur l'écran History, si une session a un `summary` mais 0 messages, afficher le résumé tronqué comme titre au lieu de la clé brute

## Acceptance Criteria

- [ ] Après un `adb shell am force-stop com.droidclaw.app` pendant un chat avec tool calls, la session est retrouvée au redémarrage avec tous les messages tools
- [ ] Après summarization d'une session avec 20+ messages dont les derniers sont des tool results, la session n'est pas vide
- [ ] `getMessages()` ne mutate plus `_messages` — les messages originaux sont préservés
- [ ] Les sessions avec JSON corrompu sont loguées dans AppLogger (niveau warning) — dans `init()` ET `reload()`
- [ ] `sessions.save()` est appelé après chaque tool result dans l'agent loop
- [ ] `sessions.save()` est appelé sur le chemin d'erreur LLM (le message user est persisté)
- [ ] `sessions.save()` est appelé après la summarization
- [ ] `flush()` est appelé après chaque `save()` et `delete()`
- [ ] `deleteSession()` appelle `flush()` (empêche les sessions zombie)
- [ ] Hive `compact()` est appelé au démarrage (main isolate)
- [ ] `AppLifecycleListener` flush la box Hive sur `paused`/`detached`

## Fichiers à modifier

- `lib/core/session/session_manager.dart` — flush après save/delete, méthode flush() publique, log corrupted dans init() ET reload(), compact on init
- `lib/core/session/session.dart` — getMessages() non-destructif (strip sur copie), truncateHistory() garde min 1 msg non-tool
- `lib/core/agent/agent_loop.dart` — save après tool result, save sur erreur LLM, save après summarization
- `lib/providers/app_providers.dart` — ref.onDispose() avec flush
- `lib/app.dart` — AppLifecycleListener pour flush on pause/detached
- `lib/features/chat/history_screen.dart` — afficher summary comme titre fallback pour sessions vides

## Risks & Notes

- **`flush()` après chaque save** : `fsync()` coûte 10-50ms sur Android eMMC/UFS. Pendant une chaîne de 5 tool calls séquentiels, ça ajoute 50-250ms — invisible car chaque tool call prend lui-même des secondes (HTTP). Si un jour ça pose problème, on pourra passer à un flush tiered (immédiat pour user messages, périodique pour tool results).
- **`compact()` au démarrage** : Hive compact() utilise le pattern temp-file + atomic rename. Safe contre les kills à tout moment du processus. Safe pour les lectures concurrentes (servies depuis la map en mémoire). Le faire dans `init()` avant que l'agent loop ne démarre élimine tout risque d'écriture concurrente.
- **Dual-isolate** : **Hive ne supporte PAS officiellement l'accès multi-isolate** (les advisory locks sont par-process, pas par-isolate). Le pattern actuel close+reopen (`SessionManager.reload()`) est le meilleur possible pour Hive 2.x. Le service isolate et le main isolate ne doivent JAMAIS avoir la même box ouverte simultanément.
- **`ref.onDispose()`** : ne protège PAS contre le force-kill Android (SIGKILL — aucun code Dart n'est exécuté). C'est le `flush()` après `save()` + l'`AppLifecycleListener` qui couvrent ce cas. Le dispose est un safety net supplémentaire pour les arrêts gracieux.
- **Hive crash recovery** : Hive détecte automatiquement les frames incomplètes au prochain `openBox()` via CRC checksum, et tronque au dernier frame valide. Avec le `flush()` après chaque save, le worst case est de perdre l'écriture en cours au moment du SIGKILL — soit 1 seule entrée.

## References

- `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md` — Prior fix: Hive path, save-before-notify, reload(). **Pattern clé : les 3 bugs devaient être fixés ensemble.**
- `docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md` — Queue pattern for IPC reliability. **Pattern : queue dans SharedPrefs avant sendDataToMain.**
- `lib/core/session/session_manager.dart:22-27` — Silent catch block dans init()
- `lib/core/session/session_manager.dart:46` — Silent catch block dans reload()
- `lib/core/session/session.dart:89-113` — `_stripOrphanedLeadingMessages()` destructive mutation
- `lib/core/session/session.dart:37-51` — `getMessages()` appelle strip AVANT la copie
- `lib/core/agent/agent_loop.dart:226,265` — Only save points in processMessage()
- `lib/core/agent/agent_loop.dart:88` — Summarization sans save
- `lib/core/agent/agent_loop.dart:218` — Error path sans save
- `lib/providers/app_providers.dart:84-88` — sessionManagerProvider without onDispose
- [Hive Issue #414 — App killed while box open](https://github.com/isar/hive/issues/414)
- [Hive Issue #77 — Multi-isolate NOT supported](https://github.com/isar/hive/issues/77)
- [Box API docs — flush() = fsync](https://pub.dev/documentation/hive/latest/hive/Box-class.html)
