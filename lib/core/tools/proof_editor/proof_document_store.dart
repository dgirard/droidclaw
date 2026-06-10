import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/log_entry.dart';
import '../../services/app_logger.dart';

/// Metadata for a ProofEditor document (slug, token, title, URL).
class ProofDocument {
  final String slug;
  final String token;
  final String title;
  final String shareUrl;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

  ProofDocument({
    required this.slug,
    required this.token,
    required this.title,
    required this.shareUrl,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  factory ProofDocument.fromJson(Map<String, dynamic> json) => ProofDocument(
        slug: json['slug'] as String,
        token: json['token'] as String,
        title: json['title'] as String? ?? '',
        shareUrl: json['shareUrl'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastAccessedAt:
            DateTime.tryParse(json['lastAccessedAt'] as String? ?? '') ??
                DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'token': token,
        'title': title,
        'shareUrl': shareUrl,
        'createdAt': createdAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  ProofDocument copyWith({
    String? title,
    String? shareUrl,
    DateTime? lastAccessedAt,
  }) =>
      ProofDocument(
        slug: slug,
        token: token,
        title: title ?? this.title,
        shareUrl: shareUrl ?? this.shareUrl,
        createdAt: createdAt,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      );
}

/// Persistent registry of ProofEditor documents.
///
/// Stored as a JSON file in the app documents directory (NOT workspace)
/// so the `file` tool cannot read tokens. Uses atomic writes (write-to-tmp
/// + rename) for cross-isolate safety, and an async mutex for
/// within-isolate read-modify-write protection.
class ProofDocumentStore {
  final String _filePath;
  Completer<void>? _mutex;

  ProofDocumentStore(this._filePath);

  /// Async mutex — prevents interleaved read-modify-write within one isolate.
  Future<T> _protect<T>(Future<T> Function() fn) async {
    while (_mutex != null) {
      await _mutex!.future;
    }
    _mutex = Completer<void>();
    try {
      return await fn();
    } finally {
      final lock = _mutex!;
      _mutex = null;
      lock.complete();
    }
  }

  /// Load all documents from disk. Returns empty list on error.
  Future<List<ProofDocument>> loadAll() async {
    final file = File(_filePath);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list
          .map((e) => ProofDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.agent, '[ProofDocStore] Failed to parse: $e');
      return [];
    }
  }

  /// Atomic write: write to .tmp then rename (POSIX atomic on same filesystem).
  Future<void> _writeDocs(List<ProofDocument> docs) async {
    final json = jsonEncode(docs.map((d) => d.toJson()).toList());
    final tmpFile = File('$_filePath.tmp');
    await tmpFile.writeAsString(json, flush: true);
    await tmpFile.rename(_filePath);
  }

  /// Save or update a document (upsert by slug).
  Future<void> save(ProofDocument doc) => _protect(() async {
        final docs = await loadAll();
        final idx = docs.indexWhere((d) => d.slug == doc.slug);
        if (idx >= 0) {
          docs[idx] = doc;
        } else {
          docs.add(doc);
        }
        await _writeDocs(docs);
      });

  /// Get a document by slug. Returns null if not found.
  Future<ProofDocument?> getBySlug(String slug) async {
    final docs = await loadAll();
    for (final doc in docs) {
      if (doc.slug == slug) return doc;
    }
    return null;
  }

  /// Get the most recently accessed document.
  Future<ProofDocument?> getMostRecent() async {
    final docs = await loadAll();
    if (docs.isEmpty) return null;
    docs.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return docs.first;
  }

  /// Remove a document by slug.
  Future<void> remove(String slug) => _protect(() async {
        final docs = await loadAll();
        docs.removeWhere((d) => d.slug == slug);
        await _writeDocs(docs);
      });

  /// Update the last-accessed timestamp for a document.
  Future<void> updateLastAccessed(String slug) => _protect(() async {
        final docs = await loadAll();
        final idx = docs.indexWhere((d) => d.slug == slug);
        if (idx >= 0) {
          docs[idx] = docs[idx].copyWith(lastAccessedAt: DateTime.now());
          await _writeDocs(docs);
        }
      });
}
