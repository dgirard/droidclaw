import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';

/// Reads secrets in the foreground-service isolate.
///
/// Runtime capability probe instead of a static assumption: the main isolate
/// writes a known value to FlutterSecureStorage
/// ([AppConstants.secureStorageProbeKey]); at service init [probe] tries to
/// read it back. If the read returns the expected value, this device's
/// service FlutterEngine CAN use secure storage — secrets are read directly
/// from it and the cleartext SharedPreferences mirrors are ignored (and
/// subsequently wiped by the main isolate via the persisted capability flag).
/// If the read throws or returns nothing, behavior falls back to the mirrors.
class ServiceSecretReader {
  ServiceSecretReader({
    required SharedPreferences prefs,
    FlutterSecureStorage? secure,
  })  : _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  bool _capable = false;

  /// Result of the last [probe] run.
  bool get isCapable => _capable;

  /// Run the capability probe and persist the result (a non-secret boolean)
  /// to SharedPreferences so the main isolate can stop writing — and wipe —
  /// cleartext mirrors once secure storage is proven to work here.
  Future<bool> probe() async {
    try {
      final value = await _secure.read(key: AppConstants.secureStorageProbeKey);
      _capable = value == AppConstants.secureStorageProbeValue;
    } catch (_) {
      _capable = false;
    }
    try {
      await _prefs.setBool(
          AppConstants.serviceSecureStorageCapableKey, _capable);
    } catch (_) {
      // Flag write is best-effort; worst case mirrors keep being written.
    }
    return _capable;
  }

  /// Read a secret: from secure storage when the probe succeeded, falling
  /// back to the cleartext SharedPreferences mirror ([mirrorKey]) otherwise
  /// (or when the secure read unexpectedly fails/returns nothing while a
  /// mirror exists).
  Future<String?> read({required String secureKey, String? mirrorKey}) async {
    if (_capable) {
      try {
        final value = await _secure.read(key: secureKey);
        if (value != null && value.isNotEmpty) return value;
      } catch (_) {
        // Fall through to mirror.
      }
    }
    if (mirrorKey == null) return null;
    final mirrored = _prefs.getString(mirrorKey);
    return (mirrored == null || mirrored.isEmpty) ? null : mirrored;
  }
}
