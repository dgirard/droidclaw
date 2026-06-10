import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/config/config_storage.dart';
import 'package:droidclaw/core/config/service_secret_cache.dart';
import 'package:droidclaw/core/services/data_wiper.dart';
import 'package:droidclaw/core/services/service_secret_reader.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/hive_test_harness.dart';

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
      expect(sessions.getAllSessions(), isEmpty);
      // SharedPreferences config gone (crons, telegram, onboarding flag).
      expect(sp.getString(AppConstants.cronDefinitionsKey), isNull);
      expect(sp.getBool(AppConstants.telegramBotEnabledKey), isNull);
      expect(sp.getBool(AppConstants.onboardingCompleteKey), isNull);
      // Trace + log files cleared.
      expect(tracesCleared, isTrue);
      expect(logsCleared, isTrue);
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
