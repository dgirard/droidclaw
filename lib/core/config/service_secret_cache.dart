import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';
import 'app_config.dart';
import 'config_storage.dart';

/// Refreshes the SharedPreferences cache the service isolate reads at init.
///
/// Non-secret values (provider name, workspace path, locale, KG + embedding
/// config) are always cached. Secret values (API keys) are only mirrored in
/// cleartext when the service isolate has NOT proven — via the capability
/// probe ([ConfigStorage.writeSecureStorageProbe] / `ServiceSecretReader`) —
/// that it can read FlutterSecureStorage directly. Once the probe succeeds,
/// secret mirrors stop being written and existing ones are wiped.
class ServiceSecretCache {
  ServiceSecretCache._();

  static Future<void> refresh({
    required SharedPreferences prefs,
    required ConfigStorage configStorage,
    required AppConfig config,
    required String workspacePath,
  }) async {
    // Pick up the capability flag the service isolate may have written.
    await prefs.reload();

    // Ensure the probe value exists in secure storage before the service
    // isolate runs its capability probe.
    try {
      await configStorage.writeSecureStorageProbe();
    } catch (_) {
      // Secure storage write failed — mirrors below still keep the service
      // isolate functional.
    }

    // --- Non-secret values: always cached. ---
    await prefs.setString(
        AppConstants.cachedProviderNameKey, config.agent.provider);
    await prefs.setString(AppConstants.cachedWorkspacePathKey, workspacePath);
    await prefs.setString(AppConstants.cachedLocaleKey, config.resolvedLocale);
    await prefs.setBool(
        AppConstants.cachedKnowledgeEnabledKey, config.knowledge.enabled);
    final kbLang = config.knowledge.kbLanguage;
    if (kbLang != null) {
      await prefs.setString(AppConstants.cachedKbLanguageKey, kbLang);
    } else {
      await prefs.remove(AppConstants.cachedKbLanguageKey);
    }
    await prefs.setString(
        AppConstants.cachedEmbeddingProviderKey, config.embedding.provider);
    await prefs.setString(
        AppConstants.cachedEmbeddingModelKey, config.embedding.model);
    await prefs.setInt(
        AppConstants.cachedEmbeddingDimensionsKey, config.embedding.dimensions);
    await prefs.setString(
        AppConstants.cachedEmbeddingApiBaseKey, config.embedding.apiBase);
    await prefs.setBool(
        AppConstants.cachedEmbeddingUseOwnKeyKey, config.embedding.useOwnApiKey);

    // --- Secret values: only mirrored when the service isolate cannot read
    // secure storage itself. ---
    if (configStorage.serviceSecureStorageCapable) {
      // Probe succeeded on this device: the service isolate reads secrets
      // directly from FlutterSecureStorage. Remove any cleartext leftovers.
      await configStorage.wipeCachedSecrets();
      return;
    }

    Future<void> mirror(String mirrorKey, String? value) async {
      if (value != null && value.isNotEmpty) {
        await prefs.setString(mirrorKey, value);
      } else {
        // Key deleted/empty — remove the stale mirror instead of skipping.
        await prefs.remove(mirrorKey);
      }
    }

    await mirror(AppConstants.cachedApiKeyKey,
        await configStorage.getApiKey(config.agent.provider));
    await mirror(
        AppConstants.cachedBraveApiKeyKey, await configStorage.getBraveApiKey());
    await mirror(
        AppConstants.cachedOrsApiKeyKey, await configStorage.getOrsApiKey());
    await mirror(
        AppConstants.cachedSncfApiKeyKey, await configStorage.getSncfApiKey());
    await mirror(
        AppConstants.cachedPrimApiKeyKey, await configStorage.getPrimApiKey());
    await mirror(AppConstants.cachedEmbeddingApiKeyKey,
        await configStorage.getEmbeddingApiKey());
  }
}
