import 'dart:io';

import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import '../config/app_config.dart';
import '../skills/skill_loader.dart';
import '../tools/proof_editor/proof_document_store.dart';
import '../tools/tool.dart';
import 'memory_manager.dart';

/// Builds the system prompt for each agent request.
/// Reconstructed on each call (following the Go pattern).
class ContextBuilder {
  final MemoryManager memoryManager;
  final SkillLoader skillLoader;
  final ToolRegistry toolRegistry;
  final String workspacePath;
  final String locale;
  final String? kbLanguage;
  final ProofDocumentStore? proofDocumentStore;

  ContextBuilder({
    required this.memoryManager,
    required this.skillLoader,
    required this.toolRegistry,
    required this.workspacePath,
    this.locale = 'en',
    this.kbLanguage,
    this.proofDocumentStore,
  });

  /// Build the complete system prompt.
  ///
  /// [knowledgeContext] is an optional XML block from the Knowledge Graph,
  /// injected when KG is enabled and relevant entities are found.
  ///
  /// [semanticSearchAvailable] mirrors `KnowledgeService.hasEmbedder`: when
  /// false, the embedding model is not ready, so KG retrieval silently
  /// degrades to lexical (keyword) matching only. A `<kb_status>` note is then
  /// injected (just before the LANGUAGE REQUIREMENT block) so the agent does
  /// NOT answer as if it had full semantic recall. Defaults to true so callers
  /// that don't thread it through are unaffected.
  Future<String> buildSystemPrompt({
    String? knowledgeContext,
    bool semanticSearchAvailable = true,
  }) async {
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

    // 4. Memory context (MEMORY.md + daily notes)
    final memoryContext = await memoryManager.getMemoryContext();
    if (memoryContext.isNotEmpty) {
      buffer.writeln(memoryContext);
      buffer.writeln();
    }

    // 5. Knowledge Graph context (auto-extracted structured knowledge)
    if (knowledgeContext != null && knowledgeContext.isNotEmpty) {
      final langNote = kbLanguage != null
          ? ' The knowledge data below is stored in ${KnowledgeConfig.languageName(kbLanguage!)}.'
          : '';
      buffer.writeln(
          'KNOWLEDGE BASE — facts from previous conversations. '
          'Answer directly from this data when it contains the requested information. '
          'Only call tools when the knowledge base does NOT have what you need, '
          'or when you need to perform an action (set alarm, create event, get directions, etc.).$langNote');
      buffer.writeln('<knowledge_context data-only="true">');
      buffer.writeln(knowledgeContext);
      buffer.writeln('</knowledge_context>');
      buffer.writeln();
    }

    // 6. Active ProofEditor documents
    final proofContext = await _buildProofContext();
    if (proofContext.isNotEmpty) {
      buffer.writeln(proofContext);
      buffer.writeln();
    }

    // 7. Tools listing
    final toolsListing = _buildToolsListing();
    if (toolsListing.isNotEmpty) {
      buffer.writeln(toolsListing);
      buffer.writeln();
    }

    // 8. KB degradation status — placed BEFORE the language requirement so the
    // three-layer locale contract stays last. When the embedding model is not
    // ready, retrieval is keyword-only; tell the agent so it doesn't claim
    // full semantic recall.
    if (!semanticSearchAvailable) {
      buffer.writeln(tr(locale).agentKbStatusSemanticUnavailable);
      buffer.writeln();
    }

    // 9. Language instruction — positioned last for maximum LLM influence
    // Use triple reinforcement: the directive in the identity, tool result language note,
    // and this final instruction all work together
    buffer.writeln('=== LANGUAGE REQUIREMENT ===');
    buffer.writeln(tr(locale).agentRespondInstructions);

    return buffer.toString().trimRight();
  }

  String _buildIdentity() {
    final l = tr(locale);
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return '''You are ${AppConstants.appName}, a personal AI assistant running on Android.
${l.agentLanguageDirective}
Current time: $now
Platform: ${Platform.operatingSystem}
Version: ${AppConstants.appVersion}

You have access to tools listed below.

${l.agentKeyBehaviors}''';
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

  Future<String> _buildProofContext() async {
    if (proofDocumentStore == null) return '';
    final docs = await proofDocumentStore!.loadAll();
    if (docs.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('Active ProofEditor documents (use proof_editor tool to read/edit):');
    for (final doc in docs) {
      buffer.writeln('- "${doc.title}" (slug: ${doc.slug}, url: ${doc.shareUrl})');
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
