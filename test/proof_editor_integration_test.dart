@Tags(['integration'])
library;

import 'dart:io';

import 'package:droidclaw/core/tools/proof_document_store.dart';
import 'package:droidclaw/core/tools/proof_editor_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Integration test for ProofEditorTool against the real ProofEditor.ai API.
///
/// Run with:
///   flutter test --tags integration test/proof_editor_integration_test.dart
///
/// These tests create real documents on ProofEditor.ai (no remote delete API).
/// Documents are titled with a timestamp for identification.
void main() {
  late Directory tempDir;
  late ProofDocumentStore store;
  late ProofEditorTool tool;

  // State shared across ordered tests.
  String? createdSlug;

  setUpAll(() async {
    // Pre-flight: check API reachability.
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse('https://www.proofeditor.ai'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 500) {
        markTestSkipped('ProofEditor.ai returned ${response.statusCode}');
        return;
      }
    } on Exception {
      markTestSkipped('ProofEditor.ai unreachable');
      return;
    } finally {
      client.close();
    }

    tempDir = await Directory.systemTemp.createTemp('proof_integ_');
    store = ProofDocumentStore('${tempDir.path}/docs.json');
    tool = ProofEditorTool(store: store, locale: 'en');
  });

  tearDownAll(() async {
    // Clean up temp directory.
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  });

  // -------------------------------------------------------------------------
  // Sequential test flow — each test depends on the previous one.
  // -------------------------------------------------------------------------

  test('1. create document with two sections', () async {
    final timestamp = DateTime.now().toIso8601String();
    final result = await tool.execute({
      'operation': 'create',
      'title': 'Test DroidClaw $timestamp',
      'content':
          '# Haut\n\nContenu initial en haut.\n\n# Bas\n\nContenu initial en bas.',
    });

    expect(result.isError, isFalse, reason: 'create failed: ${result.forLLM}');

    // Extract slug from forLLM: "Document created. Slug: xxx, URL: ..."
    final slugMatch =
        RegExp(r'Slug: ([a-zA-Z0-9_-]+)').firstMatch(result.forLLM);
    expect(slugMatch, isNotNull, reason: 'Could not extract slug from: ${result.forLLM}');
    createdSlug = slugMatch!.group(1)!;

    // Verify stored locally.
    final doc = await store.getBySlug(createdSlug!);
    expect(doc, isNotNull);
    expect(doc!.token, isNotEmpty);
  });

  test('2. read document and validate content', () async {
    expect(createdSlug, isNotNull, reason: 'Step 1 must succeed first');

    final result = await tool.execute({
      'operation': 'read',
      'slug': createdSlug!,
    });

    expect(result.isError, isFalse, reason: 'read failed: ${result.forLLM}');
    expect(result.forLLM, contains('Haut'));
    expect(result.forLLM, contains('Bas'));
    expect(result.forLLM, contains('Contenu initial en haut'));
    expect(result.forLLM, contains('Contenu initial en bas'));
  });

  test('3. append text under Bas section', () async {
    expect(createdSlug, isNotNull, reason: 'Step 1 must succeed first');

    // Try with raw heading text first; if 409, retry with "# Bas".
    var result = await tool.execute({
      'operation': 'append',
      'slug': createdSlug!,
      'section': 'Bas',
      'content': 'Texte ajouté en bas du document.',
    });

    if (result.isError && result.forLLM.contains('section may not exist')) {
      // Retry with full markdown heading.
      result = await tool.execute({
        'operation': 'append',
        'slug': createdSlug!,
        'section': '# Bas',
        'content': 'Texte ajouté en bas du document.',
      });
    }

    expect(result.isError, isFalse,
        reason: 'append failed: ${result.forLLM}');
  });

  test('4. read validates append under Bas', () async {
    expect(createdSlug, isNotNull, reason: 'Step 1 must succeed first');

    final result = await tool.execute({
      'operation': 'read',
      'slug': createdSlug!,
    });

    expect(result.isError, isFalse, reason: 'read failed: ${result.forLLM}');
    expect(result.forLLM, contains('Texte ajouté en bas du document'));
  });

  test('5. prepend text at top of document', () async {
    expect(createdSlug, isNotNull, reason: 'Step 1 must succeed first');

    final result = await tool.execute({
      'operation': 'prepend',
      'slug': createdSlug!,
      'content': 'Texte inséré en haut du document.',
    });

    expect(result.isError, isFalse,
        reason: 'prepend failed: ${result.forLLM}');
  });

  test('6. read validates prepend at top and ordering', () async {
    expect(createdSlug, isNotNull, reason: 'Step 1 must succeed first');

    final result = await tool.execute({
      'operation': 'read',
      'slug': createdSlug!,
    });

    expect(result.isError, isFalse, reason: 'read failed: ${result.forLLM}');
    expect(result.forLLM, contains('Texte inséré en haut du document'));

    // Verify ordering: prepended text (top) appears BEFORE appended text (bottom).
    final prependIdx = result.forLLM.indexOf('Texte inséré en haut');
    final appendIdx = result.forLLM.indexOf('Texte ajouté en bas');
    expect(prependIdx, greaterThanOrEqualTo(0),
        reason: 'Prepended text not found');
    expect(appendIdx, greaterThanOrEqualTo(0),
        reason: 'Appended text not found');
    expect(prependIdx, lessThan(appendIdx),
        reason: 'Prepended text should appear before appended text');
  });

  test('7. delete removes document from local store', () async {
    expect(createdSlug, isNotNull, reason: 'Step 1 must succeed first');

    final result = await tool.execute({
      'operation': 'delete',
      'slug': createdSlug!,
    });

    expect(result.isError, isFalse,
        reason: 'delete failed: ${result.forLLM}');
    expect(result.forLLM, contains('removed'));

    // Verify no longer in store.
    final doc = await store.getBySlug(createdSlug!);
    expect(doc, isNull);
  });
}
