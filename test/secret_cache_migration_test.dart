import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/config/config_storage.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/shared/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ConfigStorage> buildStorage(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    return ConfigStorage(StorageService(prefs: sp));
  }

  group('runSecretCacheMigration', () {
    test('wipes cached secret mirrors but preserves non-secret cached values',
        () async {
      final cs = await buildStorage({
        AppConstants.cachedApiKeyKey: 'sk-old',
        AppConstants.cachedBraveApiKeyKey: 'brave-old',
        AppConstants.cachedEmbeddingApiKeyKey: 'emb-old',
        AppConstants.cachedProviderNameKey: 'anthropic',
        AppConstants.cachedWorkspacePathKey: '/ws',
      });

      await cs.runSecretCacheMigration();

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedBraveApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedEmbeddingApiKeyKey), isNull);
      // Non-secret cached values are needed by the service isolate and survive.
      expect(sp.getString(AppConstants.cachedProviderNameKey), 'anthropic');
      expect(sp.getString(AppConstants.cachedWorkspacePathKey), '/ws');
      expect(sp.getBool(AppConstants.secretsCacheMigratedKey), isTrue);
    });

    test('is idempotent — a second run does not wipe re-cached current keys',
        () async {
      final cs = await buildStorage({
        AppConstants.secretsCacheMigratedKey: true,
        AppConstants.cachedApiKeyKey: 'sk-current',
      });

      await cs.runSecretCacheMigration();

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(AppConstants.cachedApiKeyKey), 'sk-current');
    });
  });

  group('wipeCachedSecrets', () {
    test('removes every secret mirror', () async {
      final cs = await buildStorage({
        AppConstants.cachedApiKeyKey: 'a',
        AppConstants.cachedOrsApiKeyKey: 'b',
        AppConstants.cachedSncfApiKeyKey: 'c',
        AppConstants.cachedPrimApiKeyKey: 'd',
      });

      await cs.wipeCachedSecrets();

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedOrsApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedSncfApiKeyKey), isNull);
      expect(sp.getString(AppConstants.cachedPrimApiKeyKey), isNull);
    });
  });

  group('deleteApiKey', () {
    test('clears the cached provider-key mirror', () async {
      FlutterSecureStorage.setMockInitialValues({'api_key_anthropic': 'sk-x'});
      final cs = await buildStorage({
        AppConstants.cachedApiKeyKey: 'sk-x',
      });

      await cs.deleteApiKey('anthropic');

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(AppConstants.cachedApiKeyKey), isNull);
    });
  });
}
