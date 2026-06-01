import 'package:drift/native.dart';
import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';

/// An in-memory [KnowledgeGraphDB] for tests — no file, no device. Each call
/// returns a fresh, empty database with the schema applied. Remember to
/// `close()` it in tearDown.
KnowledgeGraphDB inMemoryKnowledgeGraphDB() =>
    KnowledgeGraphDB.forExecutor(NativeDatabase.memory());
