import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';
import '../net/retrying_http_client.dart';
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
  final http.Client Function() _clientFactory;

  static const _baseUrl = 'https://www.proofeditor.ai';
  static const _agentId = 'droidclaw';
  static const _agentBy = 'ai:droidclaw';
  static final _slugPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  static const _maxContentLength = 15000;
  static const _maxRetries = 2;

  ProofEditorTool({
    required this.store,
    this.locale = 'en',
    http.Client Function()? httpClientFactory,
  }) : _clientFactory = (httpClientFactory ?? http.Client.new);

  @override
  String get name => 'proof_editor';

  @override
  String get description =>
      'Collaborative document editor via ProofEditor.ai. '
      'Create, read, edit, suggest changes, comment on, and manage shared markdown documents. '
      'Use "snapshot" + "edit_v2" for precise block-level edits (use "markdown" key, not "content", in ops). '
      'Use "suggest" to propose changes the user can accept/reject. '
      'Use "prepend" to add content at the very top of the document. '
      'Use "append" with a "section" heading to add content under a specific section. '
      'Documents persist across sessions and are accessible via shareable URLs.';

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
              'suggest',
              'prepend',
              'append',
              'insert',
              'rename',
              'snapshot',
              'edit_v2',
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
            'description':
                'Markdown content (for create, rewrite, suggest, prepend, append, insert). '
                    'For edit_v2, use "markdown" key inside ops array instead.',
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
            'description':
                'Text to anchor on (for comment, suggest, insert)',
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
          'section': {
            'type': 'string',
            'description':
                'Markdown heading text to append under (required for append). '
                    'Use "read" first to see available sections.',
          },
          'base_token': {
            'type': 'string',
            'description':
                'Mutation base token from a prior snapshot (required for edit_v2)',
          },
          'ops': {
            'type': 'array',
            'description':
                'Block-level operations array (for edit_v2). '
                    'Each item: {op: "replace_block", ref: "bN", markdown: "..."} '
                    'or {op: "insert_after", ref: "bN", blocks: [{markdown: "..."}]}',
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
        'suggest' => await _suggest(arguments),
        'prepend' => await _prepend(arguments),
        'append' => await _append(arguments),
        'insert' => await _insert(arguments),
        'rename' => await _rename(arguments),
        'snapshot' => await _snapshot(arguments),
        'edit_v2' => await _editV2(arguments),
        'list' => await _list(),
        'delete' => await _delete(arguments),
        _ => ToolResult.error(
            'Unknown operation: $operation. '
            'Valid: create, read, edit, rewrite, comment, suggest, prepend, '
            'append, insert, rename, snapshot, edit_v2, list, delete.'),
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

    final client = _clientFactory();
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

    final client = _clientFactory();
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
      // marks can be a Map (keyed by ID) or a List — handle both
      final rawMarks = data['marks'];
      final marksList = rawMarks is List
          ? rawMarks
          : rawMarks is Map
              ? rawMarks.values.toList()
              : <dynamic>[];

      await store.updateLastAccessed(doc.slug);

      // Build comment summary
      final commentBuf = StringBuffer();
      for (final mark in marksList) {
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

    final client = _clientFactory();
    try {
      final baseUpdatedAt = await _fetchBaseUpdatedAt(client, doc);
      final body = <String, dynamic>{
        'by': _agentBy,
        'operations': [
          {'op': 'replace', 'search': search, 'content': replace},
        ],
      };
      if (baseUpdatedAt != null) body['baseUpdatedAt'] = baseUpdatedAt;

      final response = await _postJson(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/edit'),
        headers: _bearerHeaders(doc.token),
        body: body,
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

    final client = _clientFactory();
    try {
      // Fetch revision for optimistic concurrency on the /ops endpoint.
      final stateResponse = await _getWithRetry(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/state'),
        headers: _bearerHeaders(doc.token),
      );
      int? revision;
      String? updatedAt;
      if (stateResponse.statusCode >= 200 && stateResponse.statusCode < 300) {
        final stateData =
            jsonDecode(stateResponse.body) as Map<String, dynamic>;
        revision = stateData['revision'] as int?;
        updatedAt = stateData['updatedAt'] as String?;
      }

      // SECURITY: token goes in the Authorization header, never in the URL.
      final uri = Uri.parse('$_baseUrl/api/agent/${doc.slug}/ops');
      final rewriteBody = <String, dynamic>{
        'type': 'rewrite.apply',
        'by': _agentBy,
        'content': content,
      };
      if (revision != null) {
        rewriteBody['baseRevision'] = revision;
      } else if (updatedAt != null) {
        rewriteBody['baseToken'] = updatedAt;
      }
      final response = await _postJson(
        client,
        uri,
        headers: _bearerHeaders(doc.token),
        body: rewriteBody,
      );

      if (response.statusCode == 409) {
        return ToolResult.error(
            'Rewrite conflict — document was modified. '
            'Re-read the document and try again.');
      }

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

    final client = _clientFactory();
    try {
      // SECURITY: token goes in the Authorization header, never in the URL.
      final uri = Uri.parse('$_baseUrl/api/agent/${doc.slug}/ops');
      final response = await _postJson(
        client,
        uri,
        headers: _bearerHeaders(doc.token),
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

  Future<ToolResult> _suggest(Map<String, dynamic> args) async {
    final quote = args['quote'] as String?;
    final content = args['content'] as String?;
    if (quote == null || quote.isEmpty) {
      return ToolResult.error(
          'suggest operation requires "quote" parameter.');
    }
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'suggest operation requires "content" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      // SECURITY: token goes in the Authorization header, never in the URL.
      final uri = Uri.parse('$_baseUrl/api/agent/${doc.slug}/ops');
      final response = await _postJson(
        client,
        uri,
        headers: _bearerHeaders(doc.token),
        body: {
          'type': 'suggestion.add',
          'kind': 'replace',
          'by': _agentBy,
          'quote': quote,
          'content': content,
        },
      );

      if (response.statusCode == 409) {
        return ToolResult.error(
            'Quoted text not found in document. '
            'Re-read the document to see current content.');
      }

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Suggestion added on "${quote.length > 60 ? '${quote.substring(0, 60)}...' : quote}" '
            'in document ${doc.slug}. User can accept/reject in ProofEditor UI.',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _prepend(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'prepend operation requires "content" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      // 1. Read current document content.
      final stateResponse = await _getWithRetry(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/state'),
        headers: _bearerHeaders(doc.token),
      );

      final stateError = _checkHttpError(stateResponse, doc.slug);
      if (stateError != null) return stateError;

      final stateData =
          jsonDecode(stateResponse.body) as Map<String, dynamic>;
      final currentMarkdown = stateData['markdown'] as String? ?? '';
      final revision = stateData['revision'] as int?;
      final updatedAt = stateData['updatedAt'] as String?;

      // 2. Prepend new content and rewrite the whole document.
      final newMarkdown = '$content\n\n$currentMarkdown';

      // SECURITY: token goes in the Authorization header, never in the URL.
      final uri = Uri.parse('$_baseUrl/api/agent/${doc.slug}/ops');
      final rewriteBody = <String, dynamic>{
        'type': 'rewrite.apply',
        'by': _agentBy,
        'content': newMarkdown,
      };
      if (revision != null) {
        rewriteBody['baseRevision'] = revision;
      } else if (updatedAt != null) {
        rewriteBody['baseToken'] = updatedAt;
      }
      final response = await _postJson(
        client,
        uri,
        headers: _bearerHeaders(doc.token),
        body: rewriteBody,
      );

      if (response.statusCode == 409) {
        return ToolResult.error(
            'Prepend conflict — document was modified. '
            'Re-read the document and try again.');
      }

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Content prepended to document ${doc.slug}.',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _append(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    final section = args['section'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'append operation requires "content" parameter.');
    }
    if (section == null || section.isEmpty) {
      return ToolResult.error(
          'append operation requires "section" parameter '
          '(the markdown heading text to append under). '
          'Use "read" first to see available sections.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      final baseUpdatedAt = await _fetchBaseUpdatedAt(client, doc);
      final op = <String, dynamic>{
        'op': 'append',
        'section': section,
        'content': content,
      };

      final body = <String, dynamic>{
        'by': _agentBy,
        'operations': [op],
      };
      if (baseUpdatedAt != null) body['baseUpdatedAt'] = baseUpdatedAt;

      final response = await _postJson(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/edit'),
        headers: _bearerHeaders(doc.token),
        body: body,
      );

      if (response.statusCode == 409) {
        return ToolResult.error(
            'Append failed — section may not exist. '
            'Re-read the document to see current sections.');
      }

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      final target = 'section "$section"';
      return ToolResult.dual(
        forLLM: 'Content appended to $target in document ${doc.slug}.',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _insert(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    final quote = args['quote'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'insert operation requires "content" parameter.');
    }
    if (quote == null || quote.isEmpty) {
      return ToolResult.error(
          'insert operation requires "quote" parameter (anchor text).');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      final baseUpdatedAt = await _fetchBaseUpdatedAt(client, doc);
      final body = <String, dynamic>{
        'by': _agentBy,
        'operations': [
          {
            'op': 'insert',
            'target': {'anchor': quote},
            'content': content,
          },
        ],
      };
      if (baseUpdatedAt != null) body['baseUpdatedAt'] = baseUpdatedAt;

      final response = await _postJson(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/edit'),
        headers: _bearerHeaders(doc.token),
        body: body,
      );

      if (response.statusCode == 409) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final code = errorData['code'] as String? ?? '';
        if (code == 'ANCHOR_NOT_FOUND') {
          return ToolResult.error(
              'Anchor text not found in document. '
              'Re-read the document to see current content.');
        }
        return ToolResult.error(
            'Insert conflict. Re-read the document and try again.');
      }

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Content inserted after "${quote.length > 60 ? '${quote.substring(0, 60)}...' : quote}" '
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

  Future<ToolResult> _rename(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    if (title == null || title.isEmpty) {
      return ToolResult.error(
          'rename operation requires "title" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      final response = await _putJson(
        client,
        Uri.parse('$_baseUrl/api/documents/${doc.slug}/title'),
        headers: _bearerHeaders(doc.token),
        body: {'title': title},
      );

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      // Update local store with new title
      await store.save(doc.copyWith(
        title: title,
        lastAccessedAt: DateTime.now(),
      ));

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Document ${doc.slug} renamed to "$title".',
        forUser: l.proofDocRenamed(title),
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _snapshot(Map<String, dynamic> args) async {
    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      final response = await _getWithRetry(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/snapshot'),
        headers: _bearerHeaders(doc.token),
      );

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final blocks = data['blocks'] as List? ?? [];
      final mutationBase = data['mutationBase'] as Map<String, dynamic>? ?? {};
      final baseToken = mutationBase['token'] as String? ?? '';

      await store.updateLastAccessed(doc.slug);

      // Format blocks with refs
      final llmBuf = StringBuffer();
      llmBuf.writeln('Document: "${doc.title}" (slug: ${doc.slug})');
      llmBuf.writeln('mutationBase: $baseToken');
      llmBuf.writeln('---');

      var truncated = false;
      var charCount = 0;
      for (final block in blocks) {
        if (block is Map<String, dynamic>) {
          final ref = block['ref'] as String? ?? '';
          final content = block['content'] as String? ?? '';
          final line = '[$ref] $content';
          charCount += line.length + 1;
          if (charCount > _maxContentLength) {
            truncated = true;
            llmBuf.writeln(
                '\n[Truncated: showing $_maxContentLength of ~$charCount chars. '
                '${blocks.length} total blocks.]');
            break;
          }
          llmBuf.writeln(line);
        }
      }

      final l = tr(locale);
      final preview = llmBuf.toString();
      final userPreview = preview.length > 500
          ? '${preview.substring(0, 500)}...'
          : preview;
      final truncNote = truncated
          ? '\n${l.proofDocTruncated(_maxContentLength, charCount)}'
          : '';

      return ToolResult.dual(
        forLLM: llmBuf.toString().trimRight(),
        forUser: '$userPreview$truncNote',
      );
    } finally {
      client.close();
    }
  }

  Future<ToolResult> _editV2(Map<String, dynamic> args) async {
    final baseToken = args['base_token'] as String?;
    final ops = args['ops'] as List?;
    if (baseToken == null || baseToken.isEmpty) {
      return ToolResult.error(
          'edit_v2 operation requires "base_token" parameter '
          '(from a prior snapshot).');
    }
    if (ops == null || ops.isEmpty) {
      return ToolResult.error(
          'edit_v2 operation requires "ops" parameter '
          '(array of block-level operations).');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    final client = _clientFactory();
    try {
      final response = await _postJson(
        client,
        Uri.parse('$_baseUrl/api/agent/${doc.slug}/edit/v2'),
        headers: {
          ..._bearerHeaders(doc.token),
          'Idempotency-Key': _idempotencyKey(),
        },
        body: {
          'baseToken': baseToken,
          'operations': ops,
        },
      );

      if (response.statusCode == 409) {
        return ToolResult.error(
            'Document changed since snapshot. '
            'Use operation "snapshot" to get current state, then retry.');
      }

      final error = _checkHttpError(response, doc.slug);
      if (error != null) return error;

      await store.updateLastAccessed(doc.slug);

      final l = tr(locale);
      return ToolResult.dual(
        forLLM: 'Block-level edits applied to document ${doc.slug} '
            '(${ops.length} operation(s)).',
        forUser: l.proofActionApplied,
      );
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // State helpers
  // ---------------------------------------------------------------------------

  /// Fetch the current document state to get baseUpdatedAt for edit operations.
  /// Only needed for the /edit endpoint (edit, append, insert).
  /// The /ops endpoint (rewrite, comment, suggest) handles concurrency differently.
  Future<String?> _fetchBaseUpdatedAt(
      http.Client client, ProofDocument doc) async {
    final response = await _getWithRetry(
      client,
      Uri.parse('$_baseUrl/api/agent/${doc.slug}/state'),
      headers: _bearerHeaders(doc.token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['updatedAt'] as String?;
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

  Map<String, String> get _baseHeaders => {'X-DroidClaw-App': _agentId};

  Map<String, String> _bearerHeaders(String token) => {
        ..._baseHeaders,
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
        ..._baseHeaders,
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _putJson(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    return client.put(
      uri,
      headers: {
        ..._baseHeaders,
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );
  }

  String _idempotencyKey() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  /// GET with retry on 429/5xx — delegates to the shared policy (U16),
  /// which matches the previous inline loop (2 retries, 500ms·2^attempt).
  Future<http.Response> _getWithRetry(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
  }) {
    // Injected inner client → close() is a no-op; the per-operation client
    // lifecycle stays with the call sites.
    return RetryingHttpClient(inner: client, maxRetries: _maxRetries)
        .get(uri, headers: {..._baseHeaders, ...?headers});
  }

  /// Check HTTP response for common errors. Returns null if OK.
  ToolResult? _checkHttpError(http.Response response, String slug) {
    if (response.statusCode >= 200 && response.statusCode < 300) return null;

    // Log status code only — response body may contain tokens.
    print('[ProofEditor] HTTP ${response.statusCode} for slug "$slug"');

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
