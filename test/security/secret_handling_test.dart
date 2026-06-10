import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/config/config_storage.dart';
import 'package:droidclaw/core/config/service_secret_cache.dart';
import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';
import 'package:droidclaw/core/services/data_wiper.dart';
import 'package:droidclaw/core/services/service_secret_reader.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/hive_test_harness.dart';

/// FlutterSecureStorage stand-in whose every call fails — a device whose
/// Keystore is unreadable in this engine (the probe-fail service isolate).
class _UnreadableSecureStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<String?>.error(StateError('keystore unreadable'));
}

/// FlutterSecureStorage stand-in where reads succeed (backed by [store]) but
/// every WRITE throws — a Keystore that still decrypts existing entries but
/// can no longer store new ones (the stale-capability-flag lockout case).
class _WriteFailsSecureStorage implements FlutterSecureStorage {
  _WriteFailsSecureStorage(this.store);

  final Map<String, String> store;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return Future<String?>.value(
          store[invocation.namedArguments[#key] as String]);
    }
    if (invocation.memberName == #write) {
      return Future<void>.error(StateError('keystore write failed'));
    }
    return super.noSuchMethod(invocation);
  }
}

/// StorageService whose secure-storage bulk delete fails (Keystore down
/// while the user runs "erase all data").
class _SecureWipeFailsStorage extends StorageService {
  _SecureWipeFailsStorage({required super.prefs})
      : super(overrideWorkspacePath: '/ws');

  @override
  Future<void> deleteSecureAll() async {
    throw StateError('keystore down');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ConfigStorage, StorageService, SharedPreferences)> buildStorage({
    Map<String, Object> prefs = const {},
    Map<String, String> secure = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    FlutterSecureStorage.setMockInitialValues(Map.of(secure));
    final sp = await SharedPreferences.getInstance();
    final storage = StorageService(prefs: sp, overrideWorkspacePath: '/ws');
    return (ConfigStorage(storage), storage, sp);
  }

  group('clear-on-delete (every key type removes secure entry + mirror)', () {
    test('deleteApiKey removes secure entry and LLM mirror', () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedApiKeyKey: 'sk-x'},
        secure: {'api_key_anthropic': 'sk-x'},
      );

      await cs.deleteApiKey('anthropic');

      expect(await cs.getApiKey('anthropic'), isNull);
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
    });

    test('setApiKey with empty value removes secure entry and mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedApiKeyKey: 'sk-x'},
        secure: {'api_key_openrouter': 'sk-x'},
      );

      await cs.setApiKey('openrouter', '');

      expect(await cs.getApiKey('openrouter'), isNull);
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
    });

    test('setBraveApiKey with empty value removes secure entry and mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedBraveApiKeyKey: 'brave-x'},
        secure: {AppConstants.secureBraveApiKeyKey: 'brave-x'},
      );

      await cs.setBraveApiKey('');

      expect(await cs.getBraveApiKey(), isNull);
      expect(sp.getString(AppConstants.cachedBraveApiKeyKey), isNull);
    });

    test('setOrsApiKey with empty value removes secure entry and mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedOrsApiKeyKey: 'ors-x'},
        secure: {AppConstants.secureOrsApiKeyKey: 'ors-x'},
      );

      await cs.setOrsApiKey('');

      expect(await cs.getOrsApiKey(), isNull);
      expect(sp.getString(AppConstants.cachedOrsApiKeyKey), isNull);
    });

    test('setSncfApiKey with empty value removes secure entry and mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedSncfApiKeyKey: 'sncf-x'},
        secure: {AppConstants.secureSncfApiKeyKey: 'sncf-x'},
      );

      await cs.setSncfApiKey('');

      expect(await cs.getSncfApiKey(), isNull);
      expect(sp.getString(AppConstants.cachedSncfApiKeyKey), isNull);
    });

    test('setPrimApiKey with empty value removes secure entry and mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedPrimApiKeyKey: 'prim-x'},
        secure: {AppConstants.securePrimApiKeyKey: 'prim-x'},
      );

      await cs.setPrimApiKey('');

      expect(await cs.getPrimApiKey(), isNull);
      expect(sp.getString(AppConstants.cachedPrimApiKeyKey), isNull);
    });

    test('setEmbeddingApiKey with empty value removes secure entry and mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedEmbeddingApiKeyKey: 'emb-x'},
        secure: {AppConstants.secureEmbeddingApiKeyKey: 'emb-x'},
      );

      await cs.setEmbeddingApiKey('');

      expect(await cs.getEmbeddingApiKey(), isNull);
      expect(sp.getString(AppConstants.cachedEmbeddingApiKeyKey), isNull);
    });

    test('non-empty set still stores the key in secure storage', () async {
      final (cs, _, _) = await buildStorage();

      await cs.setBraveApiKey('brave-new');

      expect(await cs.getBraveApiKey(), 'brave-new');
    });

    test('wipeCachedSecrets covers the Telegram bot token mirror', () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedTelegramBotTokenKey: 'tg-x'},
      );

      await cs.wipeCachedSecrets();

      expect(sp.getString(AppConstants.cachedTelegramBotTokenKey), isNull);
    });
  });

  group('ServiceSecretCache.refresh (mirror writing)', () {
    test('re-caching after a key became empty removes the stale mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {
          // Stale mirrors from keys that no longer exist in secure storage.
          AppConstants.cachedBraveApiKeyKey: 'brave-stale',
          AppConstants.cachedOrsApiKeyKey: 'ors-stale',
          AppConstants.cachedSncfApiKeyKey: 'sncf-stale',
          AppConstants.cachedPrimApiKeyKey: 'prim-stale',
          AppConstants.cachedEmbeddingApiKeyKey: 'emb-stale',
        },
        secure: {
          // Only the LLM key still exists.
          'api_key_openrouter': 'sk-current',
        },
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(sp.getString(AppConstants.cachedApiKeyKey), 'sk-current');
      expect(sp.getString(AppConstants.cachedBraveApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedOrsApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedSncfApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedPrimApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedEmbeddingApiKeyKey), isNull);
    });

    test('capability flag true: writes no secret mirrors and wipes existing',
        () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {
          AppConstants.serviceSecureStorageCapableKey: true,
          AppConstants.cachedApiKeyKey: 'sk-leftover',
          AppConstants.cachedBraveApiKeyKey: 'brave-leftover',
        },
        secure: {
          'api_key_openrouter': 'sk-current',
          AppConstants.secureBraveApiKeyKey: 'brave-current',
        },
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      // No secret in SharedPreferences at all.
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedBraveApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedOrsApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedSncfApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedPrimApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedEmbeddingApiKeyKey), isNull);
      // Non-secret values still cached for the service isolate.
      expect(sp.getString(AppConstants.cachedProviderNameKey),
          AppConstants.defaultProvider);
      expect(sp.getString(AppConstants.cachedWorkspacePathKey), '/ws');
    });

    test('probe-fail device: refresh() mirrors the Telegram bot token and '
        'ServiceSecretReader resolves it from the mirror', () async {
      // Capability flag absent (service probe never succeeded) → mirrors on.
      // The Telegram mirror is additionally gated on the bot being ENABLED.
      final (cs, _, sp) = await buildStorage(
        prefs: {AppConstants.telegramBotEnabledKey: true},
        secure: {
          'api_key_openrouter': 'sk-current',
          AppConstants.telegramBotTokenKey: 'tg-token',
        },
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(sp.getString(AppConstants.cachedTelegramBotTokenKey), 'tg-token');

      // The service isolate on that device cannot read secure storage at
      // all — the token must still resolve through the mirror.
      final reader = ServiceSecretReader(
        prefs: sp,
        secure: _UnreadableSecureStorage(),
      );
      expect(await reader.probe(), isFalse);
      expect(
        await reader.read(
          secureKey: AppConstants.telegramBotTokenKey,
          mirrorKey: AppConstants.cachedTelegramBotTokenKey,
        ),
        'tg-token',
      );
    });

    test('Telegram bot DISABLED on a probe-fail device: refresh() writes no '
        'token mirror and removes a stale one', () async {
      // A token can remain in secure storage after the bot is disabled (the
      // user may re-enable later). Disabled → the service isolate has no use
      // for it, so no cleartext mirror may exist.
      final (cs, _, sp) = await buildStorage(
        prefs: {
          AppConstants.telegramBotEnabledKey: false,
          // Stale mirror left from when the bot was enabled.
          AppConstants.cachedTelegramBotTokenKey: 'tg-stale',
        },
        secure: {
          'api_key_openrouter': 'sk-current',
          AppConstants.telegramBotTokenKey: 'tg-token',
        },
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(sp.getString(AppConstants.cachedTelegramBotTokenKey), isNull,
          reason: 'disabled bot: the stale cleartext mirror must be removed');
      // The other mirrors are unaffected by the Telegram gate.
      expect(sp.getString(AppConstants.cachedApiKeyKey), 'sk-current');
    });

    test('Telegram enabled flag ABSENT (never configured): refresh() treats '
        'it as disabled and writes no token mirror', () async {
      final (cs, _, sp) = await buildStorage(
        secure: {
          'api_key_openrouter': 'sk-current',
          AppConstants.telegramBotTokenKey: 'tg-token',
        },
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(sp.getString(AppConstants.cachedTelegramBotTokenKey), isNull);
    });

    test('capability-true: no Telegram token mirror is written and an '
        'existing one is wiped', () async {
      final (cs, _, sp) = await buildStorage(
        prefs: {
          AppConstants.serviceSecureStorageCapableKey: true,
          AppConstants.cachedTelegramBotTokenKey: 'tg-leftover',
        },
        secure: {
          'api_key_openrouter': 'sk-current',
          AppConstants.telegramBotTokenKey: 'tg-token',
        },
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(sp.getString(AppConstants.cachedTelegramBotTokenKey), isNull);
    });

    test('stale capable=true flag is not trusted when the probe WRITE fails: '
        'mirrors are written, not wiped', () async {
      // Keystore reads still work, writes fail (e.g. Keystore degraded after
      // an OS update). The persisted capable=true flag is stale: if it were
      // trusted, refresh() would wipe the mirrors and the service isolate —
      // which may no longer read secure storage either — would start with NO
      // secrets anywhere.
      SharedPreferences.setMockInitialValues({
        AppConstants.serviceSecureStorageCapableKey: true,
        AppConstants.cachedApiKeyKey: 'sk-old-mirror',
        AppConstants.telegramBotEnabledKey: true,
      });
      final sp = await SharedPreferences.getInstance();
      final storage = StorageService(
        prefs: sp,
        secure: _WriteFailsSecureStorage({
          'api_key_openrouter': 'sk-current',
          AppConstants.telegramBotTokenKey: 'tg-token',
        }),
        overrideWorkspacePath: '/ws',
      );
      final cs = ConfigStorage(storage);

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(sp.getString(AppConstants.cachedApiKeyKey), 'sk-current');
      expect(sp.getString(AppConstants.cachedTelegramBotTokenKey), 'tg-token');
    });

    test('flag transition sequence: no flag → mirrors written; flag set by '
        'the service probe → next refresh removes every secret mirror',
        () async {
      final (cs, _, sp) = await buildStorage(
        // Telegram enabled: its mirror participates like every other secret.
        prefs: {AppConstants.telegramBotEnabledKey: true},
        secure: {
          'api_key_openrouter': 'sk-current',
          AppConstants.secureBraveApiKeyKey: 'brave-x',
          AppConstants.secureOrsApiKeyKey: 'ors-x',
          AppConstants.secureSncfApiKeyKey: 'sncf-x',
          AppConstants.securePrimApiKeyKey: 'prim-x',
          AppConstants.secureEmbeddingApiKeyKey: 'emb-x',
          AppConstants.telegramBotTokenKey: 'tg-x',
        },
      );

      const mirrorKeys = [
        AppConstants.cachedApiKeyKey,
        AppConstants.cachedBraveApiKeyKey,
        AppConstants.cachedOrsApiKeyKey,
        AppConstants.cachedSncfApiKeyKey,
        AppConstants.cachedPrimApiKeyKey,
        AppConstants.cachedEmbeddingApiKeyKey,
        AppConstants.cachedTelegramBotTokenKey,
      ];

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );
      for (final key in mirrorKeys) {
        expect(sp.getString(key), isNotNull,
            reason: '$key must be mirrored while the flag is unset');
      }

      // The service isolate's probe succeeds and persists the flag.
      await sp.setBool(AppConstants.serviceSecureStorageCapableKey, true);

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );
      for (final key in mirrorKeys) {
        expect(sp.getString(key), isNull,
            reason: '$key must be wiped once the device is capable');
      }
    });

    test('writes the secure-storage probe value for the service isolate',
        () async {
      final (cs, storage, sp) = await buildStorage(
        secure: {'api_key_openrouter': 'sk-current'},
      );

      await ServiceSecretCache.refresh(
        prefs: sp,
        configStorage: cs,
        config: AppConfig.defaults(),
        workspacePath: '/ws',
      );

      expect(await storage.getSecure(AppConstants.secureStorageProbeKey),
          AppConstants.secureStorageProbeValue);
    });
  });

  group('ServiceSecretReader (capability probe)', () {
    test('probe succeeds: reads secrets from secure storage, persists flag',
        () async {
      final (_, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedBraveApiKeyKey: 'brave-mirror-stale'},
        secure: {
          AppConstants.secureStorageProbeKey:
              AppConstants.secureStorageProbeValue,
          AppConstants.secureBraveApiKeyKey: 'brave-secure',
        },
      );

      final reader = ServiceSecretReader(prefs: sp);
      final capable = await reader.probe();

      expect(capable, isTrue);
      expect(sp.getBool(AppConstants.serviceSecureStorageCapableKey), isTrue);
      expect(
        await reader.read(
          secureKey: AppConstants.secureBraveApiKeyKey,
          mirrorKey: AppConstants.cachedBraveApiKeyKey,
        ),
        'brave-secure',
      );
    });

    test('probe fails (value missing): falls back to mirror, persists flag',
        () async {
      final (_, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedBraveApiKeyKey: 'brave-mirror'},
        secure: {AppConstants.secureBraveApiKeyKey: 'brave-secure'},
      );

      final reader = ServiceSecretReader(prefs: sp);
      final capable = await reader.probe();

      expect(capable, isFalse);
      expect(sp.getBool(AppConstants.serviceSecureStorageCapableKey), isFalse);
      expect(
        await reader.read(
          secureKey: AppConstants.secureBraveApiKeyKey,
          mirrorKey: AppConstants.cachedBraveApiKeyKey,
        ),
        'brave-mirror',
      );
    });

    test('capable but secure key absent: falls back to mirror', () async {
      final (_, _, sp) = await buildStorage(
        prefs: {AppConstants.cachedOrsApiKeyKey: 'ors-mirror'},
        secure: {
          AppConstants.secureStorageProbeKey:
              AppConstants.secureStorageProbeValue,
        },
      );

      final reader = ServiceSecretReader(prefs: sp);
      await reader.probe();

      expect(
        await reader.read(
          secureKey: AppConstants.secureOrsApiKeyKey,
          mirrorKey: AppConstants.cachedOrsApiKeyKey,
        ),
        'ors-mirror',
      );
    });
  });

  group('DataWiper.wipeAll', () {
    test('leaves no secret, session, or cached data readable', () async {
      final hive = await HiveTestHarness.create();
      addTearDown(hive.dispose);

      final (cs, storage, sp) = await buildStorage(
        prefs: {
          AppConstants.cachedApiKeyKey: 'sk-x',
          AppConstants.cachedBraveApiKeyKey: 'brave-x',
          AppConstants.cronDefinitionsKey: '[]',
          AppConstants.telegramBotEnabledKey: true,
          AppConstants.onboardingCompleteKey: true,
        },
        secure: {
          'api_key_anthropic': 'sk-x',
          AppConstants.secureBraveApiKeyKey: 'brave-x',
          AppConstants.telegramBotTokenKey: 'tg-token',
        },
      );

      final sessions = SessionManager();
      await sessions.init();
      await sessions.save(sessions.getOrCreate('default'));

      var tracesCleared = false;
      var logsCleared = false;
      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        sessions: sessions,
        clearLlmTraces: () async => tracesCleared = true,
        clearLogs: () async => logsCleared = true,
      );

      final failures = await wiper.wipeAll();

      expect(failures, isEmpty);
      // Secrets gone (secure storage + mirrors).
      expect(await cs.getApiKey('anthropic'), isNull);
      expect(await cs.getBraveApiKey(), isNull);
      expect(await storage.getSecure(AppConstants.telegramBotTokenKey), isNull);
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedBraveApiKeyKey), isNull);
      // Sessions gone.
      expect(sessions.getAllSessionMetadata(), isEmpty);
      // SharedPreferences config gone (crons, telegram, onboarding flag).
      expect(sp.getString(AppConstants.cronDefinitionsKey), isNull);
      expect(sp.getBool(AppConstants.telegramBotEnabledKey), isNull);
      expect(sp.getBool(AppConstants.onboardingCompleteKey), isNull);
      // Trace + log files cleared.
      expect(tracesCleared, isTrue);
      expect(logsCleared, isTrue);
    });

    test('degraded sessions box (closed handle): wipeAll records the '
        'sessions failure AND deletes the box files anyway', () async {
      final hive = await HiveTestHarness.create();
      addTearDown(hive.dispose);

      final (cs, storage, _) = await buildStorage();

      final sessions = SessionManager();
      await sessions.init();
      await sessions.save(sessions.getOrCreate('default'));
      final boxFile = File('${hive.dir.path}/${SessionManager.boxName}.hive');
      expect(boxFile.existsSync(), isTrue,
          reason: 'precondition: the persisted box file exists on disk');

      // Degrade the manager: its handle is now closed (the reload-recovery
      // end state), so deleteAllSessions cannot reach the on-disk records.
      await Hive.close();

      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        sessions: sessions,
        sessionsBoxPath: '${hive.dir.path}/${SessionManager.boxName}',
      );

      final failures = await wiper.wipeAll();

      expect(failures, contains('sessions'),
          reason: 'the degraded box clear must be reported, not silently '
              'counted as success');
      // The file-level fallback still removed the conversations from disk.
      expect(boxFile.existsSync(), isFalse);
      expect(
          File('${hive.dir.path}/${SessionManager.boxName}.lock').existsSync(),
          isFalse);
    });

    test('healthy sessions box: wipeAll also removes the box file set '
        '(no recoverable bytes left behind)', () async {
      final hive = await HiveTestHarness.create();
      addTearDown(hive.dispose);

      final (cs, storage, _) = await buildStorage();

      final sessions = SessionManager();
      await sessions.init();
      await sessions.save(sessions.getOrCreate('default'));
      final boxFile = File('${hive.dir.path}/${SessionManager.boxName}.hive');
      expect(boxFile.existsSync(), isTrue);

      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        sessions: sessions,
        sessionsBoxPath: '${hive.dir.path}/${SessionManager.boxName}',
      );

      final failures = await wiper.wipeAll();

      expect(failures, isEmpty);
      expect(sessions.getAllSessionMetadata(), isEmpty);
      expect(boxFile.existsSync(), isFalse);
    });

    test('deletes the knowledge DB file when no service is open', () async {
      final hive = await HiveTestHarness.create();
      addTearDown(hive.dispose);

      final dbFile = '${hive.dir.path}/knowledge_graph.db';
      // Create fake DB files (main + WAL sidecar).
      await File(dbFile).writeAsString('db');
      await File('$dbFile-wal').writeAsString('wal');

      final (cs, storage, _) = await buildStorage();
      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        knowledgeDbPath: dbFile,
      );

      final failures = await wiper.wipeAll();

      expect(failures, isEmpty);
      expect(File(dbFile).existsSync(), isFalse);
      expect(File('$dbFile-wal').existsSync(), isFalse);
    });

    test('wipes workspace contents (memory notes, skills, files) but keeps '
        'the directory', () async {
      final workspace =
          await Directory.systemTemp.createTemp('wiper_workspace_');
      addTearDown(() async {
        if (await workspace.exists()) {
          await workspace.delete(recursive: true);
        }
      });

      // Memory notes (personal facts), a skills artifact, a file-tool file.
      await Directory('${workspace.path}/memory').create();
      await File('${workspace.path}/memory/MEMORY.md')
          .writeAsString('User lives in Paris');
      await Directory('${workspace.path}/skills/my_skill')
          .create(recursive: true);
      await File('${workspace.path}/skills/my_skill/SKILL.md')
          .writeAsString('skill');
      await File('${workspace.path}/notes.txt').writeAsString('secret note');

      final (cs, storage, _) = await buildStorage();
      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        workspacePath: workspace.path,
      );

      final failures = await wiper.wipeAll();

      expect(failures, isEmpty);
      // Directory survives (tools stay functional), contents are gone.
      expect(workspace.existsSync(), isTrue);
      expect(workspace.listSync(), isEmpty);
    });

    test('deletes the knowledge DB file set even when a live KnowledgeService '
        'is open (DELETE-d rows must not stay recoverable in the pages)',
        () async {
      final dir = await Directory.systemTemp.createTemp('wiper_kg_live_');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final dbFile = File('${dir.path}/knowledge_graph.db');
      final db = KnowledgeGraphDB.forExecutor(NativeDatabase(dbFile));
      final knowledge = KnowledgeService(db: db);
      // Touch the DB so the file (and its WAL sidecar) exists on disk and
      // the connection is live.
      await db.customSelect('SELECT 1').get();
      expect(dbFile.existsSync(), isTrue);

      final (cs, storage, _) = await buildStorage();
      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        knowledge: knowledge,
        knowledgeDbPath: dbFile.path,
      );

      final failures = await wiper.wipeAll();

      expect(failures, isEmpty);
      expect(dbFile.existsSync(), isFalse);
      expect(File('${dbFile.path}-wal').existsSync(), isFalse);
      expect(File('${dbFile.path}-shm').existsSync(), isFalse);
      expect(File('${dbFile.path}-journal').existsSync(), isFalse);
    });

    test('an early-step failure (deleteSecureAll throws) is reported and '
        'every downstream step still runs', () async {
      final hive = await HiveTestHarness.create();
      addTearDown(hive.dispose);

      SharedPreferences.setMockInitialValues({
        AppConstants.cronDefinitionsKey: '[]',
        AppConstants.onboardingCompleteKey: true,
      });
      final sp = await SharedPreferences.getInstance();
      final storage = _SecureWipeFailsStorage(prefs: sp);
      final cs = ConfigStorage(storage);

      final sessions = SessionManager();
      await sessions.init();
      await sessions.save(sessions.getOrCreate('default'));

      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        sessions: sessions,
      );

      final failures = await wiper.wipeAll();

      expect(failures, contains('secure_storage'));
      expect(failures, hasLength(1),
          reason: 'only the secure-storage step may fail');
      // Downstream steps completed despite the early failure.
      expect(sessions.getAllSessionMetadata(), isEmpty);
      expect(sp.getString(AppConstants.cronDefinitionsKey), isNull);
      expect(sp.getBool(AppConstants.onboardingCompleteKey), isNull);
    });

    test('a failing step does not prevent the others from running', () async {
      final (cs, storage, sp) = await buildStorage(
        prefs: {AppConstants.cachedApiKeyKey: 'sk-x'},
        secure: {'api_key_anthropic': 'sk-x'},
      );

      final wiper = DataWiper(
        storage: storage,
        configStorage: cs,
        clearLlmTraces: () async => throw StateError('boom'),
      );

      final failures = await wiper.wipeAll();

      expect(failures, ['llm_traces']);
      expect(await cs.getApiKey('anthropic'), isNull);
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
    });
  });
}
