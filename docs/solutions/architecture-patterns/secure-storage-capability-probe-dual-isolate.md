---
title: Self-resolving capability probe for FlutterSecureStorage in the service isolate
date: 2026-06-10
category: architecture-patterns
module: dual-isolate secrets
problem_type: architecture_pattern
component: background_job
severity: high
applies_when:
  - "A capability of the foreground-service FlutterEngine (Keystore, platform channel, plugin) is unknowable statically and varies by device/OS version"
  - "A security-sensitive fallback (cleartext mirror, broader permission) exists only because the preferred path might not work"
  - "Adding a new API key or secret that the service isolate must read"
tags: [flutter-secure-storage, dual-isolate, capability-probe, secrets, shared-preferences, keystore]
---

# Self-resolving capability probe for FlutterSecureStorage in the service isolate

## Context

DroidClaw's service isolate (foreground-service FlutterEngine running `BackgroundTaskHandler`) needs API keys. The codebase long asserted "no `FlutterSecureStorage` in the service isolate", so the main isolate mirrored every secret into cleartext `SharedPreferences` — a standing privacy liability. But the assertion was *statically unverifiable*: platform channels demonstrably work there (SharedPreferences does), and whether Keystore-backed secure storage works depends on the plugin version, engine registration, and device. Hardcoding either assumption is wrong for part of the fleet.

## Guidance

Replace the static assumption with a **runtime capability probe that self-resolves per device**:

1. **Main isolate writes a probe value** to secure storage on every cache refresh (`ServiceSecretCache.refresh()` writes `secure_storage_probe = probe_ok_v1`).
2. **Service isolate probes at startup** (`ServiceSecretReader.probe()`): reads the probe key, logs SUCCESS/FAILED prominently, and persists a **non-secret boolean capability flag** to SharedPreferences.
3. **All service-isolate secret reads go through one seam**: `reader.read(secureKey:, mirrorKey:)` — secure storage when capable, mirror fallback otherwise (also falls back when a capable read throws or returns empty).
4. **Main isolate reacts to the flag**: when `serviceSecureStorageCapable == true`, `refresh()` writes NO secret mirrors and **wipes existing ones**. Net effect: on capable devices the cleartext mirrors disappear automatically after the first service run; on incapable devices behavior is unchanged.

Two traps discovered in review, both fixed and pinned by tests:

- **Stale-flag lockout**: if the probe *write* fails (Keystore transiently down) while the persisted flag is still `true`, a naive implementation wipes the mirrors AND leaves secure storage unreadable — the service starts with no secrets at all. Rule: **when the probe write fails, do not trust the persisted flag for this refresh** — write mirrors unconditionally (`probeWritten` guard in `service_secret_cache.dart`).
- **Mirror without writer**: a `read(secureKey:, mirrorKey:)` call whose mirror key no code ever writes is a silent always-null path on probe-fail devices (the Telegram bot token had exactly this). Rule: every mirror key needs a writer in `refresh()`, an entry in the wipe list, and — for feature-gated secrets — gating on the feature flag so disabling the feature removes the mirror.

## Why This Matters

The pattern converts "we can't know, so assume the worst forever" into "one device run tells us, and the system upgrades itself". Privacy posture improves automatically where the platform allows it, with zero regression where it doesn't — and a single logcat line (`Secure-storage capability probe: SUCCESS/FAILED`) makes the active path diagnosable.

## When to Apply

- Adding any new secret the service isolate reads: add BOTH `AppConstants.secureXxxKeyKey` and `cachedXxxKeyKey`, a `mirror()` call in `ServiceSecretCache.refresh()`, and a `ServiceSecretReader.read()` call in `background_task_handler.dart` (see CLAUDE.md "API Key Pattern").
- Any other statically-unknowable engine capability where the fallback is costly (permissions, plugins): probe once, persist the verdict, route through one seam.

## Examples

Probe-aware read seam (service isolate):

```dart
final apiKey = await _secrets!.read(
  secureKey: AppConstants.secureApiKeyPrefix,
  mirrorKey: AppConstants.cachedApiKeyKey,
);
```

Stale-flag guard (main isolate):

```dart
var probeWritten = false;
try { await storage.writeSecureStorageProbe(); probeWritten = true; } catch (_) {}
final capable = probeWritten &&
    (prefs.getBool(AppConstants.serviceSecureStorageCapableKey) ?? false);
// capable → wipe mirrors and write none; otherwise → write mirrors
```

Tests: `test/security/secret_handling_test.dart` (probe success/fail/fallback, flag-transition wipe sequence, stale-flag lockout, per-key clear-on-delete).

## Related

- `docs/solutions/architecture/decouple-cron-from-telegram-autonomous-service.md` — established the SharedPreferences mirror pattern this demotes to fallback (its "no FlutterSecureStorage" claim is now superseded; flagged for refresh).
- `docs/solutions/architecture/enable-location-tools-in-service-isolate.md` — established that the service isolate is a full FlutterEngine with working platform channels (the premise making the probe worthwhile).
