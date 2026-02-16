import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/local/storage_service.dart';
import 'skill_loader.dart';

/// Installs and uninstalls skills from GitHub URLs.
class SkillInstaller {
  final StorageService _storage;
  final SkillLoader _loader;

  SkillInstaller(this._storage, this._loader);

  /// Install a skill from a GitHub URL.
  /// Expects a raw GitHub URL or converts a regular GitHub URL to raw.
  Future<String> install(String githubUrl) async {
    final rawUrl = _toRawUrl(githubUrl);

    final response = await http.get(Uri.parse(rawUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download skill: HTTP ${response.statusCode}');
    }

    final content = response.body;

    // Parse to validate and get the name
    final parsed = _parseSkillFile(content);
    if (parsed == null) {
      throw Exception(
          'Invalid skill file: missing frontmatter with name field');
    }

    final (name, _, _) = parsed;

    // Save to workspace/skills/
    final skillsDir = await _storage.ensureSubdir('skills');
    final file = File('$skillsDir/$name.md');
    await file.writeAsString(content);

    // Reload skills
    await _loader.loadAll();

    return name;
  }

  /// Uninstall a skill by name (workspace skills only).
  Future<void> uninstall(String name) async {
    final skill = _loader.getSkill(name);
    if (skill == null) {
      throw Exception('Skill not found: $name');
    }

    if (skill.source.name == 'builtin') {
      throw Exception('Cannot uninstall builtin skills');
    }

    final file = File(skill.path);
    if (await file.exists()) {
      await file.delete();
    }

    // Reload skills
    await _loader.loadAll();
  }

  /// Convert a GitHub URL to its raw content URL.
  String _toRawUrl(String url) {
    if (url.contains('raw.githubusercontent.com')) return url;

    // Convert github.com/user/repo/blob/branch/path → raw.githubusercontent.com/user/repo/branch/path
    final uri = Uri.parse(url);
    if (uri.host == 'github.com') {
      final segments = uri.pathSegments.toList();
      if (segments.length > 3 && segments[2] == 'blob') {
        segments.removeAt(2); // Remove 'blob'
        return 'https://raw.githubusercontent.com/${segments.join('/')}';
      }
    }
    return url;
  }

  (String, String, String)? _parseSkillFile(String content) {
    if (!content.startsWith('---')) return null;
    final endIndex = content.indexOf('---', 3);
    if (endIndex == -1) return null;

    final frontmatter = content.substring(3, endIndex).trim();
    final body = content.substring(endIndex + 3).trim();

    String? name;
    String? description;

    for (final line in frontmatter.split('\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 1).trim();
      if (key == 'name') name = value;
      if (key == 'description') description = value;
    }

    if (name == null || name.isEmpty) return null;
    return (name, description ?? '', body);
  }
}
