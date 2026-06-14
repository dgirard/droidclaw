// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_db.dart';

// ignore_for_file: type=lint
class Sessions extends Table with TableInfo<Sessions, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Sessions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionKeyMeta = const VerificationMeta(
    'sessionKey',
  );
  late final GeneratedColumn<String> sessionKey = GeneratedColumn<String>(
    'session_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  late final GeneratedColumn<int> created = GeneratedColumn<int>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedMeta = const VerificationMeta(
    'updated',
  );
  late final GeneratedColumn<int> updated = GeneratedColumn<int>(
    'updated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _conversationMessageCountMeta =
      const VerificationMeta('conversationMessageCount');
  late final GeneratedColumn<int> conversationMessageCount =
      GeneratedColumn<int>(
        'conversation_message_count',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT 0',
        defaultValue: const CustomExpression('0'),
      );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _summaryPreviewMeta = const VerificationMeta(
    'summaryPreview',
  );
  late final GeneratedColumn<String> summaryPreview = GeneratedColumn<String>(
    'summary_preview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionKey,
    payload,
    created,
    updated,
    messageCount,
    conversationMessageCount,
    preview,
    summaryPreview,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_key')) {
      context.handle(
        _sessionKeyMeta,
        sessionKey.isAcceptableOrUnknown(data['session_key']!, _sessionKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('updated')) {
      context.handle(
        _updatedMeta,
        updated.isAcceptableOrUnknown(data['updated']!, _updatedMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMeta);
    }
    if (data.containsKey('message_count')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['message_count']!,
          _messageCountMeta,
        ),
      );
    }
    if (data.containsKey('conversation_message_count')) {
      context.handle(
        _conversationMessageCountMeta,
        conversationMessageCount.isAcceptableOrUnknown(
          data['conversation_message_count']!,
          _conversationMessageCountMeta,
        ),
      );
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    if (data.containsKey('summary_preview')) {
      context.handle(
        _summaryPreviewMeta,
        summaryPreview.isAcceptableOrUnknown(
          data['summary_preview']!,
          _summaryPreviewMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionKey};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      sessionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      )!,
      updated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated'],
      )!,
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_count'],
      )!,
      conversationMessageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_message_count'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      ),
      summaryPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_preview'],
      ),
    );
  }

  @override
  Sessions createAlias(String alias) {
    return Sessions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String sessionKey;

  /// Full Session JSON (Session.toJson). Single source of message history.
  final String payload;

  /// Metadata columns (SessionMetadata) — kept in sync with payload by
  /// SessionManager.save (one UPSERT writes both).
  final int created;
  final int updated;
  final int messageCount;
  final int conversationMessageCount;
  final String? preview;
  final String? summaryPreview;
  const SessionRow({
    required this.sessionKey,
    required this.payload,
    required this.created,
    required this.updated,
    required this.messageCount,
    required this.conversationMessageCount,
    this.preview,
    this.summaryPreview,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_key'] = Variable<String>(sessionKey);
    map['payload'] = Variable<String>(payload);
    map['created'] = Variable<int>(created);
    map['updated'] = Variable<int>(updated);
    map['message_count'] = Variable<int>(messageCount);
    map['conversation_message_count'] = Variable<int>(conversationMessageCount);
    if (!nullToAbsent || preview != null) {
      map['preview'] = Variable<String>(preview);
    }
    if (!nullToAbsent || summaryPreview != null) {
      map['summary_preview'] = Variable<String>(summaryPreview);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      sessionKey: Value(sessionKey),
      payload: Value(payload),
      created: Value(created),
      updated: Value(updated),
      messageCount: Value(messageCount),
      conversationMessageCount: Value(conversationMessageCount),
      preview: preview == null && nullToAbsent
          ? const Value.absent()
          : Value(preview),
      summaryPreview: summaryPreview == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryPreview),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      sessionKey: serializer.fromJson<String>(json['session_key']),
      payload: serializer.fromJson<String>(json['payload']),
      created: serializer.fromJson<int>(json['created']),
      updated: serializer.fromJson<int>(json['updated']),
      messageCount: serializer.fromJson<int>(json['message_count']),
      conversationMessageCount: serializer.fromJson<int>(
        json['conversation_message_count'],
      ),
      preview: serializer.fromJson<String?>(json['preview']),
      summaryPreview: serializer.fromJson<String?>(json['summary_preview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'session_key': serializer.toJson<String>(sessionKey),
      'payload': serializer.toJson<String>(payload),
      'created': serializer.toJson<int>(created),
      'updated': serializer.toJson<int>(updated),
      'message_count': serializer.toJson<int>(messageCount),
      'conversation_message_count': serializer.toJson<int>(
        conversationMessageCount,
      ),
      'preview': serializer.toJson<String?>(preview),
      'summary_preview': serializer.toJson<String?>(summaryPreview),
    };
  }

  SessionRow copyWith({
    String? sessionKey,
    String? payload,
    int? created,
    int? updated,
    int? messageCount,
    int? conversationMessageCount,
    Value<String?> preview = const Value.absent(),
    Value<String?> summaryPreview = const Value.absent(),
  }) => SessionRow(
    sessionKey: sessionKey ?? this.sessionKey,
    payload: payload ?? this.payload,
    created: created ?? this.created,
    updated: updated ?? this.updated,
    messageCount: messageCount ?? this.messageCount,
    conversationMessageCount:
        conversationMessageCount ?? this.conversationMessageCount,
    preview: preview.present ? preview.value : this.preview,
    summaryPreview: summaryPreview.present
        ? summaryPreview.value
        : this.summaryPreview,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      sessionKey: data.sessionKey.present
          ? data.sessionKey.value
          : this.sessionKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      created: data.created.present ? data.created.value : this.created,
      updated: data.updated.present ? data.updated.value : this.updated,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
      conversationMessageCount: data.conversationMessageCount.present
          ? data.conversationMessageCount.value
          : this.conversationMessageCount,
      preview: data.preview.present ? data.preview.value : this.preview,
      summaryPreview: data.summaryPreview.present
          ? data.summaryPreview.value
          : this.summaryPreview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('sessionKey: $sessionKey, ')
          ..write('payload: $payload, ')
          ..write('created: $created, ')
          ..write('updated: $updated, ')
          ..write('messageCount: $messageCount, ')
          ..write('conversationMessageCount: $conversationMessageCount, ')
          ..write('preview: $preview, ')
          ..write('summaryPreview: $summaryPreview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionKey,
    payload,
    created,
    updated,
    messageCount,
    conversationMessageCount,
    preview,
    summaryPreview,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.sessionKey == this.sessionKey &&
          other.payload == this.payload &&
          other.created == this.created &&
          other.updated == this.updated &&
          other.messageCount == this.messageCount &&
          other.conversationMessageCount == this.conversationMessageCount &&
          other.preview == this.preview &&
          other.summaryPreview == this.summaryPreview);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> sessionKey;
  final Value<String> payload;
  final Value<int> created;
  final Value<int> updated;
  final Value<int> messageCount;
  final Value<int> conversationMessageCount;
  final Value<String?> preview;
  final Value<String?> summaryPreview;
  final Value<int> rowid;
  const SessionsCompanion({
    this.sessionKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.conversationMessageCount = const Value.absent(),
    this.preview = const Value.absent(),
    this.summaryPreview = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String sessionKey,
    required String payload,
    required int created,
    required int updated,
    this.messageCount = const Value.absent(),
    this.conversationMessageCount = const Value.absent(),
    this.preview = const Value.absent(),
    this.summaryPreview = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionKey = Value(sessionKey),
       payload = Value(payload),
       created = Value(created),
       updated = Value(updated);
  static Insertable<SessionRow> custom({
    Expression<String>? sessionKey,
    Expression<String>? payload,
    Expression<int>? created,
    Expression<int>? updated,
    Expression<int>? messageCount,
    Expression<int>? conversationMessageCount,
    Expression<String>? preview,
    Expression<String>? summaryPreview,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionKey != null) 'session_key': sessionKey,
      if (payload != null) 'payload': payload,
      if (created != null) 'created': created,
      if (updated != null) 'updated': updated,
      if (messageCount != null) 'message_count': messageCount,
      if (conversationMessageCount != null)
        'conversation_message_count': conversationMessageCount,
      if (preview != null) 'preview': preview,
      if (summaryPreview != null) 'summary_preview': summaryPreview,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? sessionKey,
    Value<String>? payload,
    Value<int>? created,
    Value<int>? updated,
    Value<int>? messageCount,
    Value<int>? conversationMessageCount,
    Value<String?>? preview,
    Value<String?>? summaryPreview,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      sessionKey: sessionKey ?? this.sessionKey,
      payload: payload ?? this.payload,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      messageCount: messageCount ?? this.messageCount,
      conversationMessageCount:
          conversationMessageCount ?? this.conversationMessageCount,
      preview: preview ?? this.preview,
      summaryPreview: summaryPreview ?? this.summaryPreview,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionKey.present) {
      map['session_key'] = Variable<String>(sessionKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(created.value);
    }
    if (updated.present) {
      map['updated'] = Variable<int>(updated.value);
    }
    if (messageCount.present) {
      map['message_count'] = Variable<int>(messageCount.value);
    }
    if (conversationMessageCount.present) {
      map['conversation_message_count'] = Variable<int>(
        conversationMessageCount.value,
      );
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (summaryPreview.present) {
      map['summary_preview'] = Variable<String>(summaryPreview.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('sessionKey: $sessionKey, ')
          ..write('payload: $payload, ')
          ..write('created: $created, ')
          ..write('updated: $updated, ')
          ..write('messageCount: $messageCount, ')
          ..write('conversationMessageCount: $conversationMessageCount, ')
          ..write('preview: $preview, ')
          ..write('summaryPreview: $summaryPreview, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AppState extends Table with TableInfo<AppState, AppStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppState(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stateKeyMeta = const VerificationMeta(
    'stateKey',
  );
  late final GeneratedColumn<String> stateKey = GeneratedColumn<String>(
    'state_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [stateKey, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('state_key')) {
      context.handle(
        _stateKeyMeta,
        stateKey.isAcceptableOrUnknown(data['state_key']!, _stateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_stateKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stateKey};
  @override
  AppStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRow(
      stateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  AppState createAlias(String alias) {
    return AppState(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AppStateRow extends DataClass implements Insertable<AppStateRow> {
  final String stateKey;
  final String value;
  const AppStateRow({required this.stateKey, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['state_key'] = Variable<String>(stateKey);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppStateCompanion toCompanion(bool nullToAbsent) {
    return AppStateCompanion(stateKey: Value(stateKey), value: Value(value));
  }

  factory AppStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateRow(
      stateKey: serializer.fromJson<String>(json['state_key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'state_key': serializer.toJson<String>(stateKey),
      'value': serializer.toJson<String>(value),
    };
  }

  AppStateRow copyWith({String? stateKey, String? value}) => AppStateRow(
    stateKey: stateKey ?? this.stateKey,
    value: value ?? this.value,
  );
  AppStateRow copyWithCompanion(AppStateCompanion data) {
    return AppStateRow(
      stateKey: data.stateKey.present ? data.stateKey.value : this.stateKey,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRow(')
          ..write('stateKey: $stateKey, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(stateKey, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRow &&
          other.stateKey == this.stateKey &&
          other.value == this.value);
}

class AppStateCompanion extends UpdateCompanion<AppStateRow> {
  final Value<String> stateKey;
  final Value<String> value;
  final Value<int> rowid;
  const AppStateCompanion({
    this.stateKey = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateCompanion.insert({
    required String stateKey,
    required String value,
    this.rowid = const Value.absent(),
  }) : stateKey = Value(stateKey),
       value = Value(value);
  static Insertable<AppStateRow> custom({
    Expression<String>? stateKey,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stateKey != null) 'state_key': stateKey,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStateCompanion copyWith({
    Value<String>? stateKey,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppStateCompanion(
      stateKey: stateKey ?? this.stateKey,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stateKey.present) {
      map['state_key'] = Variable<String>(stateKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStateCompanion(')
          ..write('stateKey: $stateKey, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SessionsDb extends GeneratedDatabase {
  _$SessionsDb(QueryExecutor e) : super(e);
  $SessionsDbManager get managers => $SessionsDbManager(this);
  late final Sessions sessions = Sessions(this);
  late final Index idxSessionsUpdated = Index(
    'idx_sessions_updated',
    'CREATE INDEX idx_sessions_updated ON sessions (updated DESC)',
  );
  late final AppState appState = AppState(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    idxSessionsUpdated,
    appState,
  ];
}

typedef $SessionsCreateCompanionBuilder =
    SessionsCompanion Function({
      required String sessionKey,
      required String payload,
      required int created,
      required int updated,
      Value<int> messageCount,
      Value<int> conversationMessageCount,
      Value<String?> preview,
      Value<String?> summaryPreview,
      Value<int> rowid,
    });
typedef $SessionsUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> sessionKey,
      Value<String> payload,
      Value<int> created,
      Value<int> updated,
      Value<int> messageCount,
      Value<int> conversationMessageCount,
      Value<String?> preview,
      Value<String?> summaryPreview,
      Value<int> rowid,
    });

class $SessionsFilterComposer extends Composer<_$SessionsDb, Sessions> {
  $SessionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionKey => $composableBuilder(
    column: $table.sessionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationMessageCount => $composableBuilder(
    column: $table.conversationMessageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryPreview => $composableBuilder(
    column: $table.summaryPreview,
    builder: (column) => ColumnFilters(column),
  );
}

class $SessionsOrderingComposer extends Composer<_$SessionsDb, Sessions> {
  $SessionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionKey => $composableBuilder(
    column: $table.sessionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationMessageCount => $composableBuilder(
    column: $table.conversationMessageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryPreview => $composableBuilder(
    column: $table.summaryPreview,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SessionsAnnotationComposer extends Composer<_$SessionsDb, Sessions> {
  $SessionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionKey => $composableBuilder(
    column: $table.sessionKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<int> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get conversationMessageCount => $composableBuilder(
    column: $table.conversationMessageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<String> get summaryPreview => $composableBuilder(
    column: $table.summaryPreview,
    builder: (column) => column,
  );
}

class $SessionsTableManager
    extends
        RootTableManager<
          _$SessionsDb,
          Sessions,
          SessionRow,
          $SessionsFilterComposer,
          $SessionsOrderingComposer,
          $SessionsAnnotationComposer,
          $SessionsCreateCompanionBuilder,
          $SessionsUpdateCompanionBuilder,
          (SessionRow, BaseReferences<_$SessionsDb, Sessions, SessionRow>),
          SessionRow,
          PrefetchHooks Function()
        > {
  $SessionsTableManager(_$SessionsDb db, Sessions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SessionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SessionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SessionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> created = const Value.absent(),
                Value<int> updated = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int> conversationMessageCount = const Value.absent(),
                Value<String?> preview = const Value.absent(),
                Value<String?> summaryPreview = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                sessionKey: sessionKey,
                payload: payload,
                created: created,
                updated: updated,
                messageCount: messageCount,
                conversationMessageCount: conversationMessageCount,
                preview: preview,
                summaryPreview: summaryPreview,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionKey,
                required String payload,
                required int created,
                required int updated,
                Value<int> messageCount = const Value.absent(),
                Value<int> conversationMessageCount = const Value.absent(),
                Value<String?> preview = const Value.absent(),
                Value<String?> summaryPreview = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                sessionKey: sessionKey,
                payload: payload,
                created: created,
                updated: updated,
                messageCount: messageCount,
                conversationMessageCount: conversationMessageCount,
                preview: preview,
                summaryPreview: summaryPreview,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SessionsProcessedTableManager =
    ProcessedTableManager<
      _$SessionsDb,
      Sessions,
      SessionRow,
      $SessionsFilterComposer,
      $SessionsOrderingComposer,
      $SessionsAnnotationComposer,
      $SessionsCreateCompanionBuilder,
      $SessionsUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$SessionsDb, Sessions, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $AppStateCreateCompanionBuilder =
    AppStateCompanion Function({
      required String stateKey,
      required String value,
      Value<int> rowid,
    });
typedef $AppStateUpdateCompanionBuilder =
    AppStateCompanion Function({
      Value<String> stateKey,
      Value<String> value,
      Value<int> rowid,
    });

class $AppStateFilterComposer extends Composer<_$SessionsDb, AppState> {
  $AppStateFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stateKey => $composableBuilder(
    column: $table.stateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $AppStateOrderingComposer extends Composer<_$SessionsDb, AppState> {
  $AppStateOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stateKey => $composableBuilder(
    column: $table.stateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AppStateAnnotationComposer extends Composer<_$SessionsDb, AppState> {
  $AppStateAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stateKey =>
      $composableBuilder(column: $table.stateKey, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $AppStateTableManager
    extends
        RootTableManager<
          _$SessionsDb,
          AppState,
          AppStateRow,
          $AppStateFilterComposer,
          $AppStateOrderingComposer,
          $AppStateAnnotationComposer,
          $AppStateCreateCompanionBuilder,
          $AppStateUpdateCompanionBuilder,
          (AppStateRow, BaseReferences<_$SessionsDb, AppState, AppStateRow>),
          AppStateRow,
          PrefetchHooks Function()
        > {
  $AppStateTableManager(_$SessionsDb db, AppState table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AppStateFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AppStateOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AppStateAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stateKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppStateCompanion(
                stateKey: stateKey,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String stateKey,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppStateCompanion.insert(
                stateKey: stateKey,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AppStateProcessedTableManager =
    ProcessedTableManager<
      _$SessionsDb,
      AppState,
      AppStateRow,
      $AppStateFilterComposer,
      $AppStateOrderingComposer,
      $AppStateAnnotationComposer,
      $AppStateCreateCompanionBuilder,
      $AppStateUpdateCompanionBuilder,
      (AppStateRow, BaseReferences<_$SessionsDb, AppState, AppStateRow>),
      AppStateRow,
      PrefetchHooks Function()
    >;

class $SessionsDbManager {
  final _$SessionsDb _db;
  $SessionsDbManager(this._db);
  $SessionsTableManager get sessions =>
      $SessionsTableManager(_db, _db.sessions);
  $AppStateTableManager get appState =>
      $AppStateTableManager(_db, _db.appState);
}
