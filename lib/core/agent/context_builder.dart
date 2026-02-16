import 'dart:io';

import 'package:intl/intl.dart';

import '../../shared/constants.dart';
import '../skills/skill_loader.dart';
import '../tools/tool.dart';
import 'memory_manager.dart';

/// Builds the system prompt for each agent request.
/// Reconstructed on each call (following the Go pattern).
class ContextBuilder {
  final MemoryManager memoryManager;
  final SkillLoader skillLoader;
  final ToolRegistry toolRegistry;
  final String workspacePath;

  ContextBuilder({
    required this.memoryManager,
    required this.skillLoader,
    required this.toolRegistry,
    required this.workspacePath,
  });

  /// Build the complete system prompt.
  Future<String> buildSystemPrompt() async {
    final buffer = StringBuffer();

    // 1. Identity section
    buffer.writeln(_buildIdentity());
    buffer.writeln();

    // 2. Bootstrap files
    final bootstrap = await _loadBootstrapFiles();
    if (bootstrap.isNotEmpty) {
      buffer.writeln(bootstrap);
      buffer.writeln();
    }

    // 3. Skills summary
    final skillsSummary = await skillLoader.buildSkillsSummary();
    if (skillsSummary.isNotEmpty) {
      buffer.writeln(skillsSummary);
      buffer.writeln();
    }

    // 4. Memory context
    final memoryContext = await memoryManager.getMemoryContext();
    if (memoryContext.isNotEmpty) {
      buffer.writeln(memoryContext);
      buffer.writeln();
    }

    // 5. Tools listing
    final toolsListing = _buildToolsListing();
    if (toolsListing.isNotEmpty) {
      buffer.writeln(toolsListing);
    }

    return buffer.toString().trimRight();
  }

  String _buildIdentity() {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '''You are ${AppConstants.appName}, a personal AI assistant running on Android.
Current time: $now
Platform: ${Platform.operatingSystem}
Version: ${AppConstants.appVersion}

You have access to tools that let you search the web, fetch web pages, and manage files in your workspace.
When you need current information, use the web_search tool.
Be concise and helpful. Use markdown formatting in your responses.''';
  }

  Future<String> _loadBootstrapFiles() async {
    final dir = Directory('$workspacePath/bootstrap');
    if (!await dir.exists()) return '';

    final buffer = StringBuffer();
    final files = await dir
        .list()
        .where((e) => e.path.endsWith('.md'))
        .toList();

    for (final file in files) {
      final content = await File(file.path).readAsString();
      buffer.writeln('<bootstrap>');
      buffer.writeln(content);
      buffer.writeln('</bootstrap>');
    }
    return buffer.toString().trimRight();
  }

  String _buildToolsListing() {
    final definitions = toolRegistry.getDefinitions();
    if (definitions.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('Available tools:');
    for (final tool in definitions) {
      buffer.writeln('- **${tool.name}**: ${tool.description}');
    }
    return buffer.toString().trimRight();
  }
}
