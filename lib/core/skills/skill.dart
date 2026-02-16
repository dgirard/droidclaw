/// Source tier for skills.
enum SkillSource {
  builtin,
  global,
  workspace,
}

/// Represents a loaded skill with its metadata and content.
class SkillInfo {
  final String name;
  final String path;
  final SkillSource source;
  final String description;
  final String content;

  const SkillInfo({
    required this.name,
    required this.path,
    required this.source,
    required this.description,
    required this.content,
  });
}
