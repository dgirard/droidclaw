import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/agent/context_builder.dart';
import 'package:droidclaw/core/agent/memory_manager.dart';
import 'package:droidclaw/core/skills/skill_loader.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/l10n/l10n.dart';

/// Minimal tool whose name acts as a marker for the tools-listing section.
class _ProbeTool extends Tool {
  @override
  String get name => 'probe_tool';

  @override
  String get description => 'A probe tool used only by tests.';

  @override
  Map<String, dynamic> get parameters => {'type': 'object', 'properties': {}};

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async =>
      ToolResult.simple('ok');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workspace;
  late StorageService storage;
  late ToolRegistry registry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    workspace = await Directory.systemTemp.createTemp('ctx_builder_test_');
    storage = StorageService(
      prefs: prefs,
      overrideWorkspacePath: workspace.path,
    );
    registry = ToolRegistry();
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  ContextBuilder builder({String locale = 'fr', String? kbLanguage}) =>
      ContextBuilder(
        memoryManager: MemoryManager(storage),
        skillLoader: SkillLoader(storage),
        toolRegistry: registry,
        workspacePath: workspace.path,
        locale: locale,
        kbLanguage: kbLanguage,
      );

  Future<void> seedAllSections() async {
    // Memory section (<long_term_memory>).
    final memoryFile = File('${workspace.path}/memory/MEMORY.md');
    await memoryFile.parent.create(recursive: true);
    await memoryFile.writeAsString('User prefers metric units.');

    // Bootstrap section (<bootstrap>).
    final bootstrapFile = File('${workspace.path}/bootstrap/setup.md');
    await bootstrapFile.parent.create(recursive: true);
    await bootstrapFile.writeAsString('Bootstrap directive content.');

    // Skills section (<available_skills>).
    final skillFile = File('${workspace.path}/skills/probe_skill.md');
    await skillFile.parent.create(recursive: true);
    await skillFile.writeAsString(
        '---\nname: probe_skill\ndescription: a test skill\n---\nbody');

    // Tools section.
    registry.register(_ProbeTool());
  }

  group('ContextBuilder.buildSystemPrompt — prompt shape', () {
    test(
        'language directive is the LAST section '
        '(documented requirement: small models obey the last instruction)',
        () async {
      await seedAllSections();
      final prompt = await builder(locale: 'fr').buildSystemPrompt(
        knowledgeContext: '<entity name="Home"/>',
      );

      // The prompt must END with the locale's respond-instruction text —
      // nothing may be appended after it. Wording comes from l10n, so this
      // pins placement, not copy.
      expect(prompt.trimRight(),
          endsWith(tr('fr').agentRespondInstructions.trimRight()));
    });

    test('section ordering is stable: identity → bootstrap → skills → memory '
        '→ knowledge → tools → language', () async {
      await seedAllSections();
      final prompt = await builder(locale: 'fr').buildSystemPrompt(
        knowledgeContext: '<entity name="Home"/>',
      );

      // Structural markers per section (tags/names, not prose) in the
      // order the builder must emit them. Note: the identity key-behaviors
      // text mentions the literal `<knowledge_context>` tag name, so the KB
      // section marker must be the attribute-qualified opening tag.
      final markers = <String, String>{
        'identity (language directive)': tr('fr').agentLanguageDirective,
        'bootstrap': '<bootstrap>',
        'skills': '<available_skills>',
        'memory': '<long_term_memory>',
        'knowledge': '<knowledge_context data-only="true">',
        'tools': 'probe_tool',
        'language requirement': tr('fr').agentRespondInstructions,
      };

      var lastIndex = -1;
      markers.forEach((label, marker) {
        final index = prompt.indexOf(marker);
        expect(index, greaterThanOrEqualTo(0),
            reason: 'section missing: $label (marker "$marker")');
        expect(index, greaterThan(lastIndex),
            reason: 'section out of order: $label');
        lastIndex = index;
      });
    });

    test('minimal build (no optional sections) still ends with the language '
        'directive', () async {
      final prompt = await builder(locale: 'en').buildSystemPrompt();

      expect(prompt, isNot(contains('<bootstrap>')));
      expect(prompt, isNot(contains('<available_skills>')));
      expect(prompt, isNot(contains('<long_term_memory>')));
      // The identity copy mentions the `<knowledge_context>` tag name, so
      // check for the actual opening tag the builder emits.
      expect(prompt, isNot(contains('<knowledge_context data-only')));
      expect(prompt.trimRight(),
          endsWith(tr('en').agentRespondInstructions.trimRight()));
    });
  });

  group('ContextBuilder.buildSystemPrompt — KB degradation status (AN2)', () {
    test('semanticSearchAvailable=false injects the <kb_status> note, '
        'placed before the language requirement', () async {
      final prompt = await builder(locale: 'fr').buildSystemPrompt(
        semanticSearchAvailable: false,
      );

      final note = tr('fr').agentKbStatusSemanticUnavailable;
      expect(prompt, contains(note));
      expect(prompt, contains('<kb_status>'));
      // The language requirement must still be LAST: the note comes before it.
      final noteIndex = prompt.indexOf(note);
      final langIndex =
          prompt.indexOf(tr('fr').agentRespondInstructions.trimRight());
      expect(noteIndex, greaterThanOrEqualTo(0));
      expect(langIndex, greaterThan(noteIndex));
      expect(prompt.trimRight(),
          endsWith(tr('fr').agentRespondInstructions.trimRight()));
    });

    test('semanticSearchAvailable=true (default) omits the <kb_status> note',
        () async {
      final explicitTrue = await builder(locale: 'fr').buildSystemPrompt(
        semanticSearchAvailable: true,
      );
      final defaulted = await builder(locale: 'fr').buildSystemPrompt();

      expect(explicitTrue, isNot(contains('<kb_status>')));
      expect(defaulted, isNot(contains('<kb_status>')));
      expect(defaulted.trimRight(),
          endsWith(tr('fr').agentRespondInstructions.trimRight()));
    });
  });

  group('ContextBuilder.buildSystemPrompt — knowledge context injection', () {
    test('KB facts are present when supplied', () async {
      final prompt = await builder().buildSystemPrompt(
        knowledgeContext:
            '<entity name="Home"><fact key="address">9 rue de la Paix</fact></entity>',
      );

      expect(prompt, contains('<knowledge_context data-only="true">'));
      expect(prompt, contains('9 rue de la Paix'));
      expect(prompt, contains('</knowledge_context>'));
    });

    test('KB section is absent when not supplied', () async {
      final withNull = await builder().buildSystemPrompt();
      final withEmpty = await builder().buildSystemPrompt(knowledgeContext: '');

      expect(withNull, isNot(contains('<knowledge_context data-only')));
      expect(withEmpty, isNot(contains('<knowledge_context data-only')));
    });

    test('kbLanguage adds a stored-language note to the KB preamble',
        () async {
      final withLang = await builder(kbLanguage: 'en').buildSystemPrompt(
        knowledgeContext: '<entity name="Home"/>',
      );
      final withoutLang = await builder().buildSystemPrompt(
        knowledgeContext: '<entity name="Home"/>',
      );

      // Pin the shape: the note names the KB language only when configured.
      expect(withLang, contains('English'));
      final kbSection = withoutLang.substring(
          0, withoutLang.indexOf('<knowledge_context'));
      expect(kbSection, isNot(contains('stored in')));
    });
  });
}
