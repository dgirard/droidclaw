import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified storage service: SharedPreferences for config,
/// FlutterSecureStorage for API keys, path_provider for workspace.
class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  String? _workspacePath;

  StorageService({
    required SharedPreferences prefs,
    FlutterSecureStorage? secure,
    String? overrideWorkspacePath,
  })  : _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage(),
        _workspacePath = overrideWorkspacePath;

  // --- SharedPreferences (config, flags) ---

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);

  /// Remove every SharedPreferences entry (config, flags, caches).
  Future<bool> clearPrefs() => _prefs.clear();

  /// Store a JSON-serializable object.
  Future<bool> setJson(String key, Map<String, dynamic> json) =>
      _prefs.setString(key, jsonEncode(json));

  /// Retrieve a JSON object.
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // --- Secure Storage (API keys) ---

  Future<void> setSecure(String key, String value) =>
      _secure.write(key: key, value: value);

  Future<String?> getSecure(String key) => _secure.read(key: key);

  Future<void> deleteSecure(String key) => _secure.delete(key: key);

  /// Delete every secure-storage entry (all API keys, tokens, probe value).
  Future<void> deleteSecureAll() => _secure.deleteAll();

  // --- Workspace directory ---

  /// Get the workspace root directory, creating it if needed.
  Future<String> get workspacePath async {
    if (_workspacePath != null) return _workspacePath!;
    final appDir = await getApplicationDocumentsDirectory();
    final workspace = Directory('${appDir.path}/droidclaw_workspace');
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }
    _workspacePath = workspace.path;
    return _workspacePath!;
  }

  /// Ensure a subdirectory exists under workspace.
  Future<String> ensureSubdir(String subpath) async {
    final base = await workspacePath;
    final dir = Directory('$base/$subpath');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Read a file from workspace. Returns null if not found.
  Future<String?> readWorkspaceFile(String relativePath) async {
    final base = await workspacePath;
    final file = File('$base/$relativePath');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Write a file to workspace.
  Future<void> writeWorkspaceFile(
      String relativePath, String content) async {
    final base = await workspacePath;
    final file = File('$base/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// List files in a workspace subdirectory.
  Future<List<FileSystemEntity>> listWorkspaceDir(String relativePath) async {
    final base = await workspacePath;
    final dir = Directory('$base/$relativePath');
    if (!await dir.exists()) return [];
    return dir.listSync();
  }

  /// Delete a file from workspace.
  Future<void> deleteWorkspaceFile(String relativePath) async {
    final base = await workspacePath;
    final file = File('$base/$relativePath');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
