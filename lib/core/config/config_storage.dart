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

  /// Get API key for a provider from secure storage.
  Future<String?> getApiKey(String providerName) =>
      _storage.getSecure('api_key_$providerName');

  /// Save API key for a provider to secure storage.
  Future<void> setApiKey(String providerName, String apiKey) =>
      _storage.setSecure('api_key_$providerName', apiKey);

  /// Delete API key for a provider.
  Future<void> deleteApiKey(String providerName) =>
      _storage.deleteSecure('api_key_$providerName');

  /// Get Brave Search API key from secure storage.
  Future<String?> getBraveApiKey() => _storage.getSecure('brave_api_key');

  /// Save Brave Search API key to secure storage.
  Future<void> setBraveApiKey(String apiKey) =>
      _storage.setSecure('brave_api_key', apiKey);

  /// Get OpenRouteService API key from secure storage.
  Future<String?> getOrsApiKey() => _storage.getSecure('ors_api_key');

  /// Save OpenRouteService API key to secure storage.
  Future<void> setOrsApiKey(String apiKey) =>
      _storage.setSecure('ors_api_key', apiKey);

  /// Get SNCF API key from secure storage.
  Future<String?> getSncfApiKey() => _storage.getSecure('sncf_api_key');

  /// Save SNCF API key to secure storage.
  Future<void> setSncfApiKey(String apiKey) =>
      _storage.setSecure('sncf_api_key', apiKey);

  /// Get PRIM (IDFM) API key from secure storage.
  Future<String?> getPrimApiKey() => _storage.getSecure('prim_api_key');

  /// Save PRIM (IDFM) API key to secure storage.
  Future<void> setPrimApiKey(String apiKey) =>
      _storage.setSecure('prim_api_key', apiKey);

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
}
