import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/agent/agent_loop.dart';
import 'package:droidclaw/core/agent/context_builder.dart';
import 'package:droidclaw/core/agent/memory_manager.dart';
import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/knowledge/services/dedup/cleanup_service.dart';
import 'package:droidclaw/core/providers/llm_provider.dart';
import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/core/skills/skill_loader.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/l10n/l10n.dart';

import '../support/fake_llm_provider.dart';
import '../support/session_db_test_harness.dart';
import '../support/in_memory_kg.dart';

/// U19 — model-aware language enforcement contract.
///
/// Pins the three-layer enforcement mechanism documented in
/// docs/solutions/runtime-errors/
/// gemini-flash-ignores-system-prompt-language-instructions.md and
/// docs/solutions/logic-errors/llm-agent-locale-prompt-engineering.md:
///
/// - Layer 1: language directive LAST in the system prompt
///   (pinned by test/agent/context_builder_test.dart — U21).
/// - Layer 2: per-turn target-language tag on the LLM-bound copy of the
///   last user message ONLY; stored history untouched (pinned here).
/// - Layer 3: summarization prompt carries the configured-language
///   instruction so a wrong-language summary is never re-injected
///   (pinned here).
///
/// Also pins the single-source language-name map
/// ([KnowledgeConfig.languageName]) and the resolved divergent default:
/// unknown locale codes yield 'English' everywhere, including the KB
/// cleanup prompt (which previously echoed the raw code).
void main() {
  late SessionDbTestHarness store;
  late Directory workspace;
  late SessionManager sessions;

  setUp(() async {
    store = await SessionDbTestHarness.create();
    workspace = await Directory.systemTemp.createTemp('lang_ws_');
    sessions = SessionManager();
    await sessions.init(directory: store.dir.path);
    store.track(sessions);
  });

  tearDown(() async {
    if (await workspace.exists()) await workspace.delete(recursive: true);
    await store.dispose();
  });

  Future<AgentLoop> buildLoop(LLMProvider provider,
      {required String locale}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage =
        StorageService(prefs: prefs, overrideWorkspacePath: workspace.path);
    final registry = ToolRegistry();
    return AgentLoop(
      provider: provider,
      config: AppConfig.defaults().copyWith(locale: locale),
      sessions: sessions,
      tools: registry,
      contextBuilder: ContextBuilder(
        memoryManager: MemoryManager(storage),
        skillLoader: SkillLoader(storage),
        toolRegistry: registry,
        workspacePath: workspace.path,
        locale: locale,
      ),
    );
  }

  /// Seed [count] alternating English user/assistant messages — the
  /// "conversation inertia" that makes Flash-class models ignore the
  /// system-prompt directive.
  void seedEnglishHistory(String sessionKey, int count) {
    final session = sessions.getOrCreate(sessionKey);
    for (var i = 0; i < count; i++) {
      session.addMessage(Message(
        role: i.isEven ? 'user' : 'assistant',
        content: i.isEven ? 'question number $i' : 'answer number $i',
      ));
    }
  }

  group('Layer 2 — per-turn language tag (LLM copy only)', () {
    test(
        'French locale + English-heavy history: the LLM-bound copy carries '
        'the French tag on the LAST user message; stored session is untouched',
        () async {
      seedEnglishHistory('tag-fr', 10);
      final provider = FakeLLMProvider([textResponse('Il est 17h47.')]);
      final loop = await buildLoop(provider, locale: 'fr');

      await loop.processMessage('quelle heure est-il ?', 'tag-fr').toList();

      // LLM-bound copy: exactly one chat call; the tag is in the target
      // language and on the last user message only (recency + priming).
      final sent = provider.receivedMessages.single;
      final sentUsers =
          sent.where((m) => m.role == 'user').toList();
      expect(sentUsers.last.content,
          'quelle heure est-il ?\n\n[Réponds en français]');
      for (final earlier in sentUsers.sublist(0, sentUsers.length - 1)) {
        expect(earlier.content, isNot(contains('[Réponds en français]')),
            reason: 'only the LAST user message may carry the tag');
      }

      // Stored session: the SAME message has NO tag — tags must never
      // persist or they compound across turns.
      final stored = sessions.getOrCreate('tag-fr');
      final storedUsers =
          stored.messages.where((m) => m.role == 'user').toList();
      expect(storedUsers.last.content, 'quelle heure est-il ?');
      expect(
        stored.messages.any((m) => m.content.contains('[Réponds')),
        isFalse,
        reason: 'no stored message may carry a language tag',
      );
    });

    test('English locale: no tag is appended', () async {
      seedEnglishHistory('tag-en', 4);
      final provider = FakeLLMProvider([textResponse('It is 5pm.')]);
      final loop = await buildLoop(provider, locale: 'en');

      await loop.processMessage('what time is it?', 'tag-en').toList();

      final sentUsers = provider.receivedMessages.single
          .where((m) => m.role == 'user')
          .toList();
      expect(sentUsers.last.content, 'what time is it?');
    });

    test(
        'hint map covers every supported locale in target-language tokens; '
        'unknown locales fall back to English (pinned default, consistent '
        'with KnowledgeConfig.languageName)', () {
      // Layer 2 hints must be written IN the target language (priming) —
      // they are deliberately NOT derived from the English-name map.
      expect(AgentLoop.languageHint('fr'), 'Réponds en français');
      expect(AgentLoop.languageHint('es'), 'Responde en español');
      expect(AgentLoop.languageHint('de'), 'Antworte auf Deutsch');
      expect(AgentLoop.languageHint('it'), 'Rispondi in italiano');
      // Unknown codes cannot reach the loop in production (the 'system'
      // locale path clamps to the supported set, and the settings UI only
      // offers the five locales), but the fallback is pinned to English to
      // match the single-source name map.
      expect(AgentLoop.languageHint('en'), 'Reply in English');
      expect(AgentLoop.languageHint('pt'), 'Reply in English');
      expect(AgentLoop.languageHint(''), 'Reply in English');
    });
  });

  group('Layer 3 — language-aware summarization', () {
    test(
        'the summarization request carries the configured-language '
        'instruction (French)', () async {
      // 20+ messages trigger summarization before the turn is processed.
      seedEnglishHistory('sum-fr', 21);
      final provider = FakeLLMProvider([
        textResponse('Résumé de la conversation précédente.'), // summarize
        textResponse("D'accord."), // main chat turn
      ]);
      final loop = await buildLoop(provider, locale: 'fr');

      await loop.processMessage('et ensuite ?', 'sum-fr').toList();

      expect(provider.callCount, 2);
      final summarizeSystem = provider.receivedMessages.first
          .firstWhere((m) => m.role == 'system');
      expect(
        summarizeSystem.content,
        contains(tr('fr').agentSummarizeInstructions),
        reason: 'a wrong-language summary would be re-injected into every '
            'future turn as persistent context',
      );

      // The produced summary is what gets re-injected.
      expect(sessions.getOrCreate('sum-fr').summary,
          'Résumé de la conversation précédente.');
    });
  });

  group('single source — KnowledgeConfig.languageName', () {
    test('maps supported locales and pins the English default for unknown '
        'codes (resolved divergent default)', () {
      expect(KnowledgeConfig.languageName('en'), 'English');
      expect(KnowledgeConfig.languageName('fr'), 'French');
      expect(KnowledgeConfig.languageName('es'), 'Spanish');
      expect(KnowledgeConfig.languageName('de'), 'German');
      expect(KnowledgeConfig.languageName('it'), 'Italian');
      // Decision (U19): unknown → 'English', NOT the raw code. kbLanguage
      // only ever comes from the supported-locale set, so a raw code in a
      // prompt would mask a programming error instead of degrading sanely.
      expect(KnowledgeConfig.languageName('pt-BR'), 'English');
      expect(KnowledgeConfig.languageName(''), 'English');
    });

    test(
        'the KB cleanup prompt resolves language names from the single '
        'source — consistent with the agent path for fr/es/de/it', () async {
      for (final code in ['fr', 'es', 'de', 'it']) {
        final db = inMemoryKnowledgeGraphDB();
        addTearDown(db.close);
        final provider =
            FakeLLMProvider([textResponse('{"operations":[],"summary":""}')]);
        final service = KbCleanupService(
          db: db,
          llmProvider: provider,
          model: 'fake-model',
          kbLanguage: code,
        );

        await service.proposeCleanup('| 1 | Probe | concept | 0 | | |');

        final systemPrompt = provider.receivedMessages.single
            .firstWhere((m) => m.role == 'system')
            .content;
        // Same name the agent path (context builder KB note, KG query
        // expansion, entity extraction) produces for this code.
        expect(
          systemPrompt,
          contains('The KB data is in '
              '${KnowledgeConfig.languageName(code)}.'),
          reason: 'cleanup prompt must use the single-source name for $code',
        );
      }
    });

    test('English KB omits the cleanup language instruction', () async {
      final db = inMemoryKnowledgeGraphDB();
      addTearDown(db.close);
      final provider =
          FakeLLMProvider([textResponse('{"operations":[],"summary":""}')]);
      final service = KbCleanupService(
        db: db,
        llmProvider: provider,
        model: 'fake-model',
        kbLanguage: 'en',
      );

      await service.proposeCleanup('| 1 | Probe | concept | 0 | | |');

      final systemPrompt = provider.receivedMessages.single
          .firstWhere((m) => m.role == 'system')
          .content;
      expect(systemPrompt, isNot(contains('The KB data is in')));
    });

    test(
        'unknown kbLanguage in the cleanup prompt yields English (pinned: '
        'the old copy echoed the raw code)', () async {
      final db = inMemoryKnowledgeGraphDB();
      addTearDown(db.close);
      final provider =
          FakeLLMProvider([textResponse('{"operations":[],"summary":""}')]);
      final service = KbCleanupService(
        db: db,
        llmProvider: provider,
        model: 'fake-model',
        kbLanguage: 'pt-BR',
      );

      await service.proposeCleanup('| 1 | Probe | concept | 0 | | |');

      final systemPrompt = provider.receivedMessages.single
          .firstWhere((m) => m.role == 'system')
          .content;
      expect(systemPrompt, contains('The KB data is in English.'));
      expect(systemPrompt, isNot(contains('pt-BR')));
    });
  });
}
