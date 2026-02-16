import 'dart:io';

import 'package:flutter/services.dart';

import '../../data/local/storage_service.dart';
import 'skill.dart';

/// Three-tier skill loader: builtin (assets) → global → workspace.
class SkillLoader {
  final StorageService _storage;
  final List<SkillInfo> _skills = [];
  bool _loaded = false;

  SkillLoader(this._storage);

  /// Load all skills from all tiers.
  Future<void> loadAll() async {
    _skills.clear();

    // 1. Builtin skills from Flutter assets
    await _loadBuiltinSkills();

    // 2. Global skills from ~/.droidclaw/skills/
    await _loadDirectorySkills(
      _globalSkillsPath(),
      SkillSource.global,
    );

    // 3. Workspace skills
    final workspace = await _storage.workspacePath;
    await _loadDirectorySkills(
      '$workspace/skills',
      SkillSource.workspace,
    );

    _loaded = true;
  }

  /// Get all loaded skills.
  List<SkillInfo> get skills {
    if (!_loaded) return [];
    return List.unmodifiable(_skills);
  }

  /// Get a skill by name.
  SkillInfo? getSkill(String name) {
    return _skills.where((s) => s.name == name).firstOrNull;
  }

  /// Build XML summary of all skills for the system prompt.
  Future<String> buildSkillsSummary() async {
    if (!_loaded) await loadAll();
    if (_skills.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('<available_skills>');
    for (final skill in _skills) {
      buffer.writeln(
          '  <skill name="${skill.name}" source="${skill.source.name}">'
          '${skill.description}</skill>');
    }
    buffer.writeln('</available_skills>');
    return buffer.toString().trimRight();
  }

  /// Load full content for selected skills by name.
  Future<String> loadSkillsForContext(List<String> names) async {
    if (!_loaded) await loadAll();
    final buffer = StringBuffer();
    for (final name in names) {
      final skill = getSkill(name);
      if (skill != null) {
        buffer.writeln('<skill name="${skill.name}">');
        buffer.writeln(skill.content);
        buffer.writeln('</skill>');
      }
    }
    return buffer.toString().trimRight();
  }

  // --- Private loading methods ---

  Future<void> _loadBuiltinSkills() async {
    try {
      // Try to load the skill manifest from assets
      final manifest =
          await rootBundle.loadString('assets/skills/manifest.txt');
      final skillFiles = manifest
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final file in skillFiles) {
        try {
          final content =
              await rootBundle.loadString('assets/skills/$file');
          final parsed = _parseSkillFile(content);
          if (parsed != null) {
            _skills.add(SkillInfo(
              name: parsed.$1,
              path: 'assets/skills/$file',
              source: SkillSource.builtin,
              description: parsed.$2,
              content: parsed.$3,
            ));
          }
        } catch (_) {
          // Skip invalid skill files
        }
      }
    } catch (_) {
      // No builtin skills manifest — that's fine
    }
  }

  Future<void> _loadDirectorySkills(
      String dirPath, SkillSource source) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final content = await entity.readAsString();
          final parsed = _parseSkillFile(content);
          if (parsed != null) {
            _skills.add(SkillInfo(
              name: parsed.$1,
              path: entity.path,
              source: source,
              description: parsed.$2,
              content: parsed.$3,
            ));
          }
        } catch (_) {
          // Skip unreadable files
        }
      }
    }
  }

  /// Parse SKILL.md: YAML frontmatter (---\nname: ...\ndescription: ...\n---) + body.
  /// Returns (name, description, body) or null if invalid.
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

  String _globalSkillsPath() {
    final home = Platform.environment['HOME'] ?? '/data/data/com.droidclaw.app';
    return '$home/.droidclaw/skills';
  }
}
