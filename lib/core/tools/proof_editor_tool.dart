import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';
import 'proof_document_store.dart';
import 'tool.dart';

/// Collaborative document editor via ProofEditor.ai.
///
/// Creates, reads, edits, and comments on shared markdown documents.
/// Uses per-document share tokens (no global API key). Tokens are stored
/// in [ProofDocumentStore] and never exposed in [ToolResult.forLLM].
class ProofEditorTool extends Tool {
  final ProofDocumentStore store;
  final String locale;

  static const _baseUrl = 'https://www.proofeditor.ai';
  static const _agentId = 'droidclaw';
  static const _agentBy = 'ai:droidclaw';
  static final _slugPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  static const _maxContentLength = 15000;
  static const _maxRetries = 2;

  ProofEditorTool({required this.store, this.locale = 'en'});

  @override
  String get name => 'proof_editor';

  @override
  String get description =>
      'Collaborative document editor via ProofEditor.ai. '
      'Create, read, edit, comment on, and manage shared markdown documents. '
      'Documents persist across sessions and are accessible via shareable URLs. '
      'Use operation "list" to see known documents, "create" to start a new one.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': [
              'create',
              'read',
              'edit',
              'rewrite',
              'comment',
              'list',
              'delete',
            ],
            'description': 'The operation to perform on a Proof document',
          },
          'slug': {
            'type': 'string',
            'description':
                'Document slug. If omitted for read/edit, uses most recently accessed document.',
          },
          'title': {
            'type': 'string',
            'description': 'Document title (for create)',
          },
          'content': {
            'type': 'string',
            'description': 'Markdown content (for create, rewrite)',
          },
          'search': {
            'type': 'string',
            'description': 'Text to find in document (for edit)',
          },
          'replace': {
            'type': 'string',
            'description': 'Replacement text (for edit)',
          },
          'quote': {
            'type': 'string',
            'description': 'Text to anchor comment on (for comment)',
          },
          'text': {
            'type': 'string',
            'description': 'Comment body (for comment)',
          },
          'url': {
            'type': 'string',
            'description':
                'ProofEditor URL to import (registers document from shared URL)',
          },
        },
        'required': ['operation'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) {
      return ToolResult.error('Missing required parameter: operation');
    }

    try {
      return switch (operation) {
        'create' => await _create(arguments),
        'read' => await _read(arguments),
        'edit' => await _edit(arguments),
        'rewrite' => await _rewrite(arguments),
        'comment' => await _comment(arguments),
        'list' => await _list(),
        'delete' => await _delete(arguments),
        _ => ToolResult.error(
            'Unknown operation: $operation. '
            'Use create, read, edit, rewrite, comment, list, or delete.'),
      };
    } catch (e) {
      // SECURITY: Never expose raw exception (may contain tokens in URLs)
      print('[ProofEditor] Operation "$operation" failed: $e');
      return ToolResult.error(
          'ProofEditor operation failed. Check network connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // Operations
  // ---------------------------------------------------------------------------

  Future<ToolResult> _create(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    final content = args['content'] as String?;
    if (title == null || title.isEmpty) {
      return ToolResult.error(
          'create operation requires "title" parameter.');
    }
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'create operation requires "content" parameter.');
    }

    final client = http.Client();
    try {
      final response = await _postJson(
        client,
        Uri.parse('$_baseUrl/share/markdown'),
        body: {'title': title, 'markdown': content},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return ToolResult.error(
            'Failed to create document (HTTP ${response.statusCode}).');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final slug = data['slug'] as String? ?? '';
      final token = data['accessToken'] as String? ?? '';
      final shareUrl = data['shareUrl'] as String? ?? '';

      if (slug.isEmpty || token.isEmpty) {
        return ToolResult.error(
            'ProofEditor returned incomplete data. Try again.');
      }

      await store.save(ProofDocument(
        slug: slug,
        token: token,
        title: title,
        shareUrl: shareUrl,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      ));

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Document created. Slug: $slug, URL: $shareUrl. '
            'Use slug "$slug" for subsequent operations.',
        forUser: '${l.proofDocCreated}: $title\n$shareUrl',
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _read(Map<String, dynamic> args) async {
    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = http.Client();
    try {
      final response = await _getWithRetry(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/state'),
        headers: _bearerHeaders(doc.token),
      );

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final markdown = data['markdown'] as String? ?? '';
      final marks = data['marks'] as List? ?? [];

      await store.updateLastAccessed(doc.slug);

      // Build comment summary
      final commentBuf = StringBuffer();
      for (final mark in marks) {
        if (mark is Map<String, dynamic>) {
          final type = mark['type'] as String? ?? '';
          final text = mark['text'] as String? ?? '';
          final quote = mark['quote'] as String? ?? '';
          if (type == 'comment' && text.isNotEmpty) {
            commentBuf.writeln('  Comment on "$quote": $text');
          }
        }
      }

      final truncated = markdown.length > _maxContentLength;
      final displayContent = truncated
          ? markdown.substring(0, _maxContentLength)
          : markdown;

      final llmBuf = StringBuffer();
      llmBuf.writeln('Document: ${doc.title} (slug: ${doc.slug})');
      llmBuf.writeln('URL: ${doc.shareUrl}');
      llmBuf.writeln('---');
      llmBuf.writeln(displayContent);
      if (truncated) {
        llmBuf.writeln(
            '\n[Truncated: showing $_maxContentLength of ${markdown.length} chars]');
      }
      if (commentBuf.isNotEmpty) {
        llmBuf.writeln('\nComments:');
        llmBuf.write(commentBuf);
      }

      final l = tr(locale);
      final preview = markdown.length > 500
          ? '${markdown.substring(0, 500)}...'
          : markdown;
      final truncNote = truncated
          ? '\n${l.proofDocTruncated(_maxContentLength, markdown.length)}'
          : '';

      return ToolResult.dual(
        forLLM: llmBuf.toString().trimRight(),
        forUser: '$preview$truncNote',
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _edit(Map<String, dynamic> args) async {
    final search = args['search'] as String?;
    final replace = args['replace'] as String?;
    if (search == null || search.isEmpty) {
      return ToolResult.error(
          'edit operation requires "search" parameter.');
    }
    if (replace == null) {
      return ToolResult.error(
          'edit operation requires "replace" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = http.Client();
    try {
      final response = await _postJson(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/edit'),
        headers: _bearerHeaders(doc.token),
        body: {
          'by': _agentBy,
          'operations': [
            {'op': 'replace', 'search': search, 'content': replace},
          ],
        },
      );

      if (response.statusCode == 409) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final code = errorData['code'] as String? ?? '';
        if (code == 'ANCHOR_NOT_FOUND') {
          return ToolResult.error(
              'Text not found in document. '
              'Re-read the document to see current content.');
        }
        return ToolResult.error(
            'Edit conflict. Re-read the document and try again.');
      }

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      final searchPreview =
          search.length > 60 ? '${search.substring(0, 60)}...' : search;
      final replacePreview =
          replace.length > 60 ? '${replace.substring(0, 60)}...' : replace;

      return ToolResult.dual(
        forLLM: 'Edit applied in document ${doc.slug}: '
            'replaced "$searchPreview" with "$replacePreview".',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _rewrite(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'rewrite operation requires "content" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/agent/${doc.slug}/ops')
          .replace(queryParameters: {'token': doc.token});
      final response = await _postJson(
        client,
        uri,
        headers: {'X-Agent-Id': _agentId},
        body: {
          'type': 'rewrite.apply',
          'by': _agentBy,
          'content': content,
        },
      );

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Full rewrite applied to document ${doc.slug}.',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _comment(Map<String, dynamic> args) async {
    final quote = args['quote'] as String?;
    final text = args['text'] as String?;
    if (quote == null || quote.isEmpty) {
      return ToolResult.error(
          'comment operation requires "quote" parameter.');
    }
    if (text == null || text.isEmpty) {
      return ToolResult.error(
          'comment operation requires "text" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/agent/${doc.slug}/ops')
          .replace(queryParameters: {'token': doc.token});
      final response = await _postJson(
        client,
        uri,
        headers: {'X-Agent-Id': _agentId},
        body: {
          'type': 'comment.add',
          'by': _agentBy,
          'quote': quote,
          'text': text,
        },
      );

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Comment added on "${quote.length > 60 ? '${quote.substring(0, 60)}...' : quote}" '
            'in document ${doc.slug}.',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _list() async {
    final docs = await store.loadAll();
    if (docs.isEmpty) {
      return ToolResult.simple(
          'No ProofEditor documents registered. '
          'Use operation "create" to create one.');
    }

    docs.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));

    final llmBuf = StringBuffer();
    llmBuf.writeln('ProofEditor documents (${docs.length}):');
    for (final doc in docs) {
      final age = DateTime.now().difference(doc.lastAccessedAt);
      final ageStr = age.inHours < 1
          ? '${age.inMinutes}m ago'
          : age.inDays < 1
              ? '${age.inHours}h ago'
              : '${age.inDays}d ago';
      llmBuf.writeln(
          '- "${doc.title}" (slug: ${doc.slug}, last edited: $ageStr)');
      llmBuf.writeln('  URL: ${doc.shareUrl}');
    }

    return ToolResult.dual(
      forLLM: llmBuf.toString().trimRight(),
      forUser: '${docs.length} document(s)',
    );
  }

  Future<ToolResult> _delete(Map<String, dynamic> args) async {
    final slug = _validateSlug(args['slug'] as String?);
    if (slug == null) {
      return ToolResult.error(
          'delete operation requires a valid "slug" parameter.');
    }

    final doc = await store.getBySlug(slug);
    if (doc == null) {
      return ToolResult.error('Document "$slug" not found in local registry.');
    }

    await store.remove(slug);

    final l = tr(locale);
    return ToolResult.dual(
      forLLM: 'Document "$slug" removed from local registry. '
          'The document still exists at ${doc.shareUrl}.',
      forUser: l.proofActionApplied,
    );
  }

  // ---------------------------------------------------------------------------
  // Document resolution
  // ---------------------------------------------------------------------------

  /// Resolve document: by URL import, by slug, or most recent.
  Future<ProofDocument?> _resolveDocument(Map<String, dynamic> args) async {
    // URL import takes priority
    final url = args['url'] as String?;
    if (url != null && url.isNotEmpty) {
      final doc = _importFromUrl(url);
      if (doc != null) {
        await store.save(doc);
        return doc;
      }
    }

    final slug = _validateSlug(args['slug'] as String?);
    if (slug != null) {
      final doc = await store.getBySlug(slug);
      if (doc != null) {
        await store.updateLastAccessed(slug);
        return doc;
      }
      return null;
    }

    return await store.getMostRecent();
  }

  /// Parse ProofEditor URL safely using Uri.parse (not regex).
  ProofDocument? _importFromUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.host != 'proofeditor.ai' && uri.host != 'www.proofeditor.ai') {
        return null;
      }
      final segments = uri.pathSegments;
      if (segments.length < 2) return null;
      final slug = segments[1];
      if (!_slugPattern.hasMatch(slug)) return null;

      final token = uri.queryParameters['token'];
      if (token == null || token.isEmpty) return null;

      return ProofDocument(
        slug: slug,
        token: token,
        title: '',
        shareUrl: '${uri.scheme}://${uri.host}/${segments.join('/')}',
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Validate slug format — alphanumeric, hyphens, underscores only.
  String? _validateSlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    if (!_slugPattern.hasMatch(slug)) return null;
    return slug;
  }

  ToolResult _noDocError(Map<String, dynamic> args) {
    final slug = args['slug'] as String?;
    if (slug != null && slug.isNotEmpty) {
      return ToolResult.error(
          'Document "$slug" not found. Use operation "list" to see known documents, '
          'or provide a ProofEditor URL via the "url" parameter.');
    }
    return ToolResult.error(
        'No document specified and no recent documents found. '
        'Use operation "create" to create one, or "list" to see known documents.');
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _bearerHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'X-Agent-Id': _agentId,
      };

  Future<http.Response> _postJson(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    return client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );
  }

  /// GET with retry on 429/5xx (exponential backoff).
  Future<http.Response> _getWithRetry(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final response = await client.get(uri, headers: headers);
      if (attempt < _maxRetries &&
          (response.statusCode == 429 || response.statusCode >= 500)) {
        await Future.delayed(
            Duration(milliseconds: 500 * (1 << attempt)));
        continue;
      }
      return response;
    }
    // Unreachable, but Dart requires a return.
    return client.get(uri, headers: headers);
  }

  /// Check HTTP response for common errors. Returns null if OK.
  ToolResult? _checkHttpError(http.Response response, String slug) {
    if (response.statusCode >= 200 && response.statusCode < 300) return null;

    switch (response.statusCode) {
      case 401:
      case 403:
        // Auto-remove stale token
        store.remove(slug);
        return ToolResult.error(
            'Document access denied. The share token may be invalid or expired. '
            'Ask the user for a new ProofEditor URL.');
      case 404:
        store.remove(slug);
        return ToolResult.error(
            'Document not found. It may have been deleted.');
      case 429:
        return ToolResult.error(
            'Rate limited by ProofEditor. Try again in a few seconds.');
      default:
        if (response.statusCode >= 500) {
          return ToolResult.error(
              'ProofEditor service is temporarily unavailable.');
        }
        return ToolResult.error(
            'ProofEditor request failed (HTTP ${response.statusCode}).');
    }
  }
}
