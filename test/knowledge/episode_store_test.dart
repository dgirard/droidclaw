// U4: episodic memory — TTL-bounded, write-redacted tool-result cache in
// the `episodes` table of the KG database.
//
// - Key = (tool, sha256(canonical args), context key). Canonicalization
//   sorts keys and trims+lowercases strings.
// - Geo-keyed tools are additionally keyed by the location cell; with no
//   known cell they are never cached (correctness first).
// - Stored content passes TraceRedactor at write time; contacts/calendar
//   store only the redacted forUser summary.
// - TTL is the eviction boundary (purgeExpired); the UNIQUE key powers
//   upsert dedup.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/config/config_storage.dart';
import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/episode_store.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';
import 'package:droidclaw/core/services/data_wiper.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/data/local/storage_service.dart';

import '../support/in_memory_kg.dart';

Future<int> _episodeCount(KnowledgeGraphDB db) async {
  final row =
      await db.customSelect('SELECT COUNT(*) AS cnt FROM episodes').getSingle();
  return row.read<int>('cnt');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeGraphDB db;

  setUp(() => db = inMemoryKnowledgeGraphDB());
  tearDown(() => db.close());

  group('args canonicalization', () {
    test('key order, whitespace, and case do not change the digest', () {
      final a = EpisodeStore.canonicalArgsDigest(
          {'city': 'Paris ', 'units': 'metric'});
      final b = EpisodeStore.canonicalArgsDigest(
          {'units': 'metric', 'city': ' paris'});
      expect(a, b);
    });

    test('different values produce different digests', () {
      final a = EpisodeStore.canonicalArgsDigest({'city': 'paris'});
      final b = EpisodeStore.canonicalArgsDigest({'city': 'lyon'});
      expect(a, isNot(b));
    });

    test('nested maps and lists are canonicalized (list order preserved)',
        () {
      final a = EpisodeStore.canonicalArgsDigest({
        'route': {'to': 'B', 'from': 'A'},
        'stops': ['X', 'Y'],
      });
      final b = EpisodeStore.canonicalArgsDigest({
        'stops': ['x', 'y'],
        'route': {'from': 'a', 'to': 'b'},
      });
      final c = EpisodeStore.canonicalArgsDigest({
        'route': {'from': 'a', 'to': 'b'},
        'stops': ['y', 'x'], // waypoint order is semantic
      });
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('record / lookup', () {
    test('a recorded result is served fresh, then expires after its TTL',
        () async {
      var now = DateTime.utc(2026, 6, 12, 10, 0, 0);
      final store = EpisodeStore(db, clock: () => now);

      await store.record('web_search', {'query': 'dart'},
          ToolResult.simple('search results body'));

      now = now.add(const Duration(minutes: 10));
      final hit = await store.lookup('web_search', {'query': 'Dart '});
      expect(hit, isNotNull);
      expect(hit!.resultRedacted, 'search results body');
      expect(hit.createdAt.toUtc(), DateTime.utc(2026, 6, 12, 10, 0, 0));

      // web_search TTL is 12h — one minute past it, the episode is stale.
      now = DateTime.utc(2026, 6, 12, 22, 1, 0);
      expect(await store.lookup('web_search', {'query': 'dart'}), isNull);
    });

    test('error results are never recorded', () async {
      final store = EpisodeStore(db);

      await store.record(
          'web_search', {'query': 'x'}, ToolResult.error('boom'));

      expect(await _episodeCount(db), 0);
    });

    test('side-effecting tools (set_alarm) are never recorded nor served',
        () async {
      final store = EpisodeStore(db);

      await store.record(
          'set_alarm', {'hour': 7}, ToolResult.simple('alarm set'));

      expect(EpisodeStore.isCacheable('set_alarm'), isFalse);
      expect(await _episodeCount(db), 0);
      expect(await store.lookup('set_alarm', {'hour': 7}), isNull);
    });

    test('same key re-record is an upsert: one row, refreshed payload',
        () async {
      var now = DateTime.utc(2026, 6, 12, 10, 0, 0);
      final store = EpisodeStore(db, clock: () => now);

      await store.record(
          'web_search', {'query': 'dart'}, ToolResult.simple('old'));
      now = now.add(const Duration(hours: 1));
      await store.record(
          'web_search', {'query': 'dart'}, ToolResult.simple('new'));

      expect(await _episodeCount(db), 1);
      final hit = await store.lookup('web_search', {'query': 'dart'});
      expect(hit!.resultRedacted, 'new');
      expect(hit.createdAt.toUtc(), DateTime.utc(2026, 6, 12, 11, 0, 0));
    });
  });

  group('geo context', () {
    test('geo-keyed tool with NO known cell is never cached', () async {
      final store = EpisodeStore(db);

      await store.record('weather', {'city': 'paris'},
          ToolResult.simple('sunny'));

      expect(await _episodeCount(db), 0);
      expect(await store.lookup('weather', {'city': 'paris'}), isNull);
    });

    test('geo-keyed episode hits in the same cell, misses in another',
        () async {
      final store = EpisodeStore(db);
      store.setLocationContext(48.8566, 2.3522); // Paris

      await store.record('weather', {}, ToolResult.simple('sunny in paris'));
      expect((await store.lookup('weather', {}))!.resultRedacted,
          'sunny in paris');

      // Same cell after rounding (~1.1 km): still a hit.
      store.setLocationContext(48.8590, 2.3510);
      expect(await store.lookup('weather', {}), isNotNull);

      // After a train ride: different cell → MISS, never the departure city.
      store.setLocationContext(45.7640, 4.8357); // Lyon
      expect(await store.lookup('weather', {}), isNull);
    });

    test('maybeUpdateLocationContext parses a get_location result', () {
      final store = EpisodeStore(db);

      store.maybeUpdateLocationContext(
          'get_location',
          'Current device location: latitude=48.856600, '
          'longitude=2.352200, accuracy=10m');
      expect(store.locationCell, '48.86,2.35');

      // Other tools and unparseable content never touch the cell.
      store.maybeUpdateLocationContext('weather', 'latitude=1.0, longitude=2.0');
      store.maybeUpdateLocationContext('get_location', 'no coordinates here');
      expect(store.locationCell, '48.86,2.35');
    });
  });

  group('write-time redaction', () {
    test('contacts episodes store the redacted forUser summary — no phone, '
        'no email, no forLLM body', () async {
      final store = EpisodeStore(db);

      await store.record(
        'contacts',
        {'action': 'list'},
        ToolResult.dual(
          forLLM: 'Full listing: Alice Dupont, +33 6 12 34 56 78, '
              'alice@example.com; Bob Martin, +33 7 98 76 54 32, '
              'bob@example.com',
          forUser: 'Found 2 contacts matching, e.g. reachable at '
              '+33 6 12 34 56 78 or alice@example.com',
        ),
      );

      final row = await db
          .customSelect('SELECT result_redacted FROM episodes')
          .getSingle();
      final stored = row.read<String>('result_redacted');
      expect(stored, isNot(contains('+33 6 12 34 56 78')));
      expect(stored, isNot(contains('alice@example.com')));
      expect(stored, isNot(contains('Full listing')),
          reason: 'forLLM bodies must never be persisted for contacts');
      expect(stored, contains('Found 2 contacts'));
    });

    test('free-text results are pattern-redacted (emails, keys)', () async {
      final store = EpisodeStore(db);

      await store.record(
          'web_scrape',
          {'url': 'https://example.com'},
          ToolResult.simple(
              'Contact us at sales@example.com — key sk-abcdef12345678'));

      final hit =
          await store.lookup('web_scrape', {'url': 'https://example.com'});
      expect(hit!.resultRedacted, isNot(contains('sales@example.com')));
      expect(hit.resultRedacted, isNot(contains('sk-abcdef12345678')));
    });
  });

  group('eviction and wipe', () {
    test('purgeExpired evicts only expired episodes', () async {
      var now = DateTime.utc(2026, 6, 12, 10, 0, 0);
      final store = EpisodeStore(db, clock: () => now);

      await store.record(
          'calendar', {}, ToolResult.simple('3 events today')); // TTL 15min
      await store.record('geocode', {'address': 'paris'},
          ToolResult.simple('coords')); // TTL 30d

      now = now.add(const Duration(minutes: 16));
      final evicted = await store.purgeExpired();

      expect(evicted, 1);
      expect(await _episodeCount(db), 1);
      expect(await store.lookup('geocode', {'address': 'paris'}), isNotNull);
    });

    test('deleteAllData clears episodes too', () async {
      final store = EpisodeStore(db);
      await store.record('web_search', {'q': 'x'}, ToolResult.simple('r'));
      expect(await _episodeCount(db), 1);

      await db.deleteAllData();

      expect(await _episodeCount(db), 0);
    });

    test('DataWiper clears episodes (explicit step, table empty after '
        'wipeAll)', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final storage = StorageService(prefs: sp, overrideWorkspacePath: '/ws');

      final dir = await Directory.systemTemp.createTemp('episodes_wipe_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/knowledge_graph.db');
      final fileDb = KnowledgeGraphDB.forExecutor(NativeDatabase(file));

      final store = EpisodeStore(fileDb);
      await store.record('web_search', {'q': 'x'}, ToolResult.simple('r'));

      final wiper = DataWiper(
        storage: storage,
        configStorage: ConfigStorage(storage),
        knowledge: KnowledgeService(db: fileDb),
        // No knowledgeDbPath: the file survives, so the row-level episodes
        // step is observable through a fresh connection below.
      );
      final failures = await wiper.wipeAll();
      expect(failures, isNot(contains('episodes')));

      final reopened = KnowledgeGraphDB.forExecutor(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(await _episodeCount(reopened), 0);
    });
  });

  group('dual-isolate visibility (two WAL connections, same file)', () {
    test('an episode written through one connection is readable through '
        'another (cron-side write visible to main)', () async {
      final dir = await Directory.systemTemp.createTemp('episodes_dual_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/knowledge_graph.db');

      final dbCron = KnowledgeGraphDB.forExecutor(NativeDatabase(file));
      final dbMain = KnowledgeGraphDB.forExecutor(NativeDatabase(file));
      addTearDown(dbCron.close);
      addTearDown(dbMain.close);

      final cronStore = EpisodeStore(dbCron);
      final mainStore = EpisodeStore(dbMain);

      await cronStore.record('web_search', {'query': 'meteo demain'},
          ToolResult.simple('cron result'));

      final hit = await mainStore.lookup(
          'web_search', {'query': 'Meteo Demain'});
      expect(hit, isNotNull);
      expect(hit!.resultRedacted, 'cron result');
    });
  });
}
