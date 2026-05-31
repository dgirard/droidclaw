import 'dart:convert';
import 'dart:io';

import 'package:droidclaw/core/tools/proof_document_store.dart';
import 'package:droidclaw/core/tools/proof_editor_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// In-memory ProofDocumentStore backed by a temp file.
Future<ProofDocumentStore> _createTempStore() async {
  final dir = await Directory.systemTemp.createTemp('proof_test_');
  return ProofDocumentStore('${dir.path}/docs.json');
}

/// Seed the store with a test document.
Future<ProofDocument> _seedDoc(ProofDocumentStore store, {
  String slug = 'test-doc',
  String token = 'tok_123',
  String title = 'Test Document',
}) async {
  final doc = ProofDocument(
    slug: slug,
    token: token,
    title: title,
    shareUrl: 'https://www.proofeditor.ai/d/$slug?token=$token',
    createdAt: DateTime(2026, 1, 1),
    lastAccessedAt: DateTime(2026, 1, 1),
  );
  await store.save(doc);
  return doc;
}

/// Build a ProofEditorTool wired to a MockClient.
ProofEditorTool _buildTool(
  ProofDocumentStore store,
  MockClient client,
) {
  return ProofEditorTool(
    store: store,
    locale: 'en',
    httpClientFactory: () => client,
  );
}

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Input validation (no HTTP needed)
  // -------------------------------------------------------------------------
  group('Input validation', () {
    late ProofDocumentStore store;
    late ProofEditorTool tool;

    setUp(() async {
      store = await _createTempStore();
      // Mock client that should not be called for validation errors.
      tool = _buildTool(store, MockClient((_) async => http.Response('', 500)));
    });

    test('missing operation returns error', () async {
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('operation'));
    });

    test('unknown operation returns error', () async {
      final result = await tool.execute({'operation': 'fly'});
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('Unknown operation'));
    });

    test('create without title returns error', () async {
      final result = await tool.execute({
        'operation': 'create',
        'content': 'Hello',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('title'));
    });

    test('create without content returns error', () async {
      final result = await tool.execute({
        'operation': 'create',
        'title': 'My Doc',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('content'));
    });

    test('edit without search returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'edit',
        'slug': 'test-doc',
        'replace': 'new text',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('search'));
    });

    test('edit without replace returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'edit',
        'slug': 'test-doc',
        'search': 'old text',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('replace'));
    });

    test('comment without quote returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'comment',
        'slug': 'test-doc',
        'text': 'Nice!',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('quote'));
    });

    test('comment without text returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'comment',
        'slug': 'test-doc',
        'quote': 'Hello',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('text'));
    });

    test('suggest without quote returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'suggest',
        'slug': 'test-doc',
        'content': 'Better text',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('quote'));
    });

    test('suggest without content returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'suggest',
        'slug': 'test-doc',
        'quote': 'Hello',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('content'));
    });

    test('append without content returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'append',
        'slug': 'test-doc',
        'section': 'Intro',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('content'));
    });

    test('append without section returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'append',
        'slug': 'test-doc',
        'content': 'More stuff',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('section'));
    });

    test('insert without content returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'insert',
        'slug': 'test-doc',
        'quote': 'anchor',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('content'));
    });

    test('insert without quote returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'insert',
        'slug': 'test-doc',
        'content': 'new stuff',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('quote'));
    });

    test('rewrite without content returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'rewrite',
        'slug': 'test-doc',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('content'));
    });

    test('rename without title returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'rename',
        'slug': 'test-doc',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('title'));
    });

    test('edit_v2 without base_token returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'edit_v2',
        'slug': 'test-doc',
        'ops': [{'op': 'replace_block', 'ref': 'b1', 'markdown': 'x'}],
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('base_token'));
    });

    test('edit_v2 without ops returns error', () async {
      await _seedDoc(store);
      final result = await tool.execute({
        'operation': 'edit_v2',
        'slug': 'test-doc',
        'base_token': 'abc',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('ops'));
    });

    test('delete without slug returns error', () async {
      final result = await tool.execute({'operation': 'delete'});
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('slug'));
    });

    test('delete with unknown slug returns error', () async {
      final result = await tool.execute({
        'operation': 'delete',
        'slug': 'nonexistent',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('not found'));
    });
  });

  // -------------------------------------------------------------------------
  // Document resolution
  // -------------------------------------------------------------------------
  group('Document resolution', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
    });

    test('read with unknown slug returns error', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({
        'operation': 'read',
        'slug': 'nonexistent',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('not found'));
    });

    test('read with no slug and no docs returns error', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({'operation': 'read'});
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('No document'));
    });

    test('read with invalid slug characters returns error', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({
        'operation': 'read',
        'slug': 'my doc!!',
      });
      expect(result.isError, isTrue);
    });

    test('URL import registers document and resolves it', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({
            'markdown': '# Imported',
            'marks': [],
          });
        }
        return http.Response('Not found', 404);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'url': 'https://www.proofeditor.ai/d/imported-doc?token=tok_abc',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Imported'));

      // Verify document was saved to store
      final doc = await store.getBySlug('imported-doc');
      expect(doc, isNotNull);
      expect(doc!.token, equals('tok_abc'));
    });

    test('URL import rejects non-proofeditor URLs', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({
        'operation': 'read',
        'url': 'https://evil.com/d/doc?token=hack',
      });
      expect(result.isError, isTrue);
    });

    test('URL import rejects URLs without token', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({
        'operation': 'read',
        'url': 'https://www.proofeditor.ai/d/doc',
      });
      expect(result.isError, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // ProofDocumentStore
  // -------------------------------------------------------------------------
  group('ProofDocumentStore', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
    });

    test('loadAll returns empty list on fresh store', () async {
      final docs = await store.loadAll();
      expect(docs, isEmpty);
    });

    test('save and retrieve by slug', () async {
      await _seedDoc(store, slug: 'my-doc', title: 'My Doc');
      final doc = await store.getBySlug('my-doc');
      expect(doc, isNotNull);
      expect(doc!.title, equals('My Doc'));
    });

    test('save upserts existing document', () async {
      await _seedDoc(store, slug: 'my-doc', title: 'V1');
      await _seedDoc(store, slug: 'my-doc', title: 'V2');
      final docs = await store.loadAll();
      expect(docs.length, equals(1));
      expect(docs.first.title, equals('V2'));
    });

    test('getMostRecent returns latest accessed', () async {
      await _seedDoc(store, slug: 'old');
      // Seed a newer doc
      final newer = ProofDocument(
        slug: 'new',
        token: 'tok',
        title: 'New',
        shareUrl: '',
        createdAt: DateTime(2026, 1, 1),
        lastAccessedAt: DateTime(2026, 6, 1),
      );
      await store.save(newer);
      final recent = await store.getMostRecent();
      expect(recent!.slug, equals('new'));
    });

    test('remove deletes document', () async {
      await _seedDoc(store, slug: 'to-delete');
      await store.remove('to-delete');
      final doc = await store.getBySlug('to-delete');
      expect(doc, isNull);
    });

    test('updateLastAccessed changes timestamp', () async {
      await _seedDoc(store, slug: 'ts-test');
      final before = (await store.getBySlug('ts-test'))!.lastAccessedAt;
      // Small delay to ensure timestamp differs
      await Future.delayed(const Duration(milliseconds: 10));
      await store.updateLastAccessed('ts-test');
      final after = (await store.getBySlug('ts-test'))!.lastAccessedAt;
      expect(after.isAfter(before), isTrue);
    });

    test('getBySlug returns null for unknown slug', () async {
      final doc = await store.getBySlug('nope');
      expect(doc, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Create operation
  // -------------------------------------------------------------------------
  group('Create operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
    });

    test('successful create stores doc and returns URL', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/share/markdown'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], equals('My Doc'));
        expect(body['markdown'], equals('# Hello'));
        return _jsonResponse({
          'slug': 'my-doc',
          'accessToken': 'tok_new',
          'shareUrl': 'https://www.proofeditor.ai/d/my-doc?token=tok_new',
        }, status: 201);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'create',
        'title': 'My Doc',
        'content': '# Hello',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('my-doc'));
      expect(result.forUser, contains('My Doc'));

      // Verify stored
      final doc = await store.getBySlug('my-doc');
      expect(doc, isNotNull);
      expect(doc!.token, equals('tok_new'));
    });

    test('create with server error returns error', () async {
      final client = MockClient((_) async => http.Response('err', 500));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'create',
        'title': 'My Doc',
        'content': '# Hello',
      });
      expect(result.isError, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Read operation
  // -------------------------------------------------------------------------
  group('Read operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
    });

    test('successful read returns markdown and comments', () async {
      await _seedDoc(store);
      final client = MockClient((request) async {
        return _jsonResponse({
          'markdown': '# Hello World\nSome content here.',
          'marks': [
            {
              'type': 'comment',
              'text': 'Great intro!',
              'quote': 'Hello World',
            },
          ],
        });
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Hello World'));
      expect(result.forLLM, contains('Great intro!'));
      expect(result.forLLM, contains('test-doc'));
    });

    test('read handles marks as Map', () async {
      await _seedDoc(store);
      final client = MockClient((request) async {
        return _jsonResponse({
          'markdown': '# Content',
          'marks': {
            'mark-1': {
              'type': 'comment',
              'text': 'Note from map',
              'quote': 'Content',
            },
          },
        });
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Note from map'));
    });

    test('read handles missing marks gracefully', () async {
      await _seedDoc(store);
      final client = MockClient((request) async {
        return _jsonResponse({'markdown': '# No marks'});
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('No marks'));
    });

    test('read resolves most recent doc when no slug given', () async {
      await _seedDoc(store, slug: 'recent-doc');
      final client = MockClient((request) async {
        expect(request.url.path, contains('recent-doc'));
        return _jsonResponse({'markdown': '# Recent', 'marks': []});
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({'operation': 'read'});
      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Recent'));
    });

    test('read with 401 removes doc and returns auth error', () async {
      await _seedDoc(store);
      final client = MockClient((_) async => http.Response('Unauthorized', 401));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('access denied'));
    });

    test('read with 404 removes doc', () async {
      await _seedDoc(store);
      final client = MockClient((_) async => http.Response('Not found', 404));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('not found'));
    });
  });

  // -------------------------------------------------------------------------
  // Edit operation
  // -------------------------------------------------------------------------
  group('Edit operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful edit sends baseUpdatedAt', () async {
      String? capturedBody;
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({
            'markdown': '# Old',
            'marks': [],
            'updatedAt': '2026-01-15T10:00:00Z',
          });
        }
        if (request.url.path.contains('/edit')) {
          capturedBody = request.body;
          return _jsonResponse({'ok': true});
        }
        return http.Response('', 404);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'edit',
        'slug': 'test-doc',
        'search': 'old text',
        'replace': 'new text',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Edit applied'));

      // Verify baseUpdatedAt was sent
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['baseUpdatedAt'], equals('2026-01-15T10:00:00Z'));
      expect(body['by'], equals('ai:droidclaw'));
    });

    test('edit 409 ANCHOR_NOT_FOUND returns helpful error', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({'updatedAt': 'x'});
        }
        return http.Response(
          jsonEncode({'code': 'ANCHOR_NOT_FOUND'}),
          409,
        );
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'edit',
        'slug': 'test-doc',
        'search': 'missing text',
        'replace': 'new',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('Text not found'));
    });

    test('edit 409 generic conflict', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({'updatedAt': 'x'});
        }
        return http.Response(jsonEncode({'code': 'CONFLICT'}), 409);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'edit',
        'slug': 'test-doc',
        'search': 'a',
        'replace': 'b',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('conflict'));
    });
  });

  // -------------------------------------------------------------------------
  // Append operation
  // -------------------------------------------------------------------------
  group('Append operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful append sends section and baseUpdatedAt', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({'updatedAt': '2026-01-20T00:00:00Z'});
        }
        if (request.url.path.contains('/edit')) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'ok': true});
        }
        return http.Response('', 404);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'append',
        'slug': 'test-doc',
        'section': 'Introduction',
        'content': 'New paragraph.',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('section "Introduction"'));

      final ops = capturedBody!['operations'] as List;
      expect(ops.first['op'], equals('append'));
      expect(ops.first['section'], equals('Introduction'));
      expect(capturedBody!['baseUpdatedAt'], equals('2026-01-20T00:00:00Z'));
    });

    test('append 409 returns section error', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({'updatedAt': 'x'});
        }
        return http.Response('conflict', 409);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'append',
        'slug': 'test-doc',
        'section': 'Nonexistent',
        'content': 'stuff',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('section may not exist'));
    });
  });

  // -------------------------------------------------------------------------
  // Insert operation
  // -------------------------------------------------------------------------
  group('Insert operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful insert sends anchor and baseUpdatedAt', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({'updatedAt': '2026-02-01T00:00:00Z'});
        }
        if (request.url.path.contains('/edit')) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'ok': true});
        }
        return http.Response('', 404);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'insert',
        'slug': 'test-doc',
        'quote': 'after this text',
        'content': 'inserted content',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('inserted after'));

      final ops = capturedBody!['operations'] as List;
      expect(ops.first['target']['anchor'], equals('after this text'));
      expect(capturedBody!['baseUpdatedAt'], equals('2026-02-01T00:00:00Z'));
    });

    test('insert 409 ANCHOR_NOT_FOUND', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/state')) {
          return _jsonResponse({'updatedAt': 'x'});
        }
        return http.Response(
          jsonEncode({'code': 'ANCHOR_NOT_FOUND'}),
          409,
        );
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'insert',
        'slug': 'test-doc',
        'quote': 'missing',
        'content': 'new',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('Anchor text not found'));
    });
  });

  // -------------------------------------------------------------------------
  // Rewrite operation
  // -------------------------------------------------------------------------
  group('Rewrite operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful rewrite fetches state then posts to ops', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.contains('/state')) {
          return _jsonResponse({
            'revision': 42,
            'updatedAt': '2026-03-01T00:00:00Z',
          });
        }
        if (request.method == 'POST' &&
            request.url.path.contains('/ops')) {
          expect(request.url.queryParameters['token'], equals('tok_123'));
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'ok': true});
        }
        return http.Response('', 404);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'rewrite',
        'slug': 'test-doc',
        'content': '# New content',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('rewrite applied'));
      expect(capturedBody!['type'], equals('rewrite.apply'));
      expect(capturedBody!['content'], equals('# New content'));
      expect(capturedBody!['baseRevision'], equals(42));
    });
  });

  // -------------------------------------------------------------------------
  // Comment operation
  // -------------------------------------------------------------------------
  group('Comment operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful comment', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], equals('comment.add'));
        expect(body['quote'], equals('target text'));
        expect(body['text'], equals('My comment'));
        return _jsonResponse({'ok': true});
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'comment',
        'slug': 'test-doc',
        'quote': 'target text',
        'text': 'My comment',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Comment added'));
    });
  });

  // -------------------------------------------------------------------------
  // Suggest operation
  // -------------------------------------------------------------------------
  group('Suggest operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful suggest', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], equals('suggestion.add'));
        expect(body['kind'], equals('replace'));
        return _jsonResponse({'ok': true});
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'suggest',
        'slug': 'test-doc',
        'quote': 'old phrase',
        'content': 'better phrase',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Suggestion added'));
    });

    test('suggest 409 returns quote-not-found error', () async {
      final client = MockClient((_) async => http.Response('', 409));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'suggest',
        'slug': 'test-doc',
        'quote': 'missing',
        'content': 'new',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('not found'));
    });
  });

  // -------------------------------------------------------------------------
  // Rename operation
  // -------------------------------------------------------------------------
  group('Rename operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful rename updates store', () async {
      final client = MockClient((request) async {
        expect(request.method, equals('PUT'));
        expect(request.url.path, contains('/title'));
        return _jsonResponse({'ok': true});
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'rename',
        'slug': 'test-doc',
        'title': 'New Title',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('renamed'));

      final doc = await store.getBySlug('test-doc');
      expect(doc!.title, equals('New Title'));
    });
  });

  // -------------------------------------------------------------------------
  // Snapshot operation
  // -------------------------------------------------------------------------
  group('Snapshot operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful snapshot returns blocks with refs', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/snapshot'));
        return _jsonResponse({
          'blocks': [
            {'ref': 'b0', 'content': '# Title'},
            {'ref': 'b1', 'content': 'Paragraph one'},
          ],
          'mutationBase': {'token': 'mut_abc123'},
        });
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'snapshot',
        'slug': 'test-doc',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('[b0]'));
      expect(result.forLLM, contains('[b1]'));
      expect(result.forLLM, contains('mut_abc123'));
      expect(result.forLLM, contains('# Title'));
    });
  });

  // -------------------------------------------------------------------------
  // Edit V2 operation
  // -------------------------------------------------------------------------
  group('Edit V2 operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('successful edit_v2 sends baseToken and ops', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        expect(request.url.path, contains('/edit/v2'));
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'ok': true});
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'edit_v2',
        'slug': 'test-doc',
        'base_token': 'mut_abc',
        'ops': [
          {'op': 'replace_block', 'ref': 'b1', 'markdown': 'Updated text'},
        ],
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Block-level edits applied'));
      expect(capturedBody!['baseToken'], equals('mut_abc'));
    });

    test('edit_v2 409 returns stale snapshot error', () async {
      final client = MockClient((_) async => http.Response('conflict', 409));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'edit_v2',
        'slug': 'test-doc',
        'base_token': 'old_token',
        'ops': [
          {'op': 'replace_block', 'ref': 'b0', 'markdown': 'x'},
        ],
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('snapshot'));
    });
  });

  // -------------------------------------------------------------------------
  // List operation
  // -------------------------------------------------------------------------
  group('List operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
    });

    test('list with no docs returns helpful message', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({'operation': 'list'});
      expect(result.isError, isFalse);
      expect(result.forLLM, contains('No ProofEditor documents'));
    });

    test('list returns all docs sorted by last accessed', () async {
      await _seedDoc(store, slug: 'older', title: 'Older Doc');
      final newer = ProofDocument(
        slug: 'newer',
        token: 'tok',
        title: 'Newer Doc',
        shareUrl: '',
        createdAt: DateTime(2026, 1, 1),
        lastAccessedAt: DateTime(2026, 6, 1),
      );
      await store.save(newer);

      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({'operation': 'list'});

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('(2)'));
      expect(result.forLLM, contains('Newer Doc'));
      expect(result.forLLM, contains('Older Doc'));
      expect(result.forUser, contains('2 document'));
    });
  });

  // -------------------------------------------------------------------------
  // Prepend operation
  // -------------------------------------------------------------------------
  group('Prepend operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('prepend without content returns error', () async {
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final result = await tool.execute({
        'operation': 'prepend',
        'slug': 'test-doc',
      });
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('content'));
    });

    test('successful prepend reads then rewrites with new content first',
        () async {
      String? rewriteBody;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.contains('/state')) {
          return _jsonResponse({
            'markdown': '# Existing\n\nOld content.',
            'marks': [],
          });
        }
        if (request.method == 'POST' &&
            request.url.path.contains('/ops')) {
          rewriteBody = request.body;
          return _jsonResponse({'ok': true});
        }
        return http.Response('', 404);
      });
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'prepend',
        'slug': 'test-doc',
        'content': '# New Header\n\nPrepended text.',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('prepended'));

      // Verify the rewrite body has new content BEFORE old content.
      final body = jsonDecode(rewriteBody!) as Map<String, dynamic>;
      expect(body['type'], equals('rewrite.apply'));
      final content = body['content'] as String;
      final newIdx = content.indexOf('New Header');
      final oldIdx = content.indexOf('Existing');
      expect(newIdx, lessThan(oldIdx));
    });

    test('prepend with read failure returns error', () async {
      final client =
          MockClient((_) async => http.Response('Unauthorized', 401));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'prepend',
        'slug': 'test-doc',
        'content': 'New stuff',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('access denied'));
    });
  });

  // -------------------------------------------------------------------------
  // Delete operation
  // -------------------------------------------------------------------------
  group('Delete operation', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
    });

    test('successful delete removes from store', () async {
      await _seedDoc(store, slug: 'to-delete');
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));

      final result = await tool.execute({
        'operation': 'delete',
        'slug': 'to-delete',
      });

      expect(result.isError, isFalse);
      expect(result.forLLM, contains('removed'));
      expect(result.forLLM, contains('still exists'));

      final doc = await store.getBySlug('to-delete');
      expect(doc, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // HTTP error handling
  // -------------------------------------------------------------------------
  group('HTTP error handling', () {
    late ProofDocumentStore store;

    setUp(() async {
      store = await _createTempStore();
      await _seedDoc(store);
    });

    test('429 returns rate limit error', () async {
      final client = MockClient((_) async => http.Response('', 429));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      // With retries, 429 is retried then returns rate limit error
      expect(result.isError, isTrue);
      expect(result.forLLM, contains('Rate limited'));
    });

    test('500 returns service unavailable', () async {
      final client = MockClient((_) async => http.Response('', 500));
      final tool = _buildTool(store, client);

      final result = await tool.execute({
        'operation': 'read',
        'slug': 'test-doc',
      });

      expect(result.isError, isTrue);
      expect(result.forLLM, contains('unavailable'));
    });
  });

  // -------------------------------------------------------------------------
  // Tool metadata
  // -------------------------------------------------------------------------
  group('Tool metadata', () {
    test('name is proof_editor', () async {
      final store = await _createTempStore();
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      expect(tool.name, equals('proof_editor'));
    });

    test('parameters schema has operation as required', () async {
      final store = await _createTempStore();
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final params = tool.parameters;
      expect(params['required'], contains('operation'));
    });

    test('all operations are listed in enum', () async {
      final store = await _createTempStore();
      final tool =
          _buildTool(store, MockClient((_) async => http.Response('', 500)));
      final props = tool.parameters['properties'] as Map<String, dynamic>;
      final ops = (props['operation'] as Map)['enum'] as List;
      expect(ops, containsAll([
        'create', 'read', 'edit', 'rewrite', 'comment', 'suggest', 'prepend',
        'append', 'insert', 'rename', 'snapshot', 'edit_v2', 'list', 'delete',
      ]));
    });
  });
}
