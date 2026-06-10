import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/log_entry.dart';
import '../../net/retrying_http_client.dart';
import '../../services/app_logger.dart';
import 'proof_document_store.dart';

/// Outcome of a ProofEditor API call.
sealed class ProofResult<T> {
  const ProofResult();
}

/// Successful call with the decoded payload.
class ProofSuccess<T> extends ProofResult<T> {
  final T value;
  const ProofSuccess(this.value);
}

/// Failed call. [message] is sanitized and user-actionable — it never
/// contains tokens or response bodies.
class ProofFailure<T> extends ProofResult<T> {
  final String message;
  const ProofFailure(this.message);
}

/// Decoded payload of `POST /share/markdown`.
class ProofCreatedDocument {
  final String slug;
  final String token;
  final String shareUrl;

  const ProofCreatedDocument({
    required this.slug,
    required this.token,
    required this.shareUrl,
  });
}

/// Decoded payload of `GET /api/agent/{slug}/state`.
class ProofDocumentState {
  final String markdown;

  /// Marks normalized to a list — the server returns either a Map (keyed by
  /// mark ID) or a List depending on version.
  final List<dynamic> marks;

  const ProofDocumentState({required this.markdown, required this.marks});
}

/// Decoded payload of `GET /api/agent/{slug}/snapshot`.
class ProofSnapshot {
  final List<dynamic> blocks;
  final String baseToken;

  const ProofSnapshot({required this.blocks, required this.baseToken});
}

/// Transport layer for ProofEditor.ai (extracted from ProofEditorTool, U18).
///
/// Owns URL construction, auth headers (Bearer token + X-Agent-Id — tokens
/// never appear in URLs), retrying GETs via the shared [RetryingHttpClient]
/// policy, status-code branching, and response decoding.
///
/// Security/robustness invariants (see
/// docs/solutions/security-issues/proof-editor-code-review-security-and-robustness-fixes.md):
/// - 409 conflict handling on every mutating call, including [prepend] and
///   [rewriteDocument] (optimistic concurrency via a `/state` fetch whose
///   `mutationBase.token` is sent as `baseToken`).
/// - Sanitized error logging: status code + slug only, never response bodies
///   (they may contain document content, PII, or tokens).
/// - 401/403/404 responses purge the stale token from the local
///   [ProofDocumentStore].
///
/// ## API drift notes (investigated live 2026-06-10, U18)
///
/// The legacy `POST /api/agent/{slug}/edit` route was removed server-side
/// (returns 404 "Unsupported agent route"), and `/ops` mutations now accept
/// only `baseToken` (`state.mutationBase.token`, schema `mt1:...`) as a
/// concurrency precondition — `baseRevision` is rejected with
/// "rewrite.apply only accepts baseToken on the public agent contract"
/// (`state.contract.supportedPreconditions == ["baseToken"]`).
///
/// Fixed in this client (verified against a live throwaway document):
/// - [rewriteDocument] and [prepend] send `baseToken: mutationBase.token`
///   instead of `baseRevision`/`updatedAt`.
/// - [appendToSection] no longer posts to the removed `/edit` route; it reads
///   `/state`, splices the content at the end of the target section locally,
///   and applies `rewrite.apply` via `/ops` — the same verified flow as
///   [prepend].
///
/// Still on the removed `/edit` route (known-broken against the live API,
/// kept as-is until replacement semantics are verified):
/// - [replaceText] (`edit` operation) — candidate replacement:
///   `POST /edit/v2` with a `find_replace_in_doc` operation
///   (`{find, replace, occurrence}`) plus `baseToken`.
/// - [insertAfterAnchor] (`insert` operation) — candidate replacements:
///   `/ops` `suggestion.add` with `kind: "insert", status: "accepted"`
///   (leaves an audit mark) or `/edit/v2` `insert_after` (requires a block
///   ref from `/snapshot` instead of a text anchor).
/// Both candidates change conflict/error semantics (the 409
/// `ANCHOR_NOT_FOUND` mapping is pinned by unit tests) and were not
/// exercised live, so they were left out of the U18 extraction.
class ProofEditorClient {
  /// Local registry — used to purge stale tokens on 401/403/404.
  final ProofDocumentStore store;
  final http.Client Function() _clientFactory;

  static const baseUrl = 'https://www.proofeditor.ai';
  static const agentId = 'droidclaw';
  static const agentBy = 'ai:droidclaw';
  static const _maxRetries = 2;

  ProofEditorClient({
    required this.store,
    http.Client Function()? httpClientFactory,
  }) : _clientFactory = (httpClientFactory ?? http.Client.new);

  // ---------------------------------------------------------------------------
  // Operations
  // ---------------------------------------------------------------------------

  /// `POST /share/markdown` — create a new shared document.
  Future<ProofResult<ProofCreatedDocument>> createDocument({
    required String title,
    required String markdown,
  }) =>
      _withClient((client) async {
        final response = await _postJson(
          client,
          Uri.parse('$baseUrl/share/markdown'),
          body: {'title': title, 'markdown': markdown},
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          return ProofFailure(
              'Failed to create document (HTTP ${response.statusCode}).');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final slug = data['slug'] as String? ?? '';
        final token = data['accessToken'] as String? ?? '';
        final shareUrl = data['shareUrl'] as String? ?? '';

        if (slug.isEmpty || token.isEmpty) {
          return const ProofFailure(
              'ProofEditor returned incomplete data. Try again.');
        }

        return ProofSuccess(ProofCreatedDocument(
          slug: slug,
          token: token,
          shareUrl: shareUrl,
        ));
      });

  /// `GET /api/agent/{slug}/state` — current markdown + marks.
  Future<ProofResult<ProofDocumentState>> fetchState(ProofDocument doc) =>
      _withClient((client) async {
        final response = await _getWithRetry(
          client,
          _stateUri(doc.slug),
          headers: _bearerHeaders(doc.token),
        );

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final markdown = data['markdown'] as String? ?? '';
        // marks can be a Map (keyed by ID) or a List — handle both.
        final rawMarks = data['marks'];
        final marks = rawMarks is List
            ? rawMarks
            : rawMarks is Map
                ? rawMarks.values.toList()
                : <dynamic>[];

        return ProofSuccess(
            ProofDocumentState(markdown: markdown, marks: marks));
      });

  /// `POST /api/agent/{slug}/edit` — search/replace ("edit" operation).
  ///
  /// NOTE: this route was removed from the live API (see API drift notes in
  /// the class doc comment) — kept until the `/edit/v2` replacement
  /// semantics are verified.
  Future<ProofResult<void>> replaceText(
    ProofDocument doc, {
    required String search,
    required String replace,
  }) =>
      _legacyEdit(
        doc,
        operation: {'op': 'replace', 'search': search, 'content': replace},
        anchorNotFoundMessage: 'Text not found in document. '
            'Re-read the document to see current content.',
        conflictMessage: 'Edit conflict. Re-read the document and try again.',
      );

  /// `POST /api/agent/{slug}/ops` `rewrite.apply` — full document rewrite
  /// with optimistic concurrency (`baseToken` from a `/state` fetch).
  Future<ProofResult<void>> rewriteDocument(
    ProofDocument doc, {
    required String content,
  }) =>
      _rewriteTransformed(
        doc,
        (_) => content,
        conflictVerb: 'Rewrite',
        // A failed state fetch is tolerated: proceed without a precondition.
        tolerateStateFailure: true,
      );

  /// Prepend content at the very top: read `/state`, then `rewrite.apply`
  /// with the new content first, carrying the `baseToken` precondition.
  Future<ProofResult<void>> prepend(
    ProofDocument doc, {
    required String content,
  }) =>
      _rewriteTransformed(
        doc,
        (current) => '$content\n\n$current',
        conflictVerb: 'Prepend',
      );

  /// Append content at the end of the section titled [section]: read
  /// `/state`, splice locally, then `rewrite.apply` with the `baseToken`
  /// precondition (the legacy `/edit` append op was removed server-side).
  Future<ProofResult<void>> appendToSection(
    ProofDocument doc, {
    required String section,
    required String content,
  }) =>
      _rewriteTransformed(
        doc,
        (current) => spliceIntoSection(current, section, content),
        conflictVerb: 'Append',
        transformFailureMessage: 'Append failed — section may not exist. '
            'Re-read the document to see current sections.',
      );

  /// `POST /api/agent/{slug}/edit` — insert content after an anchor quote.
  ///
  /// NOTE: this route was removed from the live API (see API drift notes in
  /// the class doc comment) — kept until a replacement is verified.
  Future<ProofResult<void>> insertAfterAnchor(
    ProofDocument doc, {
    required String quote,
    required String content,
  }) =>
      _legacyEdit(
        doc,
        operation: {
          'op': 'insert',
          'target': {'anchor': quote},
          'content': content,
        },
        anchorNotFoundMessage: 'Anchor text not found in document. '
            'Re-read the document to see current content.',
        conflictMessage:
            'Insert conflict. Re-read the document and try again.',
      );

  /// `POST /api/agent/{slug}/ops` `comment.add`.
  Future<ProofResult<void>> addComment(
    ProofDocument doc, {
    required String quote,
    required String text,
  }) =>
      _withClient((client) async {
        // SECURITY: token goes in the Authorization header, never in the URL.
        final response = await _postJson(
          client,
          _opsUri(doc.slug),
          headers: _bearerHeaders(doc.token),
          body: {
            'type': 'comment.add',
            'by': agentBy,
            'quote': quote,
            'text': text,
          },
        );

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);
        return const ProofSuccess(null);
      });

  /// `POST /api/agent/{slug}/ops` `suggestion.add` (pending replace).
  Future<ProofResult<void>> addSuggestion(
    ProofDocument doc, {
    required String quote,
    required String content,
  }) =>
      _withClient((client) async {
        // SECURITY: token goes in the Authorization header, never in the URL.
        final response = await _postJson(
          client,
          _opsUri(doc.slug),
          headers: _bearerHeaders(doc.token),
          body: {
            'type': 'suggestion.add',
            'kind': 'replace',
            'by': agentBy,
            'quote': quote,
            'content': content,
          },
        );

        if (response.statusCode == 409) {
          return const ProofFailure(
              'Quoted text not found in document. '
              'Re-read the document to see current content.');
        }

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);
        return const ProofSuccess(null);
      });

  /// `PUT /api/documents/{slug}/title` — rename the document.
  Future<ProofResult<void>> renameDocument(
    ProofDocument doc, {
    required String title,
  }) =>
      _withClient((client) async {
        final response = await _putJson(
          client,
          Uri.parse('$baseUrl/api/documents/${doc.slug}/title'),
          headers: _bearerHeaders(doc.token),
          body: {'title': title},
        );

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);
        return const ProofSuccess(null);
      });

  /// `GET /api/agent/{slug}/snapshot` — block refs + mutation base token.
  Future<ProofResult<ProofSnapshot>> fetchSnapshot(ProofDocument doc) =>
      _withClient((client) async {
        final response = await _getWithRetry(
          client,
          Uri.parse('$baseUrl/api/agent/${doc.slug}/snapshot'),
          headers: _bearerHeaders(doc.token),
        );

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final blocks = data['blocks'] as List? ?? [];
        final mutationBase =
            data['mutationBase'] as Map<String, dynamic>? ?? {};
        final baseToken = mutationBase['token'] as String? ?? '';

        return ProofSuccess(
            ProofSnapshot(blocks: blocks, baseToken: baseToken));
      });

  /// `POST /api/agent/{slug}/edit/v2` — block-level edits against a
  /// snapshot's mutation base token, with an Idempotency-Key.
  Future<ProofResult<void>> applyEditV2(
    ProofDocument doc, {
    required String baseToken,
    required List<dynamic> ops,
  }) =>
      _withClient((client) async {
        final response = await _postJson(
          client,
          Uri.parse('$baseUrl/api/agent/${doc.slug}/edit/v2'),
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
          return const ProofFailure(
              'Document changed since snapshot. '
              'Use operation "snapshot" to get current state, then retry.');
        }

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);
        return const ProofSuccess(null);
      });

  // ---------------------------------------------------------------------------
  // Shared operation flows
  // ---------------------------------------------------------------------------

  /// Run [body] with a fresh client from the factory, always closing it.
  Future<ProofResult<T>> _withClient<T>(
      Future<ProofResult<T>> Function(http.Client client) body) async {
    final client = _clientFactory();
    try {
      return await body(client);
    } finally {
      client.close();
    }
  }

  /// Shared flow for the rewrite-based mutations ([rewriteDocument],
  /// [prepend], [appendToSection]): fetch `/state` for the current markdown
  /// and `baseToken`, run [transform] on the current content, `rewrite.apply`
  /// via `/ops`, and map a 409 to "[conflictVerb] conflict".
  ///
  /// When [tolerateStateFailure] is true a failed state fetch is silently
  /// tolerated (the rewrite proceeds without a precondition — the
  /// [rewriteDocument] semantics); otherwise state errors are surfaced.
  /// A null return from [transform] fails with [transformFailureMessage].
  Future<ProofResult<void>> _rewriteTransformed(
    ProofDocument doc,
    String? Function(String current) transform, {
    required String conflictVerb,
    bool tolerateStateFailure = false,
    String? transformFailureMessage,
  }) =>
      _withClient((client) async {
        final stateResponse = await _getWithRetry(
          client,
          _stateUri(doc.slug),
          headers: _bearerHeaders(doc.token),
        );

        var currentMarkdown = '';
        String? baseToken;
        if (tolerateStateFailure) {
          if (stateResponse.statusCode >= 200 &&
              stateResponse.statusCode < 300) {
            final stateData =
                jsonDecode(stateResponse.body) as Map<String, dynamic>;
            currentMarkdown = stateData['markdown'] as String? ?? '';
            baseToken = _mutationBaseToken(stateData);
          }
        } else {
          final stateError = _checkHttpError(stateResponse, doc.slug);
          if (stateError != null) return ProofFailure(stateError);
          final stateData =
              jsonDecode(stateResponse.body) as Map<String, dynamic>;
          currentMarkdown = stateData['markdown'] as String? ?? '';
          baseToken = _mutationBaseToken(stateData);
        }

        final newMarkdown = transform(currentMarkdown);
        if (newMarkdown == null) {
          return ProofFailure(transformFailureMessage ??
              '$conflictVerb failed. Re-read the document and try again.');
        }

        final response =
            await _applyRewrite(client, doc, newMarkdown, baseToken);
        if (response.statusCode == 409) {
          return ProofFailure(
              '$conflictVerb conflict — document was modified. '
              'Re-read the document and try again.');
        }

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);
        return const ProofSuccess(null);
      });

  /// Shared flow for the legacy `/edit` operations ([replaceText],
  /// [insertAfterAnchor]): fetch `baseUpdatedAt`, POST the single
  /// [operation], and map a 409 to [anchorNotFoundMessage] (code
  /// `ANCHOR_NOT_FOUND`) or [conflictMessage].
  Future<ProofResult<void>> _legacyEdit(
    ProofDocument doc, {
    required Map<String, dynamic> operation,
    required String anchorNotFoundMessage,
    required String conflictMessage,
  }) =>
      _withClient((client) async {
        final baseUpdatedAt = await _fetchBaseUpdatedAt(client, doc);
        final body = <String, dynamic>{
          'by': agentBy,
          'operations': [operation],
        };
        if (baseUpdatedAt != null) body['baseUpdatedAt'] = baseUpdatedAt;

        final response = await _postJson(
          client,
          _editUri(doc.slug),
          headers: _bearerHeaders(doc.token),
          body: body,
        );

        if (response.statusCode == 409) {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final code = errorData['code'] as String? ?? '';
          if (code == 'ANCHOR_NOT_FOUND') {
            return ProofFailure(anchorNotFoundMessage);
          }
          return ProofFailure(conflictMessage);
        }

        final error = _checkHttpError(response, doc.slug);
        if (error != null) return ProofFailure(error);
        return const ProofSuccess(null);
      });

  // ---------------------------------------------------------------------------
  // Markdown section splice (used by appendToSection)
  // ---------------------------------------------------------------------------

  /// Return [markdown] with [content] appended at the end of the section
  /// whose heading text matches [section] (with or without leading `#`s),
  /// or null if no such heading exists. A section ends at the next heading
  /// of the same or higher level, or at the end of the document.
  static String? spliceIntoSection(
      String markdown, String section, String content) {
    final headingPattern = RegExp(r'^(#{1,6})\s+(.*?)\s*$');
    final wanted =
        section.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
    if (wanted.isEmpty) return null;

    final lines = markdown.split('\n');
    var matchLevel = 0;
    var matchIdx = -1;
    var endIdx = lines.length;

    for (var i = 0; i < lines.length; i++) {
      final m = headingPattern.firstMatch(lines[i]);
      if (m == null) continue;
      if (matchIdx < 0) {
        if (m.group(2)!.trim() == wanted) {
          matchIdx = i;
          matchLevel = m.group(1)!.length;
        }
      } else if (m.group(1)!.length <= matchLevel) {
        endIdx = i;
        break;
      }
    }
    if (matchIdx < 0) return null;

    final before = lines.sublist(0, endIdx);
    final after = lines.sublist(endIdx);
    while (before.isNotEmpty && before.last.trim().isEmpty) {
      before.removeLast();
    }
    return [...before, '', content, if (after.isNotEmpty) '', ...after]
        .join('\n');
  }

  // ---------------------------------------------------------------------------
  // State helpers
  // ---------------------------------------------------------------------------

  /// Fetch the current document state to get baseUpdatedAt for legacy /edit
  /// operations (replaceText, insertAfterAnchor). A failed fetch is
  /// tolerated (returns null — the edit proceeds without a precondition).
  Future<String?> _fetchBaseUpdatedAt(
      http.Client client, ProofDocument doc) async {
    final response = await _getWithRetry(
      client,
      _stateUri(doc.slug),
      headers: _bearerHeaders(doc.token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['updatedAt'] as String?;
  }

  /// Extract `mutationBase.token` from a decoded /state payload — the only
  /// concurrency precondition the live /ops contract accepts.
  static String? _mutationBaseToken(Map<String, dynamic> stateData) {
    final mutationBase = stateData['mutationBase'];
    if (mutationBase is Map) {
      final token = mutationBase['token'];
      if (token is String && token.isNotEmpty) return token;
    }
    return null;
  }

  /// POST a `rewrite.apply` op, carrying [baseToken] when available.
  Future<http.Response> _applyRewrite(
    http.Client client,
    ProofDocument doc,
    String content,
    String? baseToken,
  ) {
    // SECURITY: token goes in the Authorization header, never in the URL.
    return _postJson(
      client,
      _opsUri(doc.slug),
      headers: _bearerHeaders(doc.token),
      body: {
        'type': 'rewrite.apply',
        'by': agentBy,
        'content': content,
        'baseToken': ?baseToken,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HTTP plumbing
  // ---------------------------------------------------------------------------

  Uri _stateUri(String slug) => Uri.parse('$baseUrl/api/agent/$slug/state');
  Uri _opsUri(String slug) => Uri.parse('$baseUrl/api/agent/$slug/ops');
  Uri _editUri(String slug) => Uri.parse('$baseUrl/api/agent/$slug/edit');

  Map<String, String> get _baseHeaders => {'X-DroidClaw-App': agentId};

  Map<String, String> _bearerHeaders(String token) => {
        ..._baseHeaders,
        'Authorization': 'Bearer $token',
        'X-Agent-Id': agentId,
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
    // lifecycle stays with the operation methods.
    return RetryingHttpClient(inner: client, maxRetries: _maxRetries)
        .get(uri, headers: {..._baseHeaders, ...?headers});
  }

  /// Check HTTP response for common errors. Returns the sanitized error
  /// message, or null if OK. Purges the stale token on 401/403/404.
  String? _checkHttpError(http.Response response, String slug) {
    if (response.statusCode >= 200 && response.statusCode < 300) return null;

    // SECURITY: log status code + slug only — response body may contain
    // tokens or PII.
    AppLogger.instance.warning(LogSource.agent,
        '[ProofEditor] HTTP ${response.statusCode} for slug "$slug"');

    switch (response.statusCode) {
      case 401:
      case 403:
        // Auto-remove stale token
        store.remove(slug);
        return 'Document access denied. The share token may be invalid or '
            'expired. Ask the user for a new ProofEditor URL.';
      case 404:
        store.remove(slug);
        return 'Document not found. It may have been deleted.';
      case 429:
        return 'Rate limited by ProofEditor. Try again in a few seconds.';
      default:
        if (response.statusCode >= 500) {
          return 'ProofEditor service is temporarily unavailable.';
        }
        return 'ProofEditor request failed '
            '(HTTP ${response.statusCode}).';
    }
  }
}
