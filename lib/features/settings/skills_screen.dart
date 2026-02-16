import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/skills/skill.dart';
import '../../providers/app_providers.dart';

/// Screen for managing installed skills.
class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  final _urlController = TextEditingController();
  bool _installing = false;
  List<SkillInfo> _skills = [];

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final loader = ref.read(skillLoaderProvider);
    await loader.loadAll();
    setState(() => _skills = loader.skills);
  }

  Future<void> _installSkill() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _installing = true);

    try {
      final installer = ref.read(skillInstallerProvider);
      final name = await installer.install(url);
      _urlController.clear();
      await _loadSkills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Installed skill: $name')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Install failed: $e')),
        );
      }
    } finally {
      setState(() => _installing = false);
    }
  }

  Future<void> _uninstallSkill(SkillInfo skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uninstall Skill'),
        content: Text('Remove "${skill.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final installer = ref.read(skillInstallerProvider);
      await installer.uninstall(skill.name);
      await _loadSkills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uninstalled: ${skill.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uninstall failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      body: Column(
        children: [
          // Install from URL
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'GitHub URL',
                      hintText: 'https://github.com/user/repo/blob/main/SKILL.md',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _installing ? null : _installSkill,
                  icon: _installing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  tooltip: 'Install',
                ),
              ],
            ),
          ),

          const Divider(),

          // Installed skills list
          Expanded(
            child: _skills.isEmpty
                ? const Center(child: Text('No skills installed'))
                : ListView.builder(
                    itemCount: _skills.length,
                    itemBuilder: (context, index) {
                      final skill = _skills[index];
                      return ListTile(
                        leading: Icon(_sourceIcon(skill.source)),
                        title: Text(skill.name),
                        subtitle: Text(skill.description.isNotEmpty
                            ? skill.description
                            : skill.source.name),
                        trailing: skill.source != SkillSource.builtin
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _uninstallSkill(skill),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _sourceIcon(SkillSource source) => switch (source) {
        SkillSource.builtin => Icons.star_outline,
        SkillSource.global => Icons.public,
        SkillSource.workspace => Icons.folder_outlined,
      };
}
