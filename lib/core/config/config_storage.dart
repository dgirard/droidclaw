import 'dart:convert';

import '../../data/local/storage_service.dart';
import '../../shared/constants.dart';
import 'app_config.dart';
import 'cron_config.dart';

/// Loads and saves AppConfig via StorageService.
class ConfigStorage {
  final StorageService _storage;

  ConfigStorage(this._storage);

  /// Load config from SharedPreferences. Returns defaults if none saved.
  AppConfig load() {
    final json = _storage.getJson(AppConstants.configKey);
    if (json == null) return AppConfig.defaults();
    return AppConfig.fromJson(json);
  }

  /// Save config to SharedPreferences.
  Future<void> save(AppConfig config) async {
    await _storage.setJson(AppConstants.configKey, config.toJson());
  }

  /// Save a secret to secure storage, or delete it (and its cleartext
  /// SharedPreferences mirror) when [value] is empty. Putting mirror removal
  /// here means no call site (config screens, onboarding) can forget it.
  Future<void> _setOrDeleteSecret(
      String secureKey, String mirrorKey, String value) async {
    if (value.trim().isEmpty) {
      await _deleteSecret(secureKey, mirrorKey);
    } else {
      await _storage.setSecure(secureKey, value);
    }
  }

  /// Delete a secret from secure storage AND its SharedPreferences mirror so
  /// a deleted key never lingers in cleartext for the service isolate.
  Future<void> _deleteSecret(String secureKey, String mirrorKey) async {
    await _storage.deleteSecure(secureKey);
    await _storage.remove(mirrorKey);
  }

  /// Get API key for a provider from secure storage.
  Future<String?> getApiKey(String providerName) =>
      _storage.getSecure('${AppConstants.secureApiKeyPrefix}$providerName');

  /// Save API key for a provider to secure storage.
  /// An empty value deletes the key and its cleartext mirror.
  Future<void> setApiKey(String providerName, String apiKey) =>
      _setOrDeleteSecret('${AppConstants.secureApiKeyPrefix}$providerName',
          AppConstants.cachedApiKeyKey, apiKey);

  /// Delete API key for a provider, including its cleartext mirror.
  Future<void> deleteApiKey(String providerName) => _deleteSecret(
      '${AppConstants.secureApiKeyPrefix}$providerName',
      AppConstants.cachedApiKeyKey);

  /// Get Brave Search API key from secure storage.
  Future<String?> getBraveApiKey() =>
      _storage.getSecure(AppConstants.secureBraveApiKeyKey);

  /// Save Brave Search API key to secure storage.
  /// An empty value deletes the key and its cleartext mirror.
  Future<void> setBraveApiKey(String apiKey) => _setOrDeleteSecret(
      AppConstants.secureBraveApiKeyKey,
      AppConstants.cachedBraveApiKeyKey,
      apiKey);

  /// Get OpenRouteService API key from secure storage.
  Future<String?> getOrsApiKey() =>
      _storage.getSecure(AppConstants.secureOrsApiKeyKey);

  /// Save OpenRouteService API key to secure storage.
  /// An empty value deletes the key and its cleartext mirror.
  Future<void> setOrsApiKey(String apiKey) => _setOrDeleteSecret(
      AppConstants.secureOrsApiKeyKey,
      AppConstants.cachedOrsApiKeyKey,
      apiKey);

  /// Get SNCF API key from secure storage.
  Future<String?> getSncfApiKey() =>
      _storage.getSecure(AppConstants.secureSncfApiKeyKey);

  /// Save SNCF API key to secure storage.
  /// An empty value deletes the key and its cleartext mirror.
  Future<void> setSncfApiKey(String apiKey) => _setOrDeleteSecret(
      AppConstants.secureSncfApiKeyKey,
      AppConstants.cachedSncfApiKeyKey,
      apiKey);

  /// Get PRIM (IDFM) API key from secure storage.
  Future<String?> getPrimApiKey() =>
      _storage.getSecure(AppConstants.securePrimApiKeyKey);

  /// Save PRIM (IDFM) API key to secure storage.
  /// An empty value deletes the key and its cleartext mirror.
  Future<void> setPrimApiKey(String apiKey) => _setOrDeleteSecret(
      AppConstants.securePrimApiKeyKey,
      AppConstants.cachedPrimApiKeyKey,
      apiKey);

  /// Get embedding provider API key from secure storage.
  Future<String?> getEmbeddingApiKey() =>
      _storage.getSecure(AppConstants.secureEmbeddingApiKeyKey);

  /// Save embedding provider API key to secure storage.
  /// An empty value deletes the key and its cleartext mirror.
  Future<void> setEmbeddingApiKey(String apiKey) => _setOrDeleteSecret(
      AppConstants.secureEmbeddingApiKeyKey,
      AppConstants.cachedEmbeddingApiKeyKey,
      apiKey);

  /// Write the capability-probe value to secure storage. The service isolate
  /// reads it back to decide whether it can use secure storage directly
  /// instead of the cleartext SharedPreferences mirrors.
  Future<void> writeSecureStorageProbe() => _storage.setSecure(
      AppConstants.secureStorageProbeKey, AppConstants.secureStorageProbeValue);

  /// Whether the service isolate proved (via the probe) that it can read
  /// FlutterSecureStorage directly. When true, no cleartext secret mirrors
  /// are written.
  bool get serviceSecureStorageCapable =>
      _storage.getBool(AppConstants.serviceSecureStorageCapableKey) ?? false;

  /// Check if onboarding has been completed.
  bool get isOnboardingComplete =>
      _storage.getBool(AppConstants.onboardingCompleteKey) ?? false;

  /// Mark onboarding as complete.
  Future<void> setOnboardingComplete() =>
      _storage.setBool(AppConstants.onboardingCompleteKey, true);

  /// Load cron definitions from SharedPreferences.
  List<CronDefinition> getCronDefinitions() {
    final raw = _storage.getString(AppConstants.cronDefinitionsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => CronDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Save cron definitions to SharedPreferences.
  Future<void> saveCronDefinitions(List<CronDefinition> crons) =>
      _storage.setString(
        AppConstants.cronDefinitionsKey,
        jsonEncode(crons.map((c) => c.toJson()).toList()),
      );

  /// Get last dream timestamp (epoch seconds).
  int? get lastDreamAt {
    final raw = _storage.getString(AppConstants.lastDreamAtKey);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  /// Save last dream timestamp (epoch seconds).
  Future<void> setLastDreamAt(int epochSeconds) =>
      _storage.setString(AppConstants.lastDreamAtKey, epochSeconds.toString());

  /// SharedPreferences keys that mirror a secret value for the service isolate.
  /// These must never outlive the secure-storage key they mirror.
  static const List<String> _cachedSecretKeys = [
    AppConstants.cachedApiKeyKey,
    AppConstants.cachedBraveApiKeyKey,
    AppConstants.cachedOrsApiKeyKey,
    AppConstants.cachedSncfApiKeyKey,
    AppConstants.cachedPrimApiKeyKey,
    AppConstants.cachedEmbeddingApiKeyKey,
  ];

  /// Remove every cleartext secret mirror from SharedPreferences. The next
  /// service start re-caches only the keys that still exist in secure storage,
  /// so deleted keys do not survive.
  Future<void> wipeCachedSecrets() async {
    for (final key in _cachedSecretKeys) {
      await _storage.remove(key);
    }
  }

  /// One-time migration for installs that pre-date clear-on-delete: earlier
  /// versions wrote cleartext key mirrors to SharedPreferences and never
  /// cleared them, so stale/rotated keys could linger indefinitely. Wipe them
  /// once on first launch after the update; current keys are re-cached on the
  /// next service start. Runs before the service isolate starts.
  Future<void> runSecretCacheMigration() async {
    if (_storage.getBool(AppConstants.secretsCacheMigratedKey) ?? false) return;
    await wipeCachedSecrets();
    await _storage.setBool(AppConstants.secretsCacheMigratedKey, true);
  }
}
