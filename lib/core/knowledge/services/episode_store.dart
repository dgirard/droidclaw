import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../shared/constants.dart';
import '../../config/log_entry.dart';
import '../../config/trace_redactor.dart';
import '../../services/app_logger.dart';
import '../../tools/tool.dart';
import '../database/knowledge_graph_db.dart';

/// One fresh episode served from the cache.
class Episode {
  final String tool;
  final String resultRedacted;
  final DateTime createdAt;

  const Episode({
    required this.tool,
    required this.resultRedacted,
    required this.createdAt,
  });
}

/// Episodic memory for tool results (U4): a TTL-bounded, write-redacted cache
/// in the `episodes` table of the knowledge graph database.
///
/// Classification lives in [AppConstants.episodeTtlSeconds]: only the
/// read-only tools listed there are ever cached; everything else (every
/// side-effecting tool) is a structural no-op for both [lookup] and [record].
///
/// **Key** = (tool, sha256 of canonicalized args, context key). Args
/// canonicalization sorts map keys recursively and trims + lowercases string
/// values, so cosmetically different LLM emissions of the same call
/// ("Paris " vs "paris") hit the same episode. The context key is the device
/// location cell for geo-keyed tools and '' otherwise — never NULL, because
/// SQLite treats NULLs as distinct in UNIQUE constraints, which would defeat
/// the upsert dedup.
///
/// **Geo context**: geo-keyed tools ([AppConstants.episodeGeoKeyedTools]) are
/// additionally keyed by a lat/lon cell rounded to
/// [AppConstants.episodeLocationCellDecimals] decimals (~1.1 km), so "what's
/// the weather?" after a train ride never answers for the departure city.
/// The cell is process-local state fed by [setLocationContext] — the
/// AgentLoop updates it whenever a successful `get_location` result passes
/// through ([maybeUpdateLocationContext]). With NO known cell, geo-keyed
/// tools are neither cached nor served (correctness first); each isolate
/// learns its own cell.
///
/// **Hygiene**: stored content passes [TraceRedactor.redactText] at write
/// time; for [AppConstants.episodeSummaryOnlyTools] (contacts, calendar) only
/// the redacted `forUser` summary is stored — the structured `forLLM` bodies
/// are never persisted. Error results are never recorded.
class EpisodeStore {
  EpisodeStore(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final KnowledgeGraphDB db;
  final DateTime Function() _clock;

  String? _locationCell;

  /// Whether [tool] is in the cacheable read-only allowlist.
  static bool isCacheable(String tool) =>
      AppConstants.episodeTtlSeconds.containsKey(tool);

  /// Current location cell, or null when no device location is known yet.
  String? get locationCell => _locationCell;

  /// Set the geo context from a known device position.
  void setLocationContext(double lat, double lon) {
    final d = AppConstants.episodeLocationCellDecimals;
    _locationCell = '${lat.toStringAsFixed(d)},${lon.toStringAsFixed(d)}';
  }

  static final RegExp _latLon = RegExp(
      r'latitude=(-?\d+(?:\.\d+)?),\s*longitude=(-?\d+(?:\.\d+)?)');

  /// Update the geo context from a `get_location` tool result passing
  /// through the agent loop. No-op for other tools or unparseable content.
  void maybeUpdateLocationContext(String toolName, String resultForLLM) {
    if (toolName != 'get_location') return;
    final m = _latLon.firstMatch(resultForLLM);
    if (m == null) return;
    final lat = double.tryParse(m.group(1)!);
    final lon = double.tryParse(m.group(2)!);
    if (lat == null || lon == null) return;
    setLocationContext(lat, lon);
  }

  /// Look up a FRESH episode for (tool, args). Returns null when the tool is
  /// not cacheable, the episode is missing or expired, or the tool is
  /// geo-keyed and no location cell is known.
  Future<Episode?> lookup(String tool, Map<String, dynamic> args) async {
    if (!isCacheable(tool)) return null;
    final contextKey = _contextKeyFor(tool);
    if (contextKey == null) return null; // geo-keyed, no known cell

    final now = _clock().millisecondsSinceEpoch ~/ 1000;
    final row = await db.customSelect(
      'SELECT result_redacted, created_at FROM episodes '
      'WHERE tool = ? AND args_digest = ? AND context_key = ? '
      'AND expires_at > ?',
      variables: [
        Variable.withString(tool),
        Variable.withString(canonicalArgsDigest(args)),
        Variable.withString(contextKey),
        Variable.withInt(now),
      ],
    ).getSingleOrNull();
    if (row == null) return null;

    return Episode(
      tool: tool,
      resultRedacted: row.read<String>('result_redacted'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('created_at') * 1000),
    );
  }

  /// Record a tool result. Structural no-ops: non-cacheable tool, error
  /// result, geo-keyed tool with no known cell. Same-key recording is an
  /// upsert: payload and timestamps are refreshed.
  Future<void> record(
    String tool,
    Map<String, dynamic> args,
    ToolResult result, {
    String? sessionKey,
  }) async {
    if (!isCacheable(tool)) return;
    if (result.isError) return;
    final contextKey = _contextKeyFor(tool);
    if (contextKey == null) return; // geo-keyed, no known cell

    // Summary-only tools persist the redacted forUser summary; everything
    // else persists the redacted forLLM content.
    final raw = AppConstants.episodeSummaryOnlyTools.contains(tool)
        ? result.forUser
        : result.forLLM;
    final redacted = TraceRedactor.redactText(raw);

    final now = _clock().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = now + AppConstants.episodeTtlSeconds[tool]!;
    await db.customStatement(
      'INSERT INTO episodes '
      '(tool, args_digest, context_key, result_redacted, is_error, '
      'session_key, created_at, expires_at) '
      'VALUES (?, ?, ?, ?, 0, ?, ?, ?) '
      'ON CONFLICT(tool, args_digest, context_key) DO UPDATE SET '
      'result_redacted = excluded.result_redacted, '
      'session_key = excluded.session_key, '
      'created_at = excluded.created_at, '
      'expires_at = excluded.expires_at',
      [
        tool,
        canonicalArgsDigest(args),
        contextKey,
        redacted,
        sessionKey,
        now,
        expiresAt,
      ],
    );
  }

  /// Evict expired episodes. Returns the number of rows deleted. Called by
  /// the daily KG purge in the service isolate and safe to call anywhere.
  Future<int> purgeExpired() async {
    final now = _clock().millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        'DELETE FROM episodes WHERE expires_at <= ?', [now]);
    final changes =
        await db.customSelect('SELECT changes() AS cnt').getSingle();
    final evicted = changes.read<int>('cnt');
    if (evicted > 0) {
      AppLogger.instance.debug(
          LogSource.agent, 'Episode purge: $evicted expired evicted');
    }
    return evicted;
  }

  /// Context key for [tool]: the location cell for geo-keyed tools (null =
  /// unknown → caller must skip caching), '' for everything else.
  String? _contextKeyFor(String tool) =>
      AppConstants.episodeGeoKeyedTools.contains(tool) ? _locationCell : '';

  /// Stable digest of tool arguments: maps get sorted keys (recursively),
  /// string values are trimmed and lowercased for matching robustness, then
  /// the canonical JSON is sha256-hashed. Lists keep their order (argument
  /// order is semantic, e.g. waypoints).
  static String canonicalArgsDigest(Map<String, dynamic> args) {
    final canonical = jsonEncode(_canonicalize(args));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .map((e) => MapEntry(e.key.toString(), _canonicalize(e.value)))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return {for (final e in entries) e.key: e.value};
    }
    if (value is List) return value.map(_canonicalize).toList();
    if (value is String) return value.trim().toLowerCase();
    return value;
  }
}
