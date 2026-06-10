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
    var probeWritten = true;
    try {
      await configStorage.writeSecureStorageProbe();
    } catch (_) {
      // Secure storage write failed (e.g. Keystore down) — mirrors below
      // still keep the service isolate functional.
      probeWritten = false;
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
    //
    // The persisted capability flag is only trusted when the probe value was
    // actually (re)written above: if secure storage failed the WRITE right
    // now, a stale `capable=true` flag (owned by the service-side probe, so
    // not reset here) would otherwise wipe the mirrors AND leave the service
    // isolate unable to read secure storage — no secrets anywhere. In that
    // case, treat the device as not-capable for this refresh and write the
    // mirrors unconditionally.
    if (probeWritten && configStorage.serviceSecureStorageCapable) {
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
    // The Telegram token is only needed by the service isolate while the bot
    // is enabled. When disabled, pass null through the same mirror() path so
    // a stale cleartext mirror is removed instead of left (or re-written).
    final telegramEnabled =
        prefs.getBool(AppConstants.telegramBotEnabledKey) ?? false;
    await mirror(
        AppConstants.cachedTelegramBotTokenKey,
        telegramEnabled ? await configStorage.getTelegramBotToken() : null);
  }
}
