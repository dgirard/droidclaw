import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';
import '../config/log_entry.dart';
import '../services/app_logger.dart';
import 'proof_editor/proof_document_store.dart';
import 'proof_editor/proof_editor_client.dart';
import 'tool.dart';

/// Collaborative document editor via ProofEditor.ai.
///
/// Thin dispatcher: validates parameters, resolves the target document, and
/// formats [ToolResult]s. All HTTP transport (auth headers, retries, status
/// branching, conflict handling, token purge) lives in [ProofEditorClient].
///
/// Creates, reads, edits, and comments on shared markdown documents.
/// Uses per-document share tokens (no global API key). Tokens are stored
/// in [ProofDocumentStore] and never exposed in [ToolResult.forLLM].
class ProofEditorTool extends Tool {
  final ProofDocumentStore store;
  final String locale;
  final ProofEditorClient _client;

  static final _slugPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  static const _maxContentLength = 15000;

  ProofEditorTool({
    required this.store,
    this.locale = 'en',
    http.Client Function()? httpClientFactory,
  }) : _client = ProofEditorClient(
          store: store,
          httpClientFactory: httpClientFactory,
        );

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
      'DEPRECATED: "edit" and "insert" are no longer supported by the server '
      'and will fail — use "rewrite", "append", "suggest", or '
      '"snapshot"+"edit_v2" instead. '
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
            'description':
                'The operation to perform on a Proof document. '
                    '"edit" and "insert" are DEPRECATED (removed from the '
                    'live API, they always fail): use "rewrite", "append", '
                    '"suggest", or "snapshot"+"edit_v2" instead.',
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
            'description': 'Text to find in document (for deprecated edit)',
          },
          'replace': {
            'type': 'string',
            'description': 'Replacement text (for deprecated edit)',
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
      AppLogger.instance.error(LogSource.agent,
          '[ProofEditor] Operation "$operation" failed: $e');
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

    switch (await _client.createDocument(title: title, markdown: content)) {
      case ProofFailure(:final message):
        return ToolResult.error(message);
      case ProofSuccess(:final value):
        await store.save(ProofDocument(
          slug: value.slug,
          token: value.token,
          title: title,
          shareUrl: value.shareUrl,
          createdAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ));

        final l = tr(locale);
        return ToolResult.dual(
          forLLM: 'Document created. Slug: ${value.slug}, '
              'URL: ${value.shareUrl}. '
              'Use slug "${value.slug}" for subsequent operations.',
          forUser: '${l.proofDocCreated}: $title\n${value.shareUrl}',
        );
    }
  }

  Future<ToolResult> _read(Map<String, dynamic> args) async {
    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    switch (await _client.fetchState(doc)) {
      case ProofFailure(:final message):
        return ToolResult.error(message);
      case ProofSuccess(:final value):
        await store.updateLastAccessed(doc.slug);

        final markdown = value.markdown;

        // Build comment summary
        final commentBuf = StringBuffer();
        for (final mark in value.marks) {
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

    return switch (
        await _client.replaceText(doc, search: search, replace: replace)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() => await _applied(
          doc,
          'Edit applied in document ${doc.slug}: '
          'replaced "${_preview(search)}" with "${_preview(replace)}".'),
    };
  }

  Future<ToolResult> _rewrite(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'rewrite operation requires "content" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    return switch (await _client.rewriteDocument(doc, content: content)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() =>
        await _applied(doc, 'Full rewrite applied to document ${doc.slug}.'),
    };
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

    return switch (await _client.addComment(doc, quote: quote, text: text)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() => await _applied(doc,
          'Comment added on "${_preview(quote)}" in document ${doc.slug}.'),
    };
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

    return switch (
        await _client.addSuggestion(doc, quote: quote, content: content)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() => await _applied(
          doc,
          'Suggestion added on "${_preview(quote)}" in document ${doc.slug}. '
          'User can accept/reject in ProofEditor UI.'),
    };
  }

  Future<ToolResult> _prepend(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error(
          'prepend operation requires "content" parameter.');
    }

    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    return switch (await _client.prepend(doc, content: content)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() =>
        await _applied(doc, 'Content prepended to document ${doc.slug}.'),
    };
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

    return switch (
        await _client.appendToSection(doc, section: section, content: content)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() => await _applied(doc,
          'Content appended to section "$section" in document ${doc.slug}.'),
    };
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

    return switch (
        await _client.insertAfterAnchor(doc, quote: quote, content: content)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() => await _applied(doc,
          'Content inserted after "${_preview(quote)}" in document ${doc.slug}.'),
    };
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

    switch (await _client.renameDocument(doc, title: title)) {
      case ProofFailure(:final message):
        return ToolResult.error(message);
      case ProofSuccess():
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
    }
  }

  Future<ToolResult> _snapshot(Map<String, dynamic> args) async {
    final doc = await _resolveDocument(args);
    if (doc == null) return _noDocError(args);

    switch (await _client.fetchSnapshot(doc)) {
      case ProofFailure(:final message):
        return ToolResult.error(message);
      case ProofSuccess(:final value):
        await store.updateLastAccessed(doc.slug);

        // Format blocks with refs
        final llmBuf = StringBuffer();
        llmBuf.writeln('Document: "${doc.title}" (slug: ${doc.slug})');
        llmBuf.writeln('mutationBase: ${value.baseToken}');
        llmBuf.writeln('---');

        var truncated = false;
        var charCount = 0;
        for (final block in value.blocks) {
          if (block is Map<String, dynamic>) {
            final ref = block['ref'] as String? ?? '';
            final content = block['content'] as String? ?? '';
            final line = '[$ref] $content';
            charCount += line.length + 1;
            if (charCount > _maxContentLength) {
              truncated = true;
              llmBuf.writeln(
                  '\n[Truncated: showing $_maxContentLength of ~$charCount chars. '
                  '${value.blocks.length} total blocks.]');
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

    return switch (
        await _client.applyEditV2(doc, baseToken: baseToken, ops: ops)) {
      ProofFailure(:final message) => ToolResult.error(message),
      ProofSuccess() => await _applied(
          doc,
          'Block-level edits applied to document ${doc.slug} '
          '(${ops.length} operation(s)).'),
    };
  }

  // ---------------------------------------------------------------------------
  // Result formatting helpers
  // ---------------------------------------------------------------------------

  /// Mark the document as accessed and return the standard "applied" dual
  /// result for a successful mutation.
  Future<ToolResult> _applied(ProofDocument doc, String forLLM) async {
    await store.updateLastAccessed(doc.slug);
    return ToolResult.dual(
      forLLM: forLLM,
      forUser: tr(locale).proofActionApplied,
    );
  }

  String _preview(String text) =>
      text.length > 60 ? '${text.substring(0, 60)}...' : text;

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
}
