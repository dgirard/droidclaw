// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_graph_db.dart';

// ignore_for_file: type=lint
class SummaryNodes extends Table with TableInfo<SummaryNodes, SummaryNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SummaryNodes(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES summary_nodes(id)',
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _summaryTextMeta = const VerificationMeta(
    'summaryText',
  );
  late final GeneratedColumn<String> summaryText = GeneratedColumn<String>(
    'summary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _embeddingModelMeta = const VerificationMeta(
    'embeddingModel',
  );
  late final GeneratedColumn<String> embeddingModel = GeneratedColumn<String>(
    'embedding_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _embeddingDimMeta = const VerificationMeta(
    'embeddingDim',
  );
  late final GeneratedColumn<int> embeddingDim = GeneratedColumn<int>(
    'embedding_dim',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _memberIdsMeta = const VerificationMeta(
    'memberIds',
  );
  late final GeneratedColumn<String> memberIds = GeneratedColumn<String>(
    'member_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _clusterLabelMeta = const VerificationMeta(
    'clusterLabel',
  );
  late final GeneratedColumn<int> clusterLabel = GeneratedColumn<int>(
    'cluster_label',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  late final GeneratedColumn<int> lastUpdated = GeneratedColumn<int>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    level,
    summaryText,
    embedding,
    embeddingModel,
    embeddingDim,
    memberIds,
    clusterLabel,
    createdAt,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'summary_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SummaryNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('summary_text')) {
      context.handle(
        _summaryTextMeta,
        summaryText.isAcceptableOrUnknown(
          data['summary_text']!,
          _summaryTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryTextMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('embedding_model')) {
      context.handle(
        _embeddingModelMeta,
        embeddingModel.isAcceptableOrUnknown(
          data['embedding_model']!,
          _embeddingModelMeta,
        ),
      );
    }
    if (data.containsKey('embedding_dim')) {
      context.handle(
        _embeddingDimMeta,
        embeddingDim.isAcceptableOrUnknown(
          data['embedding_dim']!,
          _embeddingDimMeta,
        ),
      );
    }
    if (data.containsKey('member_ids')) {
      context.handle(
        _memberIdsMeta,
        memberIds.isAcceptableOrUnknown(data['member_ids']!, _memberIdsMeta),
      );
    }
    if (data.containsKey('cluster_label')) {
      context.handle(
        _clusterLabelMeta,
        clusterLabel.isAcceptableOrUnknown(
          data['cluster_label']!,
          _clusterLabelMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SummaryNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SummaryNode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      summaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_text'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      embeddingModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_model'],
      ),
      embeddingDim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}embedding_dim'],
      ),
      memberIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_ids'],
      )!,
      clusterLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cluster_label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  SummaryNodes createAlias(String alias) {
    return SummaryNodes(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SummaryNode extends DataClass implements Insertable<SummaryNode> {
  final int id;
  final int? parentId;
  final int level;
  final String summaryText;
  final Uint8List? embedding;

  /// Embedding provenance (v4) — see entities.embedding_model.
  final String? embeddingModel;
  final int? embeddingDim;
  final String memberIds;
  final int? clusterLabel;
  final int createdAt;
  final int lastUpdated;
  const SummaryNode({
    required this.id,
    this.parentId,
    required this.level,
    required this.summaryText,
    this.embedding,
    this.embeddingModel,
    this.embeddingDim,
    required this.memberIds,
    this.clusterLabel,
    required this.createdAt,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['level'] = Variable<int>(level);
    map['summary_text'] = Variable<String>(summaryText);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    if (!nullToAbsent || embeddingModel != null) {
      map['embedding_model'] = Variable<String>(embeddingModel);
    }
    if (!nullToAbsent || embeddingDim != null) {
      map['embedding_dim'] = Variable<int>(embeddingDim);
    }
    map['member_ids'] = Variable<String>(memberIds);
    if (!nullToAbsent || clusterLabel != null) {
      map['cluster_label'] = Variable<int>(clusterLabel);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['last_updated'] = Variable<int>(lastUpdated);
    return map;
  }

  SummaryNodesCompanion toCompanion(bool nullToAbsent) {
    return SummaryNodesCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      level: Value(level),
      summaryText: Value(summaryText),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      embeddingModel: embeddingModel == null && nullToAbsent
          ? const Value.absent()
          : Value(embeddingModel),
      embeddingDim: embeddingDim == null && nullToAbsent
          ? const Value.absent()
          : Value(embeddingDim),
      memberIds: Value(memberIds),
      clusterLabel: clusterLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(clusterLabel),
      createdAt: Value(createdAt),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory SummaryNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SummaryNode(
      id: serializer.fromJson<int>(json['id']),
      parentId: serializer.fromJson<int?>(json['parent_id']),
      level: serializer.fromJson<int>(json['level']),
      summaryText: serializer.fromJson<String>(json['summary_text']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      embeddingModel: serializer.fromJson<String?>(json['embedding_model']),
      embeddingDim: serializer.fromJson<int?>(json['embedding_dim']),
      memberIds: serializer.fromJson<String>(json['member_ids']),
      clusterLabel: serializer.fromJson<int?>(json['cluster_label']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      lastUpdated: serializer.fromJson<int>(json['last_updated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'parent_id': serializer.toJson<int?>(parentId),
      'level': serializer.toJson<int>(level),
      'summary_text': serializer.toJson<String>(summaryText),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'embedding_model': serializer.toJson<String?>(embeddingModel),
      'embedding_dim': serializer.toJson<int?>(embeddingDim),
      'member_ids': serializer.toJson<String>(memberIds),
      'cluster_label': serializer.toJson<int?>(clusterLabel),
      'created_at': serializer.toJson<int>(createdAt),
      'last_updated': serializer.toJson<int>(lastUpdated),
    };
  }

  SummaryNode copyWith({
    int? id,
    Value<int?> parentId = const Value.absent(),
    int? level,
    String? summaryText,
    Value<Uint8List?> embedding = const Value.absent(),
    Value<String?> embeddingModel = const Value.absent(),
    Value<int?> embeddingDim = const Value.absent(),
    String? memberIds,
    Value<int?> clusterLabel = const Value.absent(),
    int? createdAt,
    int? lastUpdated,
  }) => SummaryNode(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    level: level ?? this.level,
    summaryText: summaryText ?? this.summaryText,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingModel: embeddingModel.present
        ? embeddingModel.value
        : this.embeddingModel,
    embeddingDim: embeddingDim.present ? embeddingDim.value : this.embeddingDim,
    memberIds: memberIds ?? this.memberIds,
    clusterLabel: clusterLabel.present ? clusterLabel.value : this.clusterLabel,
    createdAt: createdAt ?? this.createdAt,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  SummaryNode copyWithCompanion(SummaryNodesCompanion data) {
    return SummaryNode(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      level: data.level.present ? data.level.value : this.level,
      summaryText: data.summaryText.present
          ? data.summaryText.value
          : this.summaryText,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingModel: data.embeddingModel.present
          ? data.embeddingModel.value
          : this.embeddingModel,
      embeddingDim: data.embeddingDim.present
          ? data.embeddingDim.value
          : this.embeddingDim,
      memberIds: data.memberIds.present ? data.memberIds.value : this.memberIds,
      clusterLabel: data.clusterLabel.present
          ? data.clusterLabel.value
          : this.clusterLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SummaryNode(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('summaryText: $summaryText, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('embeddingDim: $embeddingDim, ')
          ..write('memberIds: $memberIds, ')
          ..write('clusterLabel: $clusterLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    parentId,
    level,
    summaryText,
    $driftBlobEquality.hash(embedding),
    embeddingModel,
    embeddingDim,
    memberIds,
    clusterLabel,
    createdAt,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SummaryNode &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.level == this.level &&
          other.summaryText == this.summaryText &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.embeddingModel == this.embeddingModel &&
          other.embeddingDim == this.embeddingDim &&
          other.memberIds == this.memberIds &&
          other.clusterLabel == this.clusterLabel &&
          other.createdAt == this.createdAt &&
          other.lastUpdated == this.lastUpdated);
}

class SummaryNodesCompanion extends UpdateCompanion<SummaryNode> {
  final Value<int> id;
  final Value<int?> parentId;
  final Value<int> level;
  final Value<String> summaryText;
  final Value<Uint8List?> embedding;
  final Value<String?> embeddingModel;
  final Value<int?> embeddingDim;
  final Value<String> memberIds;
  final Value<int?> clusterLabel;
  final Value<int> createdAt;
  final Value<int> lastUpdated;
  const SummaryNodesCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.embeddingDim = const Value.absent(),
    this.memberIds = const Value.absent(),
    this.clusterLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  SummaryNodesCompanion.insert({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    required String summaryText,
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.embeddingDim = const Value.absent(),
    this.memberIds = const Value.absent(),
    this.clusterLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  }) : summaryText = Value(summaryText);
  static Insertable<SummaryNode> custom({
    Expression<int>? id,
    Expression<int>? parentId,
    Expression<int>? level,
    Expression<String>? summaryText,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingModel,
    Expression<int>? embeddingDim,
    Expression<String>? memberIds,
    Expression<int>? clusterLabel,
    Expression<int>? createdAt,
    Expression<int>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (level != null) 'level': level,
      if (summaryText != null) 'summary_text': summaryText,
      if (embedding != null) 'embedding': embedding,
      if (embeddingModel != null) 'embedding_model': embeddingModel,
      if (embeddingDim != null) 'embedding_dim': embeddingDim,
      if (memberIds != null) 'member_ids': memberIds,
      if (clusterLabel != null) 'cluster_label': clusterLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  SummaryNodesCompanion copyWith({
    Value<int>? id,
    Value<int?>? parentId,
    Value<int>? level,
    Value<String>? summaryText,
    Value<Uint8List?>? embedding,
    Value<String?>? embeddingModel,
    Value<int?>? embeddingDim,
    Value<String>? memberIds,
    Value<int?>? clusterLabel,
    Value<int>? createdAt,
    Value<int>? lastUpdated,
  }) {
    return SummaryNodesCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      summaryText: summaryText ?? this.summaryText,
      embedding: embedding ?? this.embedding,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      embeddingDim: embeddingDim ?? this.embeddingDim,
      memberIds: memberIds ?? this.memberIds,
      clusterLabel: clusterLabel ?? this.clusterLabel,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (summaryText.present) {
      map['summary_text'] = Variable<String>(summaryText.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (embeddingModel.present) {
      map['embedding_model'] = Variable<String>(embeddingModel.value);
    }
    if (embeddingDim.present) {
      map['embedding_dim'] = Variable<int>(embeddingDim.value);
    }
    if (memberIds.present) {
      map['member_ids'] = Variable<String>(memberIds.value);
    }
    if (clusterLabel.present) {
      map['cluster_label'] = Variable<int>(clusterLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<int>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SummaryNodesCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('summaryText: $summaryText, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('embeddingDim: $embeddingDim, ')
          ..write('memberIds: $memberIds, ')
          ..write('clusterLabel: $clusterLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class Entities extends Table with TableInfo<Entities, Entity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Entities(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'CONCEPT\'',
    defaultValue: const CustomExpression('\'CONCEPT\''),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _propertiesMeta = const VerificationMeta(
    'properties',
  );
  late final GeneratedColumn<String> properties = GeneratedColumn<String>(
    'properties',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _embeddingModelMeta = const VerificationMeta(
    'embeddingModel',
  );
  late final GeneratedColumn<String> embeddingModel = GeneratedColumn<String>(
    'embedding_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _embeddingDimMeta = const VerificationMeta(
    'embeddingDim',
  );
  late final GeneratedColumn<int> embeddingDim = GeneratedColumn<int>(
    'embedding_dim',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _validAtMeta = const VerificationMeta(
    'validAt',
  );
  late final GeneratedColumn<int> validAt = GeneratedColumn<int>(
    'valid_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _invalidAtMeta = const VerificationMeta(
    'invalidAt',
  );
  late final GeneratedColumn<int> invalidAt = GeneratedColumn<int>(
    'invalid_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _ingestedAtMeta = const VerificationMeta(
    'ingestedAt',
  );
  late final GeneratedColumn<int> ingestedAt = GeneratedColumn<int>(
    'ingested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _expiredAtMeta = const VerificationMeta(
    'expiredAt',
  );
  late final GeneratedColumn<int> expiredAt = GeneratedColumn<int>(
    'expired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastAccessedMeta = const VerificationMeta(
    'lastAccessed',
  );
  late final GeneratedColumn<int> lastAccessed = GeneratedColumn<int>(
    'last_accessed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _accessCountMeta = const VerificationMeta(
    'accessCount',
  );
  late final GeneratedColumn<int> accessCount = GeneratedColumn<int>(
    'access_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  late final GeneratedColumn<String> temperature = GeneratedColumn<String>(
    'temperature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'warm\' CHECK (temperature IN (\'hot\', \'warm\', \'cool\', \'cold\'))',
    defaultValue: const CustomExpression('\'warm\''),
  );
  static const VerificationMeta _baseScoreMeta = const VerificationMeta(
    'baseScore',
  );
  late final GeneratedColumn<double> baseScore = GeneratedColumn<double>(
    'base_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0.5',
    defaultValue: const CustomExpression('0.5'),
  );
  static const VerificationMeta _parentSummaryIdMeta = const VerificationMeta(
    'parentSummaryId',
  );
  late final GeneratedColumn<int> parentSummaryId = GeneratedColumn<int>(
    'parent_summary_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES summary_nodes(id)',
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  late final GeneratedColumn<int> isActive = GeneratedColumn<int>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    entityType,
    summary,
    properties,
    embedding,
    embeddingModel,
    embeddingDim,
    createdAt,
    validAt,
    invalidAt,
    ingestedAt,
    expiredAt,
    lastAccessed,
    accessCount,
    temperature,
    baseScore,
    parentSummaryId,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('properties')) {
      context.handle(
        _propertiesMeta,
        properties.isAcceptableOrUnknown(data['properties']!, _propertiesMeta),
      );
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('embedding_model')) {
      context.handle(
        _embeddingModelMeta,
        embeddingModel.isAcceptableOrUnknown(
          data['embedding_model']!,
          _embeddingModelMeta,
        ),
      );
    }
    if (data.containsKey('embedding_dim')) {
      context.handle(
        _embeddingDimMeta,
        embeddingDim.isAcceptableOrUnknown(
          data['embedding_dim']!,
          _embeddingDimMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('valid_at')) {
      context.handle(
        _validAtMeta,
        validAt.isAcceptableOrUnknown(data['valid_at']!, _validAtMeta),
      );
    }
    if (data.containsKey('invalid_at')) {
      context.handle(
        _invalidAtMeta,
        invalidAt.isAcceptableOrUnknown(data['invalid_at']!, _invalidAtMeta),
      );
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
        _ingestedAtMeta,
        ingestedAt.isAcceptableOrUnknown(data['ingested_at']!, _ingestedAtMeta),
      );
    }
    if (data.containsKey('expired_at')) {
      context.handle(
        _expiredAtMeta,
        expiredAt.isAcceptableOrUnknown(data['expired_at']!, _expiredAtMeta),
      );
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
        _lastAccessedMeta,
        lastAccessed.isAcceptableOrUnknown(
          data['last_accessed']!,
          _lastAccessedMeta,
        ),
      );
    }
    if (data.containsKey('access_count')) {
      context.handle(
        _accessCountMeta,
        accessCount.isAcceptableOrUnknown(
          data['access_count']!,
          _accessCountMeta,
        ),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('base_score')) {
      context.handle(
        _baseScoreMeta,
        baseScore.isAcceptableOrUnknown(data['base_score']!, _baseScoreMeta),
      );
    }
    if (data.containsKey('parent_summary_id')) {
      context.handle(
        _parentSummaryIdMeta,
        parentSummaryId.isAcceptableOrUnknown(
          data['parent_summary_id']!,
          _parentSummaryIdMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      properties: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}properties'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      embeddingModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_model'],
      ),
      embeddingDim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}embedding_dim'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      validAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valid_at'],
      ),
      invalidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invalid_at'],
      ),
      ingestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingested_at'],
      )!,
      expiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expired_at'],
      ),
      lastAccessed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed'],
      )!,
      accessCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}access_count'],
      )!,
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temperature'],
      )!,
      baseScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_score'],
      )!,
      parentSummaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_summary_id'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  Entities createAlias(String alias) {
    return Entities(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Entity extends DataClass implements Insertable<Entity> {
  final int id;
  final String name;
  final String entityType;
  final String? summary;
  final String properties;
  final Uint8List? embedding;

  /// Embedding provenance (v4): the space a vector belongs to. NULL iff
  /// embedding is NULL. Vectors from different (model, dim) spaces must
  /// never be compared (see KnowledgeService.resolveQuerySpace).
  final String? embeddingModel;
  final int? embeddingDim;

  /// Bi-temporal
  final int createdAt;
  final int? validAt;
  final int? invalidAt;
  final int ingestedAt;
  final int? expiredAt;

  /// Activation & decay
  final int lastAccessed;
  final int accessCount;
  final String temperature;
  final double baseScore;

  /// RAPTOR hierarchy
  final int? parentSummaryId;
  final int isActive;
  const Entity({
    required this.id,
    required this.name,
    required this.entityType,
    this.summary,
    required this.properties,
    this.embedding,
    this.embeddingModel,
    this.embeddingDim,
    required this.createdAt,
    this.validAt,
    this.invalidAt,
    required this.ingestedAt,
    this.expiredAt,
    required this.lastAccessed,
    required this.accessCount,
    required this.temperature,
    required this.baseScore,
    this.parentSummaryId,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['properties'] = Variable<String>(properties);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    if (!nullToAbsent || embeddingModel != null) {
      map['embedding_model'] = Variable<String>(embeddingModel);
    }
    if (!nullToAbsent || embeddingDim != null) {
      map['embedding_dim'] = Variable<int>(embeddingDim);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || validAt != null) {
      map['valid_at'] = Variable<int>(validAt);
    }
    if (!nullToAbsent || invalidAt != null) {
      map['invalid_at'] = Variable<int>(invalidAt);
    }
    map['ingested_at'] = Variable<int>(ingestedAt);
    if (!nullToAbsent || expiredAt != null) {
      map['expired_at'] = Variable<int>(expiredAt);
    }
    map['last_accessed'] = Variable<int>(lastAccessed);
    map['access_count'] = Variable<int>(accessCount);
    map['temperature'] = Variable<String>(temperature);
    map['base_score'] = Variable<double>(baseScore);
    if (!nullToAbsent || parentSummaryId != null) {
      map['parent_summary_id'] = Variable<int>(parentSummaryId);
    }
    map['is_active'] = Variable<int>(isActive);
    return map;
  }

  EntitiesCompanion toCompanion(bool nullToAbsent) {
    return EntitiesCompanion(
      id: Value(id),
      name: Value(name),
      entityType: Value(entityType),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      properties: Value(properties),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      embeddingModel: embeddingModel == null && nullToAbsent
          ? const Value.absent()
          : Value(embeddingModel),
      embeddingDim: embeddingDim == null && nullToAbsent
          ? const Value.absent()
          : Value(embeddingDim),
      createdAt: Value(createdAt),
      validAt: validAt == null && nullToAbsent
          ? const Value.absent()
          : Value(validAt),
      invalidAt: invalidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(invalidAt),
      ingestedAt: Value(ingestedAt),
      expiredAt: expiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiredAt),
      lastAccessed: Value(lastAccessed),
      accessCount: Value(accessCount),
      temperature: Value(temperature),
      baseScore: Value(baseScore),
      parentSummaryId: parentSummaryId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSummaryId),
      isActive: Value(isActive),
    );
  }

  factory Entity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entity(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      entityType: serializer.fromJson<String>(json['entity_type']),
      summary: serializer.fromJson<String?>(json['summary']),
      properties: serializer.fromJson<String>(json['properties']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      embeddingModel: serializer.fromJson<String?>(json['embedding_model']),
      embeddingDim: serializer.fromJson<int?>(json['embedding_dim']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      validAt: serializer.fromJson<int?>(json['valid_at']),
      invalidAt: serializer.fromJson<int?>(json['invalid_at']),
      ingestedAt: serializer.fromJson<int>(json['ingested_at']),
      expiredAt: serializer.fromJson<int?>(json['expired_at']),
      lastAccessed: serializer.fromJson<int>(json['last_accessed']),
      accessCount: serializer.fromJson<int>(json['access_count']),
      temperature: serializer.fromJson<String>(json['temperature']),
      baseScore: serializer.fromJson<double>(json['base_score']),
      parentSummaryId: serializer.fromJson<int?>(json['parent_summary_id']),
      isActive: serializer.fromJson<int>(json['is_active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'entity_type': serializer.toJson<String>(entityType),
      'summary': serializer.toJson<String?>(summary),
      'properties': serializer.toJson<String>(properties),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'embedding_model': serializer.toJson<String?>(embeddingModel),
      'embedding_dim': serializer.toJson<int?>(embeddingDim),
      'created_at': serializer.toJson<int>(createdAt),
      'valid_at': serializer.toJson<int?>(validAt),
      'invalid_at': serializer.toJson<int?>(invalidAt),
      'ingested_at': serializer.toJson<int>(ingestedAt),
      'expired_at': serializer.toJson<int?>(expiredAt),
      'last_accessed': serializer.toJson<int>(lastAccessed),
      'access_count': serializer.toJson<int>(accessCount),
      'temperature': serializer.toJson<String>(temperature),
      'base_score': serializer.toJson<double>(baseScore),
      'parent_summary_id': serializer.toJson<int?>(parentSummaryId),
      'is_active': serializer.toJson<int>(isActive),
    };
  }

  Entity copyWith({
    int? id,
    String? name,
    String? entityType,
    Value<String?> summary = const Value.absent(),
    String? properties,
    Value<Uint8List?> embedding = const Value.absent(),
    Value<String?> embeddingModel = const Value.absent(),
    Value<int?> embeddingDim = const Value.absent(),
    int? createdAt,
    Value<int?> validAt = const Value.absent(),
    Value<int?> invalidAt = const Value.absent(),
    int? ingestedAt,
    Value<int?> expiredAt = const Value.absent(),
    int? lastAccessed,
    int? accessCount,
    String? temperature,
    double? baseScore,
    Value<int?> parentSummaryId = const Value.absent(),
    int? isActive,
  }) => Entity(
    id: id ?? this.id,
    name: name ?? this.name,
    entityType: entityType ?? this.entityType,
    summary: summary.present ? summary.value : this.summary,
    properties: properties ?? this.properties,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingModel: embeddingModel.present
        ? embeddingModel.value
        : this.embeddingModel,
    embeddingDim: embeddingDim.present ? embeddingDim.value : this.embeddingDim,
    createdAt: createdAt ?? this.createdAt,
    validAt: validAt.present ? validAt.value : this.validAt,
    invalidAt: invalidAt.present ? invalidAt.value : this.invalidAt,
    ingestedAt: ingestedAt ?? this.ingestedAt,
    expiredAt: expiredAt.present ? expiredAt.value : this.expiredAt,
    lastAccessed: lastAccessed ?? this.lastAccessed,
    accessCount: accessCount ?? this.accessCount,
    temperature: temperature ?? this.temperature,
    baseScore: baseScore ?? this.baseScore,
    parentSummaryId: parentSummaryId.present
        ? parentSummaryId.value
        : this.parentSummaryId,
    isActive: isActive ?? this.isActive,
  );
  Entity copyWithCompanion(EntitiesCompanion data) {
    return Entity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      summary: data.summary.present ? data.summary.value : this.summary,
      properties: data.properties.present
          ? data.properties.value
          : this.properties,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingModel: data.embeddingModel.present
          ? data.embeddingModel.value
          : this.embeddingModel,
      embeddingDim: data.embeddingDim.present
          ? data.embeddingDim.value
          : this.embeddingDim,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      validAt: data.validAt.present ? data.validAt.value : this.validAt,
      invalidAt: data.invalidAt.present ? data.invalidAt.value : this.invalidAt,
      ingestedAt: data.ingestedAt.present
          ? data.ingestedAt.value
          : this.ingestedAt,
      expiredAt: data.expiredAt.present ? data.expiredAt.value : this.expiredAt,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
      accessCount: data.accessCount.present
          ? data.accessCount.value
          : this.accessCount,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      baseScore: data.baseScore.present ? data.baseScore.value : this.baseScore,
      parentSummaryId: data.parentSummaryId.present
          ? data.parentSummaryId.value
          : this.parentSummaryId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('entityType: $entityType, ')
          ..write('summary: $summary, ')
          ..write('properties: $properties, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('embeddingDim: $embeddingDim, ')
          ..write('createdAt: $createdAt, ')
          ..write('validAt: $validAt, ')
          ..write('invalidAt: $invalidAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('expiredAt: $expiredAt, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('accessCount: $accessCount, ')
          ..write('temperature: $temperature, ')
          ..write('baseScore: $baseScore, ')
          ..write('parentSummaryId: $parentSummaryId, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    entityType,
    summary,
    properties,
    $driftBlobEquality.hash(embedding),
    embeddingModel,
    embeddingDim,
    createdAt,
    validAt,
    invalidAt,
    ingestedAt,
    expiredAt,
    lastAccessed,
    accessCount,
    temperature,
    baseScore,
    parentSummaryId,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entity &&
          other.id == this.id &&
          other.name == this.name &&
          other.entityType == this.entityType &&
          other.summary == this.summary &&
          other.properties == this.properties &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.embeddingModel == this.embeddingModel &&
          other.embeddingDim == this.embeddingDim &&
          other.createdAt == this.createdAt &&
          other.validAt == this.validAt &&
          other.invalidAt == this.invalidAt &&
          other.ingestedAt == this.ingestedAt &&
          other.expiredAt == this.expiredAt &&
          other.lastAccessed == this.lastAccessed &&
          other.accessCount == this.accessCount &&
          other.temperature == this.temperature &&
          other.baseScore == this.baseScore &&
          other.parentSummaryId == this.parentSummaryId &&
          other.isActive == this.isActive);
}

class EntitiesCompanion extends UpdateCompanion<Entity> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> entityType;
  final Value<String?> summary;
  final Value<String> properties;
  final Value<Uint8List?> embedding;
  final Value<String?> embeddingModel;
  final Value<int?> embeddingDim;
  final Value<int> createdAt;
  final Value<int?> validAt;
  final Value<int?> invalidAt;
  final Value<int> ingestedAt;
  final Value<int?> expiredAt;
  final Value<int> lastAccessed;
  final Value<int> accessCount;
  final Value<String> temperature;
  final Value<double> baseScore;
  final Value<int?> parentSummaryId;
  final Value<int> isActive;
  const EntitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.entityType = const Value.absent(),
    this.summary = const Value.absent(),
    this.properties = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.embeddingDim = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.validAt = const Value.absent(),
    this.invalidAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.expiredAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.temperature = const Value.absent(),
    this.baseScore = const Value.absent(),
    this.parentSummaryId = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  EntitiesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.entityType = const Value.absent(),
    this.summary = const Value.absent(),
    this.properties = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.embeddingDim = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.validAt = const Value.absent(),
    this.invalidAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.expiredAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.temperature = const Value.absent(),
    this.baseScore = const Value.absent(),
    this.parentSummaryId = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Entity> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? entityType,
    Expression<String>? summary,
    Expression<String>? properties,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingModel,
    Expression<int>? embeddingDim,
    Expression<int>? createdAt,
    Expression<int>? validAt,
    Expression<int>? invalidAt,
    Expression<int>? ingestedAt,
    Expression<int>? expiredAt,
    Expression<int>? lastAccessed,
    Expression<int>? accessCount,
    Expression<String>? temperature,
    Expression<double>? baseScore,
    Expression<int>? parentSummaryId,
    Expression<int>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (entityType != null) 'entity_type': entityType,
      if (summary != null) 'summary': summary,
      if (properties != null) 'properties': properties,
      if (embedding != null) 'embedding': embedding,
      if (embeddingModel != null) 'embedding_model': embeddingModel,
      if (embeddingDim != null) 'embedding_dim': embeddingDim,
      if (createdAt != null) 'created_at': createdAt,
      if (validAt != null) 'valid_at': validAt,
      if (invalidAt != null) 'invalid_at': invalidAt,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (expiredAt != null) 'expired_at': expiredAt,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (accessCount != null) 'access_count': accessCount,
      if (temperature != null) 'temperature': temperature,
      if (baseScore != null) 'base_score': baseScore,
      if (parentSummaryId != null) 'parent_summary_id': parentSummaryId,
      if (isActive != null) 'is_active': isActive,
    });
  }

  EntitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? entityType,
    Value<String?>? summary,
    Value<String>? properties,
    Value<Uint8List?>? embedding,
    Value<String?>? embeddingModel,
    Value<int?>? embeddingDim,
    Value<int>? createdAt,
    Value<int?>? validAt,
    Value<int?>? invalidAt,
    Value<int>? ingestedAt,
    Value<int?>? expiredAt,
    Value<int>? lastAccessed,
    Value<int>? accessCount,
    Value<String>? temperature,
    Value<double>? baseScore,
    Value<int?>? parentSummaryId,
    Value<int>? isActive,
  }) {
    return EntitiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      entityType: entityType ?? this.entityType,
      summary: summary ?? this.summary,
      properties: properties ?? this.properties,
      embedding: embedding ?? this.embedding,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      embeddingDim: embeddingDim ?? this.embeddingDim,
      createdAt: createdAt ?? this.createdAt,
      validAt: validAt ?? this.validAt,
      invalidAt: invalidAt ?? this.invalidAt,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
      temperature: temperature ?? this.temperature,
      baseScore: baseScore ?? this.baseScore,
      parentSummaryId: parentSummaryId ?? this.parentSummaryId,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (properties.present) {
      map['properties'] = Variable<String>(properties.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (embeddingModel.present) {
      map['embedding_model'] = Variable<String>(embeddingModel.value);
    }
    if (embeddingDim.present) {
      map['embedding_dim'] = Variable<int>(embeddingDim.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (validAt.present) {
      map['valid_at'] = Variable<int>(validAt.value);
    }
    if (invalidAt.present) {
      map['invalid_at'] = Variable<int>(invalidAt.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<int>(ingestedAt.value);
    }
    if (expiredAt.present) {
      map['expired_at'] = Variable<int>(expiredAt.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<int>(lastAccessed.value);
    }
    if (accessCount.present) {
      map['access_count'] = Variable<int>(accessCount.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<String>(temperature.value);
    }
    if (baseScore.present) {
      map['base_score'] = Variable<double>(baseScore.value);
    }
    if (parentSummaryId.present) {
      map['parent_summary_id'] = Variable<int>(parentSummaryId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<int>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('entityType: $entityType, ')
          ..write('summary: $summary, ')
          ..write('properties: $properties, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('embeddingDim: $embeddingDim, ')
          ..write('createdAt: $createdAt, ')
          ..write('validAt: $validAt, ')
          ..write('invalidAt: $invalidAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('expiredAt: $expiredAt, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('accessCount: $accessCount, ')
          ..write('temperature: $temperature, ')
          ..write('baseScore: $baseScore, ')
          ..write('parentSummaryId: $parentSummaryId, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class Relations extends Table with TableInfo<Relations, Relation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Relations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES entities(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  late final GeneratedColumn<int> targetId = GeneratedColumn<int>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES entities(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _predicateMeta = const VerificationMeta(
    'predicate',
  );
  late final GeneratedColumn<String> predicate = GeneratedColumn<String>(
    'predicate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1.0',
    defaultValue: const CustomExpression('1.0'),
  );
  static const VerificationMeta _propertiesMeta = const VerificationMeta(
    'properties',
  );
  late final GeneratedColumn<String> properties = GeneratedColumn<String>(
    'properties',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _embeddingModelMeta = const VerificationMeta(
    'embeddingModel',
  );
  late final GeneratedColumn<String> embeddingModel = GeneratedColumn<String>(
    'embedding_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _embeddingDimMeta = const VerificationMeta(
    'embeddingDim',
  );
  late final GeneratedColumn<int> embeddingDim = GeneratedColumn<int>(
    'embedding_dim',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _validAtMeta = const VerificationMeta(
    'validAt',
  );
  late final GeneratedColumn<int> validAt = GeneratedColumn<int>(
    'valid_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _invalidAtMeta = const VerificationMeta(
    'invalidAt',
  );
  late final GeneratedColumn<int> invalidAt = GeneratedColumn<int>(
    'invalid_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _ingestedAtMeta = const VerificationMeta(
    'ingestedAt',
  );
  late final GeneratedColumn<int> ingestedAt = GeneratedColumn<int>(
    'ingested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _expiredAtMeta = const VerificationMeta(
    'expiredAt',
  );
  late final GeneratedColumn<int> expiredAt = GeneratedColumn<int>(
    'expired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastAccessedMeta = const VerificationMeta(
    'lastAccessed',
  );
  late final GeneratedColumn<int> lastAccessed = GeneratedColumn<int>(
    'last_accessed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _accessCountMeta = const VerificationMeta(
    'accessCount',
  );
  late final GeneratedColumn<int> accessCount = GeneratedColumn<int>(
    'access_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1.0',
    defaultValue: const CustomExpression('1.0'),
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  late final GeneratedColumn<int> isActive = GeneratedColumn<int>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    targetId,
    predicate,
    weight,
    properties,
    embedding,
    embeddingModel,
    embeddingDim,
    createdAt,
    validAt,
    invalidAt,
    ingestedAt,
    expiredAt,
    lastAccessed,
    accessCount,
    confidence,
    sourceText,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'relations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Relation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('predicate')) {
      context.handle(
        _predicateMeta,
        predicate.isAcceptableOrUnknown(data['predicate']!, _predicateMeta),
      );
    } else if (isInserting) {
      context.missing(_predicateMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('properties')) {
      context.handle(
        _propertiesMeta,
        properties.isAcceptableOrUnknown(data['properties']!, _propertiesMeta),
      );
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('embedding_model')) {
      context.handle(
        _embeddingModelMeta,
        embeddingModel.isAcceptableOrUnknown(
          data['embedding_model']!,
          _embeddingModelMeta,
        ),
      );
    }
    if (data.containsKey('embedding_dim')) {
      context.handle(
        _embeddingDimMeta,
        embeddingDim.isAcceptableOrUnknown(
          data['embedding_dim']!,
          _embeddingDimMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('valid_at')) {
      context.handle(
        _validAtMeta,
        validAt.isAcceptableOrUnknown(data['valid_at']!, _validAtMeta),
      );
    }
    if (data.containsKey('invalid_at')) {
      context.handle(
        _invalidAtMeta,
        invalidAt.isAcceptableOrUnknown(data['invalid_at']!, _invalidAtMeta),
      );
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
        _ingestedAtMeta,
        ingestedAt.isAcceptableOrUnknown(data['ingested_at']!, _ingestedAtMeta),
      );
    }
    if (data.containsKey('expired_at')) {
      context.handle(
        _expiredAtMeta,
        expiredAt.isAcceptableOrUnknown(data['expired_at']!, _expiredAtMeta),
      );
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
        _lastAccessedMeta,
        lastAccessed.isAcceptableOrUnknown(
          data['last_accessed']!,
          _lastAccessedMeta,
        ),
      );
    }
    if (data.containsKey('access_count')) {
      context.handle(
        _accessCountMeta,
        accessCount.isAcceptableOrUnknown(
          data['access_count']!,
          _accessCountMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Relation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Relation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_id'],
      )!,
      predicate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}predicate'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      properties: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}properties'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      embeddingModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_model'],
      ),
      embeddingDim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}embedding_dim'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      validAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valid_at'],
      ),
      invalidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invalid_at'],
      ),
      ingestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingested_at'],
      )!,
      expiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expired_at'],
      ),
      lastAccessed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed'],
      )!,
      accessCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}access_count'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  Relations createAlias(String alias) {
    return Relations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Relation extends DataClass implements Insertable<Relation> {
  final int id;
  final int sourceId;
  final int targetId;
  final String predicate;
  final double weight;
  final String properties;
  final Uint8List? embedding;

  /// Embedding provenance (v4) — see entities.embedding_model.
  final String? embeddingModel;
  final int? embeddingDim;

  /// Bi-temporal
  final int createdAt;
  final int? validAt;
  final int? invalidAt;
  final int ingestedAt;
  final int? expiredAt;

  /// Activation
  final int lastAccessed;
  final int accessCount;
  final double confidence;
  final String? sourceText;
  final int isActive;
  const Relation({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.predicate,
    required this.weight,
    required this.properties,
    this.embedding,
    this.embeddingModel,
    this.embeddingDim,
    required this.createdAt,
    this.validAt,
    this.invalidAt,
    required this.ingestedAt,
    this.expiredAt,
    required this.lastAccessed,
    required this.accessCount,
    required this.confidence,
    this.sourceText,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['target_id'] = Variable<int>(targetId);
    map['predicate'] = Variable<String>(predicate);
    map['weight'] = Variable<double>(weight);
    map['properties'] = Variable<String>(properties);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    if (!nullToAbsent || embeddingModel != null) {
      map['embedding_model'] = Variable<String>(embeddingModel);
    }
    if (!nullToAbsent || embeddingDim != null) {
      map['embedding_dim'] = Variable<int>(embeddingDim);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || validAt != null) {
      map['valid_at'] = Variable<int>(validAt);
    }
    if (!nullToAbsent || invalidAt != null) {
      map['invalid_at'] = Variable<int>(invalidAt);
    }
    map['ingested_at'] = Variable<int>(ingestedAt);
    if (!nullToAbsent || expiredAt != null) {
      map['expired_at'] = Variable<int>(expiredAt);
    }
    map['last_accessed'] = Variable<int>(lastAccessed);
    map['access_count'] = Variable<int>(accessCount);
    map['confidence'] = Variable<double>(confidence);
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    map['is_active'] = Variable<int>(isActive);
    return map;
  }

  RelationsCompanion toCompanion(bool nullToAbsent) {
    return RelationsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      targetId: Value(targetId),
      predicate: Value(predicate),
      weight: Value(weight),
      properties: Value(properties),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      embeddingModel: embeddingModel == null && nullToAbsent
          ? const Value.absent()
          : Value(embeddingModel),
      embeddingDim: embeddingDim == null && nullToAbsent
          ? const Value.absent()
          : Value(embeddingDim),
      createdAt: Value(createdAt),
      validAt: validAt == null && nullToAbsent
          ? const Value.absent()
          : Value(validAt),
      invalidAt: invalidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(invalidAt),
      ingestedAt: Value(ingestedAt),
      expiredAt: expiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiredAt),
      lastAccessed: Value(lastAccessed),
      accessCount: Value(accessCount),
      confidence: Value(confidence),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
      isActive: Value(isActive),
    );
  }

  factory Relation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Relation(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['source_id']),
      targetId: serializer.fromJson<int>(json['target_id']),
      predicate: serializer.fromJson<String>(json['predicate']),
      weight: serializer.fromJson<double>(json['weight']),
      properties: serializer.fromJson<String>(json['properties']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      embeddingModel: serializer.fromJson<String?>(json['embedding_model']),
      embeddingDim: serializer.fromJson<int?>(json['embedding_dim']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      validAt: serializer.fromJson<int?>(json['valid_at']),
      invalidAt: serializer.fromJson<int?>(json['invalid_at']),
      ingestedAt: serializer.fromJson<int>(json['ingested_at']),
      expiredAt: serializer.fromJson<int?>(json['expired_at']),
      lastAccessed: serializer.fromJson<int>(json['last_accessed']),
      accessCount: serializer.fromJson<int>(json['access_count']),
      confidence: serializer.fromJson<double>(json['confidence']),
      sourceText: serializer.fromJson<String?>(json['source_text']),
      isActive: serializer.fromJson<int>(json['is_active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source_id': serializer.toJson<int>(sourceId),
      'target_id': serializer.toJson<int>(targetId),
      'predicate': serializer.toJson<String>(predicate),
      'weight': serializer.toJson<double>(weight),
      'properties': serializer.toJson<String>(properties),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'embedding_model': serializer.toJson<String?>(embeddingModel),
      'embedding_dim': serializer.toJson<int?>(embeddingDim),
      'created_at': serializer.toJson<int>(createdAt),
      'valid_at': serializer.toJson<int?>(validAt),
      'invalid_at': serializer.toJson<int?>(invalidAt),
      'ingested_at': serializer.toJson<int>(ingestedAt),
      'expired_at': serializer.toJson<int?>(expiredAt),
      'last_accessed': serializer.toJson<int>(lastAccessed),
      'access_count': serializer.toJson<int>(accessCount),
      'confidence': serializer.toJson<double>(confidence),
      'source_text': serializer.toJson<String?>(sourceText),
      'is_active': serializer.toJson<int>(isActive),
    };
  }

  Relation copyWith({
    int? id,
    int? sourceId,
    int? targetId,
    String? predicate,
    double? weight,
    String? properties,
    Value<Uint8List?> embedding = const Value.absent(),
    Value<String?> embeddingModel = const Value.absent(),
    Value<int?> embeddingDim = const Value.absent(),
    int? createdAt,
    Value<int?> validAt = const Value.absent(),
    Value<int?> invalidAt = const Value.absent(),
    int? ingestedAt,
    Value<int?> expiredAt = const Value.absent(),
    int? lastAccessed,
    int? accessCount,
    double? confidence,
    Value<String?> sourceText = const Value.absent(),
    int? isActive,
  }) => Relation(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    targetId: targetId ?? this.targetId,
    predicate: predicate ?? this.predicate,
    weight: weight ?? this.weight,
    properties: properties ?? this.properties,
    embedding: embedding.present ? embedding.value : this.embedding,
    embeddingModel: embeddingModel.present
        ? embeddingModel.value
        : this.embeddingModel,
    embeddingDim: embeddingDim.present ? embeddingDim.value : this.embeddingDim,
    createdAt: createdAt ?? this.createdAt,
    validAt: validAt.present ? validAt.value : this.validAt,
    invalidAt: invalidAt.present ? invalidAt.value : this.invalidAt,
    ingestedAt: ingestedAt ?? this.ingestedAt,
    expiredAt: expiredAt.present ? expiredAt.value : this.expiredAt,
    lastAccessed: lastAccessed ?? this.lastAccessed,
    accessCount: accessCount ?? this.accessCount,
    confidence: confidence ?? this.confidence,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
    isActive: isActive ?? this.isActive,
  );
  Relation copyWithCompanion(RelationsCompanion data) {
    return Relation(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      predicate: data.predicate.present ? data.predicate.value : this.predicate,
      weight: data.weight.present ? data.weight.value : this.weight,
      properties: data.properties.present
          ? data.properties.value
          : this.properties,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingModel: data.embeddingModel.present
          ? data.embeddingModel.value
          : this.embeddingModel,
      embeddingDim: data.embeddingDim.present
          ? data.embeddingDim.value
          : this.embeddingDim,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      validAt: data.validAt.present ? data.validAt.value : this.validAt,
      invalidAt: data.invalidAt.present ? data.invalidAt.value : this.invalidAt,
      ingestedAt: data.ingestedAt.present
          ? data.ingestedAt.value
          : this.ingestedAt,
      expiredAt: data.expiredAt.present ? data.expiredAt.value : this.expiredAt,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
      accessCount: data.accessCount.present
          ? data.accessCount.value
          : this.accessCount,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Relation(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('predicate: $predicate, ')
          ..write('weight: $weight, ')
          ..write('properties: $properties, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('embeddingDim: $embeddingDim, ')
          ..write('createdAt: $createdAt, ')
          ..write('validAt: $validAt, ')
          ..write('invalidAt: $invalidAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('expiredAt: $expiredAt, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('accessCount: $accessCount, ')
          ..write('confidence: $confidence, ')
          ..write('sourceText: $sourceText, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    targetId,
    predicate,
    weight,
    properties,
    $driftBlobEquality.hash(embedding),
    embeddingModel,
    embeddingDim,
    createdAt,
    validAt,
    invalidAt,
    ingestedAt,
    expiredAt,
    lastAccessed,
    accessCount,
    confidence,
    sourceText,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Relation &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.targetId == this.targetId &&
          other.predicate == this.predicate &&
          other.weight == this.weight &&
          other.properties == this.properties &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.embeddingModel == this.embeddingModel &&
          other.embeddingDim == this.embeddingDim &&
          other.createdAt == this.createdAt &&
          other.validAt == this.validAt &&
          other.invalidAt == this.invalidAt &&
          other.ingestedAt == this.ingestedAt &&
          other.expiredAt == this.expiredAt &&
          other.lastAccessed == this.lastAccessed &&
          other.accessCount == this.accessCount &&
          other.confidence == this.confidence &&
          other.sourceText == this.sourceText &&
          other.isActive == this.isActive);
}

class RelationsCompanion extends UpdateCompanion<Relation> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<int> targetId;
  final Value<String> predicate;
  final Value<double> weight;
  final Value<String> properties;
  final Value<Uint8List?> embedding;
  final Value<String?> embeddingModel;
  final Value<int?> embeddingDim;
  final Value<int> createdAt;
  final Value<int?> validAt;
  final Value<int?> invalidAt;
  final Value<int> ingestedAt;
  final Value<int?> expiredAt;
  final Value<int> lastAccessed;
  final Value<int> accessCount;
  final Value<double> confidence;
  final Value<String?> sourceText;
  final Value<int> isActive;
  const RelationsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.predicate = const Value.absent(),
    this.weight = const Value.absent(),
    this.properties = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.embeddingDim = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.validAt = const Value.absent(),
    this.invalidAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.expiredAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.confidence = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  RelationsCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required int targetId,
    required String predicate,
    this.weight = const Value.absent(),
    this.properties = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.embeddingDim = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.validAt = const Value.absent(),
    this.invalidAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.expiredAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.confidence = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : sourceId = Value(sourceId),
       targetId = Value(targetId),
       predicate = Value(predicate);
  static Insertable<Relation> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<int>? targetId,
    Expression<String>? predicate,
    Expression<double>? weight,
    Expression<String>? properties,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingModel,
    Expression<int>? embeddingDim,
    Expression<int>? createdAt,
    Expression<int>? validAt,
    Expression<int>? invalidAt,
    Expression<int>? ingestedAt,
    Expression<int>? expiredAt,
    Expression<int>? lastAccessed,
    Expression<int>? accessCount,
    Expression<double>? confidence,
    Expression<String>? sourceText,
    Expression<int>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (targetId != null) 'target_id': targetId,
      if (predicate != null) 'predicate': predicate,
      if (weight != null) 'weight': weight,
      if (properties != null) 'properties': properties,
      if (embedding != null) 'embedding': embedding,
      if (embeddingModel != null) 'embedding_model': embeddingModel,
      if (embeddingDim != null) 'embedding_dim': embeddingDim,
      if (createdAt != null) 'created_at': createdAt,
      if (validAt != null) 'valid_at': validAt,
      if (invalidAt != null) 'invalid_at': invalidAt,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (expiredAt != null) 'expired_at': expiredAt,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (accessCount != null) 'access_count': accessCount,
      if (confidence != null) 'confidence': confidence,
      if (sourceText != null) 'source_text': sourceText,
      if (isActive != null) 'is_active': isActive,
    });
  }

  RelationsCompanion copyWith({
    Value<int>? id,
    Value<int>? sourceId,
    Value<int>? targetId,
    Value<String>? predicate,
    Value<double>? weight,
    Value<String>? properties,
    Value<Uint8List?>? embedding,
    Value<String?>? embeddingModel,
    Value<int?>? embeddingDim,
    Value<int>? createdAt,
    Value<int?>? validAt,
    Value<int?>? invalidAt,
    Value<int>? ingestedAt,
    Value<int?>? expiredAt,
    Value<int>? lastAccessed,
    Value<int>? accessCount,
    Value<double>? confidence,
    Value<String?>? sourceText,
    Value<int>? isActive,
  }) {
    return RelationsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      predicate: predicate ?? this.predicate,
      weight: weight ?? this.weight,
      properties: properties ?? this.properties,
      embedding: embedding ?? this.embedding,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      embeddingDim: embeddingDim ?? this.embeddingDim,
      createdAt: createdAt ?? this.createdAt,
      validAt: validAt ?? this.validAt,
      invalidAt: invalidAt ?? this.invalidAt,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
      confidence: confidence ?? this.confidence,
      sourceText: sourceText ?? this.sourceText,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<int>(targetId.value);
    }
    if (predicate.present) {
      map['predicate'] = Variable<String>(predicate.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (properties.present) {
      map['properties'] = Variable<String>(properties.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (embeddingModel.present) {
      map['embedding_model'] = Variable<String>(embeddingModel.value);
    }
    if (embeddingDim.present) {
      map['embedding_dim'] = Variable<int>(embeddingDim.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (validAt.present) {
      map['valid_at'] = Variable<int>(validAt.value);
    }
    if (invalidAt.present) {
      map['invalid_at'] = Variable<int>(invalidAt.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<int>(ingestedAt.value);
    }
    if (expiredAt.present) {
      map['expired_at'] = Variable<int>(expiredAt.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<int>(lastAccessed.value);
    }
    if (accessCount.present) {
      map['access_count'] = Variable<int>(accessCount.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<int>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RelationsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('predicate: $predicate, ')
          ..write('weight: $weight, ')
          ..write('properties: $properties, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('embeddingDim: $embeddingDim, ')
          ..write('createdAt: $createdAt, ')
          ..write('validAt: $validAt, ')
          ..write('invalidAt: $invalidAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('expiredAt: $expiredAt, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('accessCount: $accessCount, ')
          ..write('confidence: $confidence, ')
          ..write('sourceText: $sourceText, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class Facts extends Table with TableInfo<Facts, Fact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Facts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES entities(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _factKeyMeta = const VerificationMeta(
    'factKey',
  );
  late final GeneratedColumn<String> factKey = GeneratedColumn<String>(
    'fact_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _factValueMeta = const VerificationMeta(
    'factValue',
  );
  late final GeneratedColumn<String> factValue = GeneratedColumn<String>(
    'fact_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'string\'',
    defaultValue: const CustomExpression('\'string\''),
  );
  static const VerificationMeta _validAtMeta = const VerificationMeta(
    'validAt',
  );
  late final GeneratedColumn<int> validAt = GeneratedColumn<int>(
    'valid_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _invalidAtMeta = const VerificationMeta(
    'invalidAt',
  );
  late final GeneratedColumn<int> invalidAt = GeneratedColumn<int>(
    'invalid_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _ingestedAtMeta = const VerificationMeta(
    'ingestedAt',
  );
  late final GeneratedColumn<int> ingestedAt = GeneratedColumn<int>(
    'ingested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT (strftime(\'%s\', \'now\'))',
    defaultValue: const CustomExpression('strftime(\'%s\', \'now\')'),
  );
  static const VerificationMeta _expiredAtMeta = const VerificationMeta(
    'expiredAt',
  );
  late final GeneratedColumn<int> expiredAt = GeneratedColumn<int>(
    'expired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1.0',
    defaultValue: const CustomExpression('1.0'),
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityId,
    factKey,
    factValue,
    valueType,
    validAt,
    invalidAt,
    ingestedAt,
    expiredAt,
    confidence,
    sourceText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'facts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Fact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('fact_key')) {
      context.handle(
        _factKeyMeta,
        factKey.isAcceptableOrUnknown(data['fact_key']!, _factKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_factKeyMeta);
    }
    if (data.containsKey('fact_value')) {
      context.handle(
        _factValueMeta,
        factValue.isAcceptableOrUnknown(data['fact_value']!, _factValueMeta),
      );
    } else if (isInserting) {
      context.missing(_factValueMeta);
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    }
    if (data.containsKey('valid_at')) {
      context.handle(
        _validAtMeta,
        validAt.isAcceptableOrUnknown(data['valid_at']!, _validAtMeta),
      );
    }
    if (data.containsKey('invalid_at')) {
      context.handle(
        _invalidAtMeta,
        invalidAt.isAcceptableOrUnknown(data['invalid_at']!, _invalidAtMeta),
      );
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
        _ingestedAtMeta,
        ingestedAt.isAcceptableOrUnknown(data['ingested_at']!, _ingestedAtMeta),
      );
    }
    if (data.containsKey('expired_at')) {
      context.handle(
        _expiredAtMeta,
        expiredAt.isAcceptableOrUnknown(data['expired_at']!, _expiredAtMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Fact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Fact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_id'],
      )!,
      factKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_key'],
      )!,
      factValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_value'],
      )!,
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      validAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valid_at'],
      ),
      invalidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invalid_at'],
      ),
      ingestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingested_at'],
      )!,
      expiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expired_at'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
    );
  }

  @override
  Facts createAlias(String alias) {
    return Facts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Fact extends DataClass implements Insertable<Fact> {
  final int id;
  final int entityId;
  final String factKey;
  final String factValue;
  final String valueType;
  final int? validAt;
  final int? invalidAt;
  final int ingestedAt;
  final int? expiredAt;
  final double confidence;
  final String? sourceText;
  const Fact({
    required this.id,
    required this.entityId,
    required this.factKey,
    required this.factValue,
    required this.valueType,
    this.validAt,
    this.invalidAt,
    required this.ingestedAt,
    this.expiredAt,
    required this.confidence,
    this.sourceText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<int>(entityId);
    map['fact_key'] = Variable<String>(factKey);
    map['fact_value'] = Variable<String>(factValue);
    map['value_type'] = Variable<String>(valueType);
    if (!nullToAbsent || validAt != null) {
      map['valid_at'] = Variable<int>(validAt);
    }
    if (!nullToAbsent || invalidAt != null) {
      map['invalid_at'] = Variable<int>(invalidAt);
    }
    map['ingested_at'] = Variable<int>(ingestedAt);
    if (!nullToAbsent || expiredAt != null) {
      map['expired_at'] = Variable<int>(expiredAt);
    }
    map['confidence'] = Variable<double>(confidence);
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    return map;
  }

  FactsCompanion toCompanion(bool nullToAbsent) {
    return FactsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      factKey: Value(factKey),
      factValue: Value(factValue),
      valueType: Value(valueType),
      validAt: validAt == null && nullToAbsent
          ? const Value.absent()
          : Value(validAt),
      invalidAt: invalidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(invalidAt),
      ingestedAt: Value(ingestedAt),
      expiredAt: expiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiredAt),
      confidence: Value(confidence),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
    );
  }

  factory Fact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Fact(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<int>(json['entity_id']),
      factKey: serializer.fromJson<String>(json['fact_key']),
      factValue: serializer.fromJson<String>(json['fact_value']),
      valueType: serializer.fromJson<String>(json['value_type']),
      validAt: serializer.fromJson<int?>(json['valid_at']),
      invalidAt: serializer.fromJson<int?>(json['invalid_at']),
      ingestedAt: serializer.fromJson<int>(json['ingested_at']),
      expiredAt: serializer.fromJson<int?>(json['expired_at']),
      confidence: serializer.fromJson<double>(json['confidence']),
      sourceText: serializer.fromJson<String?>(json['source_text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity_id': serializer.toJson<int>(entityId),
      'fact_key': serializer.toJson<String>(factKey),
      'fact_value': serializer.toJson<String>(factValue),
      'value_type': serializer.toJson<String>(valueType),
      'valid_at': serializer.toJson<int?>(validAt),
      'invalid_at': serializer.toJson<int?>(invalidAt),
      'ingested_at': serializer.toJson<int>(ingestedAt),
      'expired_at': serializer.toJson<int?>(expiredAt),
      'confidence': serializer.toJson<double>(confidence),
      'source_text': serializer.toJson<String?>(sourceText),
    };
  }

  Fact copyWith({
    int? id,
    int? entityId,
    String? factKey,
    String? factValue,
    String? valueType,
    Value<int?> validAt = const Value.absent(),
    Value<int?> invalidAt = const Value.absent(),
    int? ingestedAt,
    Value<int?> expiredAt = const Value.absent(),
    double? confidence,
    Value<String?> sourceText = const Value.absent(),
  }) => Fact(
    id: id ?? this.id,
    entityId: entityId ?? this.entityId,
    factKey: factKey ?? this.factKey,
    factValue: factValue ?? this.factValue,
    valueType: valueType ?? this.valueType,
    validAt: validAt.present ? validAt.value : this.validAt,
    invalidAt: invalidAt.present ? invalidAt.value : this.invalidAt,
    ingestedAt: ingestedAt ?? this.ingestedAt,
    expiredAt: expiredAt.present ? expiredAt.value : this.expiredAt,
    confidence: confidence ?? this.confidence,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
  );
  Fact copyWithCompanion(FactsCompanion data) {
    return Fact(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      factKey: data.factKey.present ? data.factKey.value : this.factKey,
      factValue: data.factValue.present ? data.factValue.value : this.factValue,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      validAt: data.validAt.present ? data.validAt.value : this.validAt,
      invalidAt: data.invalidAt.present ? data.invalidAt.value : this.invalidAt,
      ingestedAt: data.ingestedAt.present
          ? data.ingestedAt.value
          : this.ingestedAt,
      expiredAt: data.expiredAt.present ? data.expiredAt.value : this.expiredAt,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Fact(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('factKey: $factKey, ')
          ..write('factValue: $factValue, ')
          ..write('valueType: $valueType, ')
          ..write('validAt: $validAt, ')
          ..write('invalidAt: $invalidAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('expiredAt: $expiredAt, ')
          ..write('confidence: $confidence, ')
          ..write('sourceText: $sourceText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityId,
    factKey,
    factValue,
    valueType,
    validAt,
    invalidAt,
    ingestedAt,
    expiredAt,
    confidence,
    sourceText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Fact &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.factKey == this.factKey &&
          other.factValue == this.factValue &&
          other.valueType == this.valueType &&
          other.validAt == this.validAt &&
          other.invalidAt == this.invalidAt &&
          other.ingestedAt == this.ingestedAt &&
          other.expiredAt == this.expiredAt &&
          other.confidence == this.confidence &&
          other.sourceText == this.sourceText);
}

class FactsCompanion extends UpdateCompanion<Fact> {
  final Value<int> id;
  final Value<int> entityId;
  final Value<String> factKey;
  final Value<String> factValue;
  final Value<String> valueType;
  final Value<int?> validAt;
  final Value<int?> invalidAt;
  final Value<int> ingestedAt;
  final Value<int?> expiredAt;
  final Value<double> confidence;
  final Value<String?> sourceText;
  const FactsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.factKey = const Value.absent(),
    this.factValue = const Value.absent(),
    this.valueType = const Value.absent(),
    this.validAt = const Value.absent(),
    this.invalidAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.expiredAt = const Value.absent(),
    this.confidence = const Value.absent(),
    this.sourceText = const Value.absent(),
  });
  FactsCompanion.insert({
    this.id = const Value.absent(),
    required int entityId,
    required String factKey,
    required String factValue,
    this.valueType = const Value.absent(),
    this.validAt = const Value.absent(),
    this.invalidAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.expiredAt = const Value.absent(),
    this.confidence = const Value.absent(),
    this.sourceText = const Value.absent(),
  }) : entityId = Value(entityId),
       factKey = Value(factKey),
       factValue = Value(factValue);
  static Insertable<Fact> custom({
    Expression<int>? id,
    Expression<int>? entityId,
    Expression<String>? factKey,
    Expression<String>? factValue,
    Expression<String>? valueType,
    Expression<int>? validAt,
    Expression<int>? invalidAt,
    Expression<int>? ingestedAt,
    Expression<int>? expiredAt,
    Expression<double>? confidence,
    Expression<String>? sourceText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (factKey != null) 'fact_key': factKey,
      if (factValue != null) 'fact_value': factValue,
      if (valueType != null) 'value_type': valueType,
      if (validAt != null) 'valid_at': validAt,
      if (invalidAt != null) 'invalid_at': invalidAt,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (expiredAt != null) 'expired_at': expiredAt,
      if (confidence != null) 'confidence': confidence,
      if (sourceText != null) 'source_text': sourceText,
    });
  }

  FactsCompanion copyWith({
    Value<int>? id,
    Value<int>? entityId,
    Value<String>? factKey,
    Value<String>? factValue,
    Value<String>? valueType,
    Value<int?>? validAt,
    Value<int?>? invalidAt,
    Value<int>? ingestedAt,
    Value<int?>? expiredAt,
    Value<double>? confidence,
    Value<String?>? sourceText,
  }) {
    return FactsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      factKey: factKey ?? this.factKey,
      factValue: factValue ?? this.factValue,
      valueType: valueType ?? this.valueType,
      validAt: validAt ?? this.validAt,
      invalidAt: invalidAt ?? this.invalidAt,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      confidence: confidence ?? this.confidence,
      sourceText: sourceText ?? this.sourceText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (factKey.present) {
      map['fact_key'] = Variable<String>(factKey.value);
    }
    if (factValue.present) {
      map['fact_value'] = Variable<String>(factValue.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (validAt.present) {
      map['valid_at'] = Variable<int>(validAt.value);
    }
    if (invalidAt.present) {
      map['invalid_at'] = Variable<int>(invalidAt.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<int>(ingestedAt.value);
    }
    if (expiredAt.present) {
      map['expired_at'] = Variable<int>(expiredAt.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('factKey: $factKey, ')
          ..write('factValue: $factValue, ')
          ..write('valueType: $valueType, ')
          ..write('validAt: $validAt, ')
          ..write('invalidAt: $invalidAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('expiredAt: $expiredAt, ')
          ..write('confidence: $confidence, ')
          ..write('sourceText: $sourceText')
          ..write(')'))
        .toString();
  }
}

class Aliases extends Table with TableInfo<Aliases, Aliase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Aliases(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES entities(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _aliasNameMeta = const VerificationMeta(
    'aliasName',
  );
  late final GeneratedColumn<String> aliasName = GeneratedColumn<String>(
    'alias_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL COLLATE NOCASE',
  );
  static const VerificationMeta _aliasTypeMeta = const VerificationMeta(
    'aliasType',
  );
  late final GeneratedColumn<String> aliasType = GeneratedColumn<String>(
    'alias_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'name\'',
    defaultValue: const CustomExpression('\'name\''),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1.0',
    defaultValue: const CustomExpression('1.0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityId,
    aliasName,
    aliasType,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Aliase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('alias_name')) {
      context.handle(
        _aliasNameMeta,
        aliasName.isAcceptableOrUnknown(data['alias_name']!, _aliasNameMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasNameMeta);
    }
    if (data.containsKey('alias_type')) {
      context.handle(
        _aliasTypeMeta,
        aliasType.isAcceptableOrUnknown(data['alias_type']!, _aliasTypeMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Aliase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Aliase(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_id'],
      )!,
      aliasName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias_name'],
      )!,
      aliasType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias_type'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  Aliases createAlias(String alias) {
    return Aliases(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Aliase extends DataClass implements Insertable<Aliase> {
  final int id;
  final int entityId;
  final String aliasName;
  final String aliasType;
  final double confidence;
  const Aliase({
    required this.id,
    required this.entityId,
    required this.aliasName,
    required this.aliasType,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<int>(entityId);
    map['alias_name'] = Variable<String>(aliasName);
    map['alias_type'] = Variable<String>(aliasType);
    map['confidence'] = Variable<double>(confidence);
    return map;
  }

  AliasesCompanion toCompanion(bool nullToAbsent) {
    return AliasesCompanion(
      id: Value(id),
      entityId: Value(entityId),
      aliasName: Value(aliasName),
      aliasType: Value(aliasType),
      confidence: Value(confidence),
    );
  }

  factory Aliase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Aliase(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<int>(json['entity_id']),
      aliasName: serializer.fromJson<String>(json['alias_name']),
      aliasType: serializer.fromJson<String>(json['alias_type']),
      confidence: serializer.fromJson<double>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity_id': serializer.toJson<int>(entityId),
      'alias_name': serializer.toJson<String>(aliasName),
      'alias_type': serializer.toJson<String>(aliasType),
      'confidence': serializer.toJson<double>(confidence),
    };
  }

  Aliase copyWith({
    int? id,
    int? entityId,
    String? aliasName,
    String? aliasType,
    double? confidence,
  }) => Aliase(
    id: id ?? this.id,
    entityId: entityId ?? this.entityId,
    aliasName: aliasName ?? this.aliasName,
    aliasType: aliasType ?? this.aliasType,
    confidence: confidence ?? this.confidence,
  );
  Aliase copyWithCompanion(AliasesCompanion data) {
    return Aliase(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      aliasName: data.aliasName.present ? data.aliasName.value : this.aliasName,
      aliasType: data.aliasType.present ? data.aliasType.value : this.aliasType,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Aliase(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('aliasName: $aliasName, ')
          ..write('aliasType: $aliasType, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityId, aliasName, aliasType, confidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Aliase &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.aliasName == this.aliasName &&
          other.aliasType == this.aliasType &&
          other.confidence == this.confidence);
}

class AliasesCompanion extends UpdateCompanion<Aliase> {
  final Value<int> id;
  final Value<int> entityId;
  final Value<String> aliasName;
  final Value<String> aliasType;
  final Value<double> confidence;
  const AliasesCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.aliasName = const Value.absent(),
    this.aliasType = const Value.absent(),
    this.confidence = const Value.absent(),
  });
  AliasesCompanion.insert({
    this.id = const Value.absent(),
    required int entityId,
    required String aliasName,
    this.aliasType = const Value.absent(),
    this.confidence = const Value.absent(),
  }) : entityId = Value(entityId),
       aliasName = Value(aliasName);
  static Insertable<Aliase> custom({
    Expression<int>? id,
    Expression<int>? entityId,
    Expression<String>? aliasName,
    Expression<String>? aliasType,
    Expression<double>? confidence,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (aliasName != null) 'alias_name': aliasName,
      if (aliasType != null) 'alias_type': aliasType,
      if (confidence != null) 'confidence': confidence,
    });
  }

  AliasesCompanion copyWith({
    Value<int>? id,
    Value<int>? entityId,
    Value<String>? aliasName,
    Value<String>? aliasType,
    Value<double>? confidence,
  }) {
    return AliasesCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      aliasName: aliasName ?? this.aliasName,
      aliasType: aliasType ?? this.aliasType,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (aliasName.present) {
      map['alias_name'] = Variable<String>(aliasName.value);
    }
    if (aliasType.present) {
      map['alias_type'] = Variable<String>(aliasType.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AliasesCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('aliasName: $aliasName, ')
          ..write('aliasType: $aliasType, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }
}

class EntitiesFts extends Table
    with
        TableInfo<EntitiesFts, EntitiesFt>,
        VirtualTableInfo<EntitiesFts, EntitiesFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EntitiesFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [name, summary, entityType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entities_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntitiesFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  EntitiesFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntitiesFt(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      ),
    );
  }

  @override
  EntitiesFts createAlias(String alias) {
    return EntitiesFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(name, summary, entity_type, content=entities, content_rowid=id, prefix=\'2 3\', tokenize=\'unicode61\')';
}

class EntitiesFt extends DataClass implements Insertable<EntitiesFt> {
  final String? name;
  final String? summary;
  final String? entityType;
  const EntitiesFt({this.name, this.summary, this.entityType});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || entityType != null) {
      map['entity_type'] = Variable<String>(entityType);
    }
    return map;
  }

  EntitiesFtsCompanion toCompanion(bool nullToAbsent) {
    return EntitiesFtsCompanion(
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      entityType: entityType == null && nullToAbsent
          ? const Value.absent()
          : Value(entityType),
    );
  }

  factory EntitiesFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntitiesFt(
      name: serializer.fromJson<String?>(json['name']),
      summary: serializer.fromJson<String?>(json['summary']),
      entityType: serializer.fromJson<String?>(json['entity_type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String?>(name),
      'summary': serializer.toJson<String?>(summary),
      'entity_type': serializer.toJson<String?>(entityType),
    };
  }

  EntitiesFt copyWith({
    Value<String?> name = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> entityType = const Value.absent(),
  }) => EntitiesFt(
    name: name.present ? name.value : this.name,
    summary: summary.present ? summary.value : this.summary,
    entityType: entityType.present ? entityType.value : this.entityType,
  );
  EntitiesFt copyWithCompanion(EntitiesFtsCompanion data) {
    return EntitiesFt(
      name: data.name.present ? data.name.value : this.name,
      summary: data.summary.present ? data.summary.value : this.summary,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntitiesFt(')
          ..write('name: $name, ')
          ..write('summary: $summary, ')
          ..write('entityType: $entityType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, summary, entityType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntitiesFt &&
          other.name == this.name &&
          other.summary == this.summary &&
          other.entityType == this.entityType);
}

class EntitiesFtsCompanion extends UpdateCompanion<EntitiesFt> {
  final Value<String?> name;
  final Value<String?> summary;
  final Value<String?> entityType;
  final Value<int> rowid;
  const EntitiesFtsCompanion({
    this.name = const Value.absent(),
    this.summary = const Value.absent(),
    this.entityType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntitiesFtsCompanion.insert({
    this.name = const Value.absent(),
    this.summary = const Value.absent(),
    this.entityType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<EntitiesFt> custom({
    Expression<String>? name,
    Expression<String>? summary,
    Expression<String>? entityType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (summary != null) 'summary': summary,
      if (entityType != null) 'entity_type': entityType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntitiesFtsCompanion copyWith({
    Value<String?>? name,
    Value<String?>? summary,
    Value<String?>? entityType,
    Value<int>? rowid,
  }) {
    return EntitiesFtsCompanion(
      name: name ?? this.name,
      summary: summary ?? this.summary,
      entityType: entityType ?? this.entityType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntitiesFtsCompanion(')
          ..write('name: $name, ')
          ..write('summary: $summary, ')
          ..write('entityType: $entityType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class FactsFts extends Table
    with TableInfo<FactsFts, FactsFt>, VirtualTableInfo<FactsFts, FactsFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  FactsFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _factKeyMeta = const VerificationMeta(
    'factKey',
  );
  late final GeneratedColumn<String> factKey = GeneratedColumn<String>(
    'fact_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _factValueMeta = const VerificationMeta(
    'factValue',
  );
  late final GeneratedColumn<String> factValue = GeneratedColumn<String>(
    'fact_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [factKey, factValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'facts_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<FactsFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fact_key')) {
      context.handle(
        _factKeyMeta,
        factKey.isAcceptableOrUnknown(data['fact_key']!, _factKeyMeta),
      );
    }
    if (data.containsKey('fact_value')) {
      context.handle(
        _factValueMeta,
        factValue.isAcceptableOrUnknown(data['fact_value']!, _factValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  FactsFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FactsFt(
      factKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_key'],
      ),
      factValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_value'],
      ),
    );
  }

  @override
  FactsFts createAlias(String alias) {
    return FactsFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(fact_key, fact_value, content=facts, content_rowid=id, prefix=\'2 3\', tokenize=\'unicode61\')';
}

class FactsFt extends DataClass implements Insertable<FactsFt> {
  final String? factKey;
  final String? factValue;
  const FactsFt({this.factKey, this.factValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || factKey != null) {
      map['fact_key'] = Variable<String>(factKey);
    }
    if (!nullToAbsent || factValue != null) {
      map['fact_value'] = Variable<String>(factValue);
    }
    return map;
  }

  FactsFtsCompanion toCompanion(bool nullToAbsent) {
    return FactsFtsCompanion(
      factKey: factKey == null && nullToAbsent
          ? const Value.absent()
          : Value(factKey),
      factValue: factValue == null && nullToAbsent
          ? const Value.absent()
          : Value(factValue),
    );
  }

  factory FactsFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FactsFt(
      factKey: serializer.fromJson<String?>(json['fact_key']),
      factValue: serializer.fromJson<String?>(json['fact_value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fact_key': serializer.toJson<String?>(factKey),
      'fact_value': serializer.toJson<String?>(factValue),
    };
  }

  FactsFt copyWith({
    Value<String?> factKey = const Value.absent(),
    Value<String?> factValue = const Value.absent(),
  }) => FactsFt(
    factKey: factKey.present ? factKey.value : this.factKey,
    factValue: factValue.present ? factValue.value : this.factValue,
  );
  FactsFt copyWithCompanion(FactsFtsCompanion data) {
    return FactsFt(
      factKey: data.factKey.present ? data.factKey.value : this.factKey,
      factValue: data.factValue.present ? data.factValue.value : this.factValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FactsFt(')
          ..write('factKey: $factKey, ')
          ..write('factValue: $factValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(factKey, factValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FactsFt &&
          other.factKey == this.factKey &&
          other.factValue == this.factValue);
}

class FactsFtsCompanion extends UpdateCompanion<FactsFt> {
  final Value<String?> factKey;
  final Value<String?> factValue;
  final Value<int> rowid;
  const FactsFtsCompanion({
    this.factKey = const Value.absent(),
    this.factValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactsFtsCompanion.insert({
    this.factKey = const Value.absent(),
    this.factValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<FactsFt> custom({
    Expression<String>? factKey,
    Expression<String>? factValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (factKey != null) 'fact_key': factKey,
      if (factValue != null) 'fact_value': factValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactsFtsCompanion copyWith({
    Value<String?>? factKey,
    Value<String?>? factValue,
    Value<int>? rowid,
  }) {
    return FactsFtsCompanion(
      factKey: factKey ?? this.factKey,
      factValue: factValue ?? this.factValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (factKey.present) {
      map['fact_key'] = Variable<String>(factKey.value);
    }
    if (factValue.present) {
      map['fact_value'] = Variable<String>(factValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactsFtsCompanion(')
          ..write('factKey: $factKey, ')
          ..write('factValue: $factValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KnowledgeGraphDB extends GeneratedDatabase {
  _$KnowledgeGraphDB(QueryExecutor e) : super(e);
  $KnowledgeGraphDBManager get managers => $KnowledgeGraphDBManager(this);
  late final SummaryNodes summaryNodes = SummaryNodes(this);
  late final Entities entities = Entities(this);
  late final Index idxEntitiesType = Index(
    'idx_entities_type',
    'CREATE INDEX idx_entities_type ON entities (entity_type)',
  );
  late final Index idxEntitiesTemperature = Index(
    'idx_entities_temperature',
    'CREATE INDEX idx_entities_temperature ON entities (temperature)',
  );
  late final Index idxEntitiesValid = Index(
    'idx_entities_valid',
    'CREATE INDEX idx_entities_valid ON entities (valid_at, invalid_at)',
  );
  late final Index idxEntitiesActive = Index(
    'idx_entities_active',
    'CREATE INDEX idx_entities_active ON entities (is_active, temperature)',
  );
  late final Relations relations = Relations(this);
  late final Index idxRelSource = Index(
    'idx_rel_source',
    'CREATE INDEX idx_rel_source ON relations (source_id) WHERE is_active = 1',
  );
  late final Index idxRelTarget = Index(
    'idx_rel_target',
    'CREATE INDEX idx_rel_target ON relations (target_id) WHERE is_active = 1',
  );
  late final Index idxRelPredicate = Index(
    'idx_rel_predicate',
    'CREATE INDEX idx_rel_predicate ON relations (predicate)',
  );
  late final Index idxRelTriplet = Index(
    'idx_rel_triplet',
    'CREATE UNIQUE INDEX idx_rel_triplet ON relations (source_id, predicate, target_id) WHERE is_active = 1 AND expired_at IS NULL',
  );
  late final Facts facts = Facts(this);
  late final Index idxFactsActive = Index(
    'idx_facts_active',
    'CREATE UNIQUE INDEX idx_facts_active ON facts (entity_id, fact_key) WHERE expired_at IS NULL',
  );
  late final Aliases aliases = Aliases(this);
  late final Index idxAliasesUnique = Index(
    'idx_aliases_unique',
    'CREATE UNIQUE INDEX idx_aliases_unique ON aliases (alias_name, entity_id)',
  );
  late final Index idxAliasesName = Index(
    'idx_aliases_name',
    'CREATE INDEX idx_aliases_name ON aliases (alias_name COLLATE NOCASE)',
  );
  late final Index idxAliasesEntity = Index(
    'idx_aliases_entity',
    'CREATE INDEX idx_aliases_entity ON aliases (entity_id)',
  );
  late final Index idxSummaryParent = Index(
    'idx_summary_parent',
    'CREATE INDEX idx_summary_parent ON summary_nodes (parent_id)',
  );
  late final Index idxSummaryLevel = Index(
    'idx_summary_level',
    'CREATE INDEX idx_summary_level ON summary_nodes (level)',
  );
  late final EntitiesFts entitiesFts = EntitiesFts(this);
  late final FactsFts factsFts = FactsFts(this);
  late final Trigger entitiesAi = Trigger(
    'CREATE TRIGGER entities_ai AFTER INSERT ON entities BEGIN INSERT INTO entities_fts ("rowid", name, summary, entity_type) VALUES (new.id, new.name, new.summary, new.entity_type);END',
    'entities_ai',
  );
  late final Trigger entitiesAd = Trigger(
    'CREATE TRIGGER entities_ad AFTER DELETE ON entities BEGIN INSERT INTO entities_fts (entities_fts, "rowid", name, summary, entity_type) VALUES (\'delete\', old.id, old.name, old.summary, old.entity_type);END',
    'entities_ad',
  );
  late final Trigger entitiesAu = Trigger(
    'CREATE TRIGGER entities_au AFTER UPDATE ON entities BEGIN INSERT INTO entities_fts (entities_fts, "rowid", name, summary, entity_type) VALUES (\'delete\', old.id, old.name, old.summary, old.entity_type);INSERT INTO entities_fts ("rowid", name, summary, entity_type) SELECT new.id, new.name, new.summary, new.entity_type WHERE new.is_active = 1;END',
    'entities_au',
  );
  late final Trigger factsAi = Trigger(
    'CREATE TRIGGER facts_ai AFTER INSERT ON facts BEGIN INSERT INTO facts_fts ("rowid", fact_key, fact_value) VALUES (new.id, new.fact_key, new.fact_value);END',
    'facts_ai',
  );
  late final Trigger factsAd = Trigger(
    'CREATE TRIGGER facts_ad AFTER DELETE ON facts BEGIN INSERT INTO facts_fts (facts_fts, "rowid", fact_key, fact_value) VALUES (\'delete\', old.id, old.fact_key, old.fact_value);END',
    'facts_ad',
  );
  late final Trigger factsAu = Trigger(
    'CREATE TRIGGER facts_au AFTER UPDATE ON facts BEGIN INSERT INTO facts_fts (facts_fts, "rowid", fact_key, fact_value) VALUES (\'delete\', old.id, old.fact_key, old.fact_value);INSERT INTO facts_fts ("rowid", fact_key, fact_value) SELECT new.id, new.fact_key, new.fact_value WHERE new.expired_at IS NULL;END',
    'facts_au',
  );
  Selectable<SearchEntitiesResult> searchEntities(String query, int lim) {
    return customSelect(
      'SELECT e.*, bm25(entities_fts, 5.0, 2.0, 1.0) AS rank FROM entities_fts JOIN entities AS e ON e.id = entities_fts."rowid" WHERE entities_fts MATCH ?1 AND e.is_active = 1 ORDER BY rank LIMIT ?2',
      variables: [Variable<String>(query), Variable<int>(lim)],
      readsFrom: {entitiesFts, entities},
    ).map(
      (QueryRow row) => SearchEntitiesResult(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        entityType: row.read<String>('entity_type'),
        summary: row.readNullable<String>('summary'),
        properties: row.read<String>('properties'),
        embedding: row.readNullable<Uint8List>('embedding'),
        embeddingModel: row.readNullable<String>('embedding_model'),
        embeddingDim: row.readNullable<int>('embedding_dim'),
        createdAt: row.read<int>('created_at'),
        validAt: row.readNullable<int>('valid_at'),
        invalidAt: row.readNullable<int>('invalid_at'),
        ingestedAt: row.read<int>('ingested_at'),
        expiredAt: row.readNullable<int>('expired_at'),
        lastAccessed: row.read<int>('last_accessed'),
        accessCount: row.read<int>('access_count'),
        temperature: row.read<String>('temperature'),
        baseScore: row.read<double>('base_score'),
        parentSummaryId: row.readNullable<int>('parent_summary_id'),
        isActive: row.read<int>('is_active'),
        rank: row.read<double>('rank'),
      ),
    );
  }

  Selectable<SearchFactsResult> searchFacts(String query, int lim) {
    return customSelect(
      'SELECT f.*, bm25(facts_fts, 2.0, 5.0) AS rank FROM facts_fts JOIN facts AS f ON f.id = facts_fts."rowid" JOIN entities AS e ON e.id = f.entity_id WHERE facts_fts MATCH ?1 AND f.expired_at IS NULL AND e.is_active = 1 ORDER BY rank LIMIT ?2',
      variables: [Variable<String>(query), Variable<int>(lim)],
      readsFrom: {factsFts, facts, entities},
    ).map(
      (QueryRow row) => SearchFactsResult(
        id: row.read<int>('id'),
        entityId: row.read<int>('entity_id'),
        factKey: row.read<String>('fact_key'),
        factValue: row.read<String>('fact_value'),
        valueType: row.read<String>('value_type'),
        validAt: row.readNullable<int>('valid_at'),
        invalidAt: row.readNullable<int>('invalid_at'),
        ingestedAt: row.read<int>('ingested_at'),
        expiredAt: row.readNullable<int>('expired_at'),
        confidence: row.read<double>('confidence'),
        sourceText: row.readNullable<String>('source_text'),
        rank: row.read<double>('rank'),
      ),
    );
  }

  Selectable<FindNeighborsResult> findNeighbors(int entityId) {
    return customSelect(
      'SELECT e.*, r.predicate, r.weight, r.confidence AS rel_confidence FROM relations AS r JOIN entities AS e ON((r.target_id = e.id AND r.source_id = ?1)OR(r.source_id = e.id AND r.target_id = ?1))WHERE r.is_active = 1 AND r.expired_at IS NULL AND e.is_active = 1 ORDER BY r.weight DESC',
      variables: [Variable<int>(entityId)],
      readsFrom: {relations, entities},
    ).map(
      (QueryRow row) => FindNeighborsResult(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        entityType: row.read<String>('entity_type'),
        summary: row.readNullable<String>('summary'),
        properties: row.read<String>('properties'),
        embedding: row.readNullable<Uint8List>('embedding'),
        embeddingModel: row.readNullable<String>('embedding_model'),
        embeddingDim: row.readNullable<int>('embedding_dim'),
        createdAt: row.read<int>('created_at'),
        validAt: row.readNullable<int>('valid_at'),
        invalidAt: row.readNullable<int>('invalid_at'),
        ingestedAt: row.read<int>('ingested_at'),
        expiredAt: row.readNullable<int>('expired_at'),
        lastAccessed: row.read<int>('last_accessed'),
        accessCount: row.read<int>('access_count'),
        temperature: row.read<String>('temperature'),
        baseScore: row.read<double>('base_score'),
        parentSummaryId: row.readNullable<int>('parent_summary_id'),
        isActive: row.read<int>('is_active'),
        predicate: row.read<String>('predicate'),
        weight: row.read<double>('weight'),
        relConfidence: row.read<double>('rel_confidence'),
      ),
    );
  }

  Selectable<Entity> resolveAlias(String name) {
    return customSelect(
      'SELECT e.* FROM entities AS e JOIN aliases AS a ON a.entity_id = e.id WHERE a.alias_name = ?1 COLLATE NOCASE AND e.is_active = 1 ORDER BY a.confidence DESC LIMIT 1',
      variables: [Variable<String>(name)],
      readsFrom: {entities, aliases},
    ).asyncMap(entities.mapFromRow);
  }

  Selectable<Fact> getEntityFacts(int entityId) {
    return customSelect(
      'SELECT * FROM facts WHERE entity_id = ?1 AND expired_at IS NULL ORDER BY fact_key',
      variables: [Variable<int>(entityId)],
      readsFrom: {facts},
    ).asyncMap(facts.mapFromRow);
  }

  Selectable<GetActiveEntitiesResult> getActiveEntities() {
    return customSelect(
      'SELECT id, base_score, last_accessed, access_count, temperature FROM entities WHERE is_active = 1',
      variables: [],
      readsFrom: {entities},
    ).map(
      (QueryRow row) => GetActiveEntitiesResult(
        id: row.read<int>('id'),
        baseScore: row.read<double>('base_score'),
        lastAccessed: row.read<int>('last_accessed'),
        accessCount: row.read<int>('access_count'),
        temperature: row.read<String>('temperature'),
      ),
    );
  }

  Selectable<Entity> getEntityById(int id) {
    return customSelect(
      'SELECT * FROM entities WHERE id = ?1',
      variables: [Variable<int>(id)],
      readsFrom: {entities},
    ).asyncMap(entities.mapFromRow);
  }

  Selectable<int> countEntities() {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM entities WHERE is_active = 1',
      variables: [],
      readsFrom: {entities},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  Selectable<int> countRelations() {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM relations WHERE is_active = 1 AND expired_at IS NULL',
      variables: [],
      readsFrom: {relations},
    ).map((QueryRow row) => row.read<int>('cnt'));
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    summaryNodes,
    entities,
    idxEntitiesType,
    idxEntitiesTemperature,
    idxEntitiesValid,
    idxEntitiesActive,
    relations,
    idxRelSource,
    idxRelTarget,
    idxRelPredicate,
    idxRelTriplet,
    facts,
    idxFactsActive,
    aliases,
    idxAliasesUnique,
    idxAliasesName,
    idxAliasesEntity,
    idxSummaryParent,
    idxSummaryLevel,
    entitiesFts,
    factsFts,
    entitiesAi,
    entitiesAd,
    entitiesAu,
    factsAi,
    factsAd,
    factsAu,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('relations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('relations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('facts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('aliases', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('entities_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entities_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entities',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('entities_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'facts',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('facts_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'facts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('facts_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'facts',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('facts_fts', kind: UpdateKind.insert)],
    ),
  ]);
}

typedef $SummaryNodesCreateCompanionBuilder =
    SummaryNodesCompanion Function({
      Value<int> id,
      Value<int?> parentId,
      Value<int> level,
      required String summaryText,
      Value<Uint8List?> embedding,
      Value<String?> embeddingModel,
      Value<int?> embeddingDim,
      Value<String> memberIds,
      Value<int?> clusterLabel,
      Value<int> createdAt,
      Value<int> lastUpdated,
    });
typedef $SummaryNodesUpdateCompanionBuilder =
    SummaryNodesCompanion Function({
      Value<int> id,
      Value<int?> parentId,
      Value<int> level,
      Value<String> summaryText,
      Value<Uint8List?> embedding,
      Value<String?> embeddingModel,
      Value<int?> embeddingDim,
      Value<String> memberIds,
      Value<int?> clusterLabel,
      Value<int> createdAt,
      Value<int> lastUpdated,
    });

final class $SummaryNodesReferences
    extends BaseReferences<_$KnowledgeGraphDB, SummaryNodes, SummaryNode> {
  $SummaryNodesReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Entities, List<Entity>> _entitiesRefsTable(
    _$KnowledgeGraphDB db,
  ) => MultiTypedResultKey.fromTable(
    db.entities,
    aliasName: $_aliasNameGenerator(
      db.summaryNodes.id,
      db.entities.parentSummaryId,
    ),
  );

  $EntitiesProcessedTableManager get entitiesRefs {
    final manager = $EntitiesTableManager(
      $_db,
      $_db.entities,
    ).filter((f) => f.parentSummaryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $SummaryNodesFilterComposer
    extends Composer<_$KnowledgeGraphDB, SummaryNodes> {
  $SummaryNodesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberIds => $composableBuilder(
    column: $table.memberIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clusterLabel => $composableBuilder(
    column: $table.clusterLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entitiesRefs(
    Expression<bool> Function($EntitiesFilterComposer f) f,
  ) {
    final $EntitiesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.parentSummaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesFilterComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SummaryNodesOrderingComposer
    extends Composer<_$KnowledgeGraphDB, SummaryNodes> {
  $SummaryNodesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberIds => $composableBuilder(
    column: $table.memberIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clusterLabel => $composableBuilder(
    column: $table.clusterLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SummaryNodesAnnotationComposer
    extends Composer<_$KnowledgeGraphDB, SummaryNodes> {
  $SummaryNodesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memberIds =>
      $composableBuilder(column: $table.memberIds, builder: (column) => column);

  GeneratedColumn<int> get clusterLabel => $composableBuilder(
    column: $table.clusterLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  Expression<T> entitiesRefs<T extends Object>(
    Expression<T> Function($EntitiesAnnotationComposer a) f,
  ) {
    final $EntitiesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.parentSummaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesAnnotationComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SummaryNodesTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          SummaryNodes,
          SummaryNode,
          $SummaryNodesFilterComposer,
          $SummaryNodesOrderingComposer,
          $SummaryNodesAnnotationComposer,
          $SummaryNodesCreateCompanionBuilder,
          $SummaryNodesUpdateCompanionBuilder,
          (SummaryNode, $SummaryNodesReferences),
          SummaryNode,
          PrefetchHooks Function({bool entitiesRefs})
        > {
  $SummaryNodesTableManager(_$KnowledgeGraphDB db, SummaryNodes table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SummaryNodesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SummaryNodesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SummaryNodesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String> summaryText = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String?> embeddingModel = const Value.absent(),
                Value<int?> embeddingDim = const Value.absent(),
                Value<String> memberIds = const Value.absent(),
                Value<int?> clusterLabel = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> lastUpdated = const Value.absent(),
              }) => SummaryNodesCompanion(
                id: id,
                parentId: parentId,
                level: level,
                summaryText: summaryText,
                embedding: embedding,
                embeddingModel: embeddingModel,
                embeddingDim: embeddingDim,
                memberIds: memberIds,
                clusterLabel: clusterLabel,
                createdAt: createdAt,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int> level = const Value.absent(),
                required String summaryText,
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String?> embeddingModel = const Value.absent(),
                Value<int?> embeddingDim = const Value.absent(),
                Value<String> memberIds = const Value.absent(),
                Value<int?> clusterLabel = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> lastUpdated = const Value.absent(),
              }) => SummaryNodesCompanion.insert(
                id: id,
                parentId: parentId,
                level: level,
                summaryText: summaryText,
                embedding: embedding,
                embeddingModel: embeddingModel,
                embeddingDim: embeddingDim,
                memberIds: memberIds,
                clusterLabel: clusterLabel,
                createdAt: createdAt,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $SummaryNodesReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entitiesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entitiesRefs) db.entities],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entitiesRefs)
                    await $_getPrefetchedData<
                      SummaryNode,
                      SummaryNodes,
                      Entity
                    >(
                      currentTable: table,
                      referencedTable: $SummaryNodesReferences
                          ._entitiesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $SummaryNodesReferences(db, table, p0).entitiesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.parentSummaryId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $SummaryNodesProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      SummaryNodes,
      SummaryNode,
      $SummaryNodesFilterComposer,
      $SummaryNodesOrderingComposer,
      $SummaryNodesAnnotationComposer,
      $SummaryNodesCreateCompanionBuilder,
      $SummaryNodesUpdateCompanionBuilder,
      (SummaryNode, $SummaryNodesReferences),
      SummaryNode,
      PrefetchHooks Function({bool entitiesRefs})
    >;
typedef $EntitiesCreateCompanionBuilder =
    EntitiesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> entityType,
      Value<String?> summary,
      Value<String> properties,
      Value<Uint8List?> embedding,
      Value<String?> embeddingModel,
      Value<int?> embeddingDim,
      Value<int> createdAt,
      Value<int?> validAt,
      Value<int?> invalidAt,
      Value<int> ingestedAt,
      Value<int?> expiredAt,
      Value<int> lastAccessed,
      Value<int> accessCount,
      Value<String> temperature,
      Value<double> baseScore,
      Value<int?> parentSummaryId,
      Value<int> isActive,
    });
typedef $EntitiesUpdateCompanionBuilder =
    EntitiesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> entityType,
      Value<String?> summary,
      Value<String> properties,
      Value<Uint8List?> embedding,
      Value<String?> embeddingModel,
      Value<int?> embeddingDim,
      Value<int> createdAt,
      Value<int?> validAt,
      Value<int?> invalidAt,
      Value<int> ingestedAt,
      Value<int?> expiredAt,
      Value<int> lastAccessed,
      Value<int> accessCount,
      Value<String> temperature,
      Value<double> baseScore,
      Value<int?> parentSummaryId,
      Value<int> isActive,
    });

final class $EntitiesReferences
    extends BaseReferences<_$KnowledgeGraphDB, Entities, Entity> {
  $EntitiesReferences(super.$_db, super.$_table, super.$_typedResult);

  static SummaryNodes _parentSummaryIdTable(_$KnowledgeGraphDB db) =>
      db.summaryNodes.createAlias(
        $_aliasNameGenerator(db.entities.parentSummaryId, db.summaryNodes.id),
      );

  $SummaryNodesProcessedTableManager? get parentSummaryId {
    final $_column = $_itemColumn<int>('parent_summary_id');
    if ($_column == null) return null;
    final manager = $SummaryNodesTableManager(
      $_db,
      $_db.summaryNodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentSummaryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<Facts, List<Fact>> _factsRefsTable(
    _$KnowledgeGraphDB db,
  ) => MultiTypedResultKey.fromTable(
    db.facts,
    aliasName: $_aliasNameGenerator(db.entities.id, db.facts.entityId),
  );

  $FactsProcessedTableManager get factsRefs {
    final manager = $FactsTableManager(
      $_db,
      $_db.facts,
    ).filter((f) => f.entityId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_factsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Aliases, List<Aliase>> _aliasesRefsTable(
    _$KnowledgeGraphDB db,
  ) => MultiTypedResultKey.fromTable(
    db.aliases,
    aliasName: $_aliasNameGenerator(db.entities.id, db.aliases.entityId),
  );

  $AliasesProcessedTableManager get aliasesRefs {
    final manager = $AliasesTableManager(
      $_db,
      $_db.aliases,
    ).filter((f) => f.entityId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_aliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $EntitiesFilterComposer extends Composer<_$KnowledgeGraphDB, Entities> {
  $EntitiesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get validAt => $composableBuilder(
    column: $table.validAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get invalidAt => $composableBuilder(
    column: $table.invalidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiredAt => $composableBuilder(
    column: $table.expiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseScore => $composableBuilder(
    column: $table.baseScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $SummaryNodesFilterComposer get parentSummaryId {
    final $SummaryNodesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSummaryId,
      referencedTable: $db.summaryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SummaryNodesFilterComposer(
            $db: $db,
            $table: $db.summaryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> factsRefs(
    Expression<bool> Function($FactsFilterComposer f) f,
  ) {
    final $FactsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.entityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $FactsFilterComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> aliasesRefs(
    Expression<bool> Function($AliasesFilterComposer f) f,
  ) {
    final $AliasesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.entityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AliasesFilterComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $EntitiesOrderingComposer extends Composer<_$KnowledgeGraphDB, Entities> {
  $EntitiesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get validAt => $composableBuilder(
    column: $table.validAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get invalidAt => $composableBuilder(
    column: $table.invalidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiredAt => $composableBuilder(
    column: $table.expiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseScore => $composableBuilder(
    column: $table.baseScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $SummaryNodesOrderingComposer get parentSummaryId {
    final $SummaryNodesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSummaryId,
      referencedTable: $db.summaryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SummaryNodesOrderingComposer(
            $db: $db,
            $table: $db.summaryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $EntitiesAnnotationComposer
    extends Composer<_$KnowledgeGraphDB, Entities> {
  $EntitiesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get validAt =>
      $composableBuilder(column: $table.validAt, builder: (column) => column);

  GeneratedColumn<int> get invalidAt =>
      $composableBuilder(column: $table.invalidAt, builder: (column) => column);

  GeneratedColumn<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiredAt =>
      $composableBuilder(column: $table.expiredAt, builder: (column) => column);

  GeneratedColumn<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseScore =>
      $composableBuilder(column: $table.baseScore, builder: (column) => column);

  GeneratedColumn<int> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $SummaryNodesAnnotationComposer get parentSummaryId {
    final $SummaryNodesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSummaryId,
      referencedTable: $db.summaryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SummaryNodesAnnotationComposer(
            $db: $db,
            $table: $db.summaryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> factsRefs<T extends Object>(
    Expression<T> Function($FactsAnnotationComposer a) f,
  ) {
    final $FactsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.entityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $FactsAnnotationComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> aliasesRefs<T extends Object>(
    Expression<T> Function($AliasesAnnotationComposer a) f,
  ) {
    final $AliasesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.entityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AliasesAnnotationComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $EntitiesTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          Entities,
          Entity,
          $EntitiesFilterComposer,
          $EntitiesOrderingComposer,
          $EntitiesAnnotationComposer,
          $EntitiesCreateCompanionBuilder,
          $EntitiesUpdateCompanionBuilder,
          (Entity, $EntitiesReferences),
          Entity,
          PrefetchHooks Function({
            bool parentSummaryId,
            bool factsRefs,
            bool aliasesRefs,
          })
        > {
  $EntitiesTableManager(_$KnowledgeGraphDB db, Entities table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EntitiesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EntitiesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EntitiesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> properties = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String?> embeddingModel = const Value.absent(),
                Value<int?> embeddingDim = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> validAt = const Value.absent(),
                Value<int?> invalidAt = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> expiredAt = const Value.absent(),
                Value<int> lastAccessed = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<String> temperature = const Value.absent(),
                Value<double> baseScore = const Value.absent(),
                Value<int?> parentSummaryId = const Value.absent(),
                Value<int> isActive = const Value.absent(),
              }) => EntitiesCompanion(
                id: id,
                name: name,
                entityType: entityType,
                summary: summary,
                properties: properties,
                embedding: embedding,
                embeddingModel: embeddingModel,
                embeddingDim: embeddingDim,
                createdAt: createdAt,
                validAt: validAt,
                invalidAt: invalidAt,
                ingestedAt: ingestedAt,
                expiredAt: expiredAt,
                lastAccessed: lastAccessed,
                accessCount: accessCount,
                temperature: temperature,
                baseScore: baseScore,
                parentSummaryId: parentSummaryId,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> entityType = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> properties = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String?> embeddingModel = const Value.absent(),
                Value<int?> embeddingDim = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> validAt = const Value.absent(),
                Value<int?> invalidAt = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> expiredAt = const Value.absent(),
                Value<int> lastAccessed = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<String> temperature = const Value.absent(),
                Value<double> baseScore = const Value.absent(),
                Value<int?> parentSummaryId = const Value.absent(),
                Value<int> isActive = const Value.absent(),
              }) => EntitiesCompanion.insert(
                id: id,
                name: name,
                entityType: entityType,
                summary: summary,
                properties: properties,
                embedding: embedding,
                embeddingModel: embeddingModel,
                embeddingDim: embeddingDim,
                createdAt: createdAt,
                validAt: validAt,
                invalidAt: invalidAt,
                ingestedAt: ingestedAt,
                expiredAt: expiredAt,
                lastAccessed: lastAccessed,
                accessCount: accessCount,
                temperature: temperature,
                baseScore: baseScore,
                parentSummaryId: parentSummaryId,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable(table), $EntitiesReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parentSummaryId = false,
                factsRefs = false,
                aliasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (factsRefs) db.facts,
                    if (aliasesRefs) db.aliases,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentSummaryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentSummaryId,
                                    referencedTable: $EntitiesReferences
                                        ._parentSummaryIdTable(db),
                                    referencedColumn: $EntitiesReferences
                                        ._parentSummaryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (factsRefs)
                        await $_getPrefetchedData<Entity, Entities, Fact>(
                          currentTable: table,
                          referencedTable: $EntitiesReferences._factsRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $EntitiesReferences(db, table, p0).factsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entityId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (aliasesRefs)
                        await $_getPrefetchedData<Entity, Entities, Aliase>(
                          currentTable: table,
                          referencedTable: $EntitiesReferences
                              ._aliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $EntitiesReferences(db, table, p0).aliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entityId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $EntitiesProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      Entities,
      Entity,
      $EntitiesFilterComposer,
      $EntitiesOrderingComposer,
      $EntitiesAnnotationComposer,
      $EntitiesCreateCompanionBuilder,
      $EntitiesUpdateCompanionBuilder,
      (Entity, $EntitiesReferences),
      Entity,
      PrefetchHooks Function({
        bool parentSummaryId,
        bool factsRefs,
        bool aliasesRefs,
      })
    >;
typedef $RelationsCreateCompanionBuilder =
    RelationsCompanion Function({
      Value<int> id,
      required int sourceId,
      required int targetId,
      required String predicate,
      Value<double> weight,
      Value<String> properties,
      Value<Uint8List?> embedding,
      Value<String?> embeddingModel,
      Value<int?> embeddingDim,
      Value<int> createdAt,
      Value<int?> validAt,
      Value<int?> invalidAt,
      Value<int> ingestedAt,
      Value<int?> expiredAt,
      Value<int> lastAccessed,
      Value<int> accessCount,
      Value<double> confidence,
      Value<String?> sourceText,
      Value<int> isActive,
    });
typedef $RelationsUpdateCompanionBuilder =
    RelationsCompanion Function({
      Value<int> id,
      Value<int> sourceId,
      Value<int> targetId,
      Value<String> predicate,
      Value<double> weight,
      Value<String> properties,
      Value<Uint8List?> embedding,
      Value<String?> embeddingModel,
      Value<int?> embeddingDim,
      Value<int> createdAt,
      Value<int?> validAt,
      Value<int?> invalidAt,
      Value<int> ingestedAt,
      Value<int?> expiredAt,
      Value<int> lastAccessed,
      Value<int> accessCount,
      Value<double> confidence,
      Value<String?> sourceText,
      Value<int> isActive,
    });

final class $RelationsReferences
    extends BaseReferences<_$KnowledgeGraphDB, Relations, Relation> {
  $RelationsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Entities _sourceIdTable(_$KnowledgeGraphDB db) => db.entities
      .createAlias($_aliasNameGenerator(db.relations.sourceId, db.entities.id));

  $EntitiesProcessedTableManager get sourceId {
    final $_column = $_itemColumn<int>('source_id')!;

    final manager = $EntitiesTableManager(
      $_db,
      $_db.entities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Entities _targetIdTable(_$KnowledgeGraphDB db) => db.entities
      .createAlias($_aliasNameGenerator(db.relations.targetId, db.entities.id));

  $EntitiesProcessedTableManager get targetId {
    final $_column = $_itemColumn<int>('target_id')!;

    final manager = $EntitiesTableManager(
      $_db,
      $_db.entities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $RelationsFilterComposer extends Composer<_$KnowledgeGraphDB, Relations> {
  $RelationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get validAt => $composableBuilder(
    column: $table.validAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get invalidAt => $composableBuilder(
    column: $table.invalidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiredAt => $composableBuilder(
    column: $table.expiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $EntitiesFilterComposer get sourceId {
    final $EntitiesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesFilterComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $EntitiesFilterComposer get targetId {
    final $EntitiesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesFilterComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RelationsOrderingComposer
    extends Composer<_$KnowledgeGraphDB, Relations> {
  $RelationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get validAt => $composableBuilder(
    column: $table.validAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get invalidAt => $composableBuilder(
    column: $table.invalidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiredAt => $composableBuilder(
    column: $table.expiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $EntitiesOrderingComposer get sourceId {
    final $EntitiesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesOrderingComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $EntitiesOrderingComposer get targetId {
    final $EntitiesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesOrderingComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RelationsAnnotationComposer
    extends Composer<_$KnowledgeGraphDB, Relations> {
  $RelationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get predicate =>
      $composableBuilder(column: $table.predicate, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get embeddingDim => $composableBuilder(
    column: $table.embeddingDim,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get validAt =>
      $composableBuilder(column: $table.validAt, builder: (column) => column);

  GeneratedColumn<int> get invalidAt =>
      $composableBuilder(column: $table.invalidAt, builder: (column) => column);

  GeneratedColumn<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiredAt =>
      $composableBuilder(column: $table.expiredAt, builder: (column) => column);

  GeneratedColumn<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $EntitiesAnnotationComposer get sourceId {
    final $EntitiesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesAnnotationComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $EntitiesAnnotationComposer get targetId {
    final $EntitiesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesAnnotationComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RelationsTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          Relations,
          Relation,
          $RelationsFilterComposer,
          $RelationsOrderingComposer,
          $RelationsAnnotationComposer,
          $RelationsCreateCompanionBuilder,
          $RelationsUpdateCompanionBuilder,
          (Relation, $RelationsReferences),
          Relation,
          PrefetchHooks Function({bool sourceId, bool targetId})
        > {
  $RelationsTableManager(_$KnowledgeGraphDB db, Relations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RelationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RelationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RelationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sourceId = const Value.absent(),
                Value<int> targetId = const Value.absent(),
                Value<String> predicate = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<String> properties = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String?> embeddingModel = const Value.absent(),
                Value<int?> embeddingDim = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> validAt = const Value.absent(),
                Value<int?> invalidAt = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> expiredAt = const Value.absent(),
                Value<int> lastAccessed = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<int> isActive = const Value.absent(),
              }) => RelationsCompanion(
                id: id,
                sourceId: sourceId,
                targetId: targetId,
                predicate: predicate,
                weight: weight,
                properties: properties,
                embedding: embedding,
                embeddingModel: embeddingModel,
                embeddingDim: embeddingDim,
                createdAt: createdAt,
                validAt: validAt,
                invalidAt: invalidAt,
                ingestedAt: ingestedAt,
                expiredAt: expiredAt,
                lastAccessed: lastAccessed,
                accessCount: accessCount,
                confidence: confidence,
                sourceText: sourceText,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sourceId,
                required int targetId,
                required String predicate,
                Value<double> weight = const Value.absent(),
                Value<String> properties = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String?> embeddingModel = const Value.absent(),
                Value<int?> embeddingDim = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> validAt = const Value.absent(),
                Value<int?> invalidAt = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> expiredAt = const Value.absent(),
                Value<int> lastAccessed = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<int> isActive = const Value.absent(),
              }) => RelationsCompanion.insert(
                id: id,
                sourceId: sourceId,
                targetId: targetId,
                predicate: predicate,
                weight: weight,
                properties: properties,
                embedding: embedding,
                embeddingModel: embeddingModel,
                embeddingDim: embeddingDim,
                createdAt: createdAt,
                validAt: validAt,
                invalidAt: invalidAt,
                ingestedAt: ingestedAt,
                expiredAt: expiredAt,
                lastAccessed: lastAccessed,
                accessCount: accessCount,
                confidence: confidence,
                sourceText: sourceText,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable(table), $RelationsReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false, targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $RelationsReferences
                                    ._sourceIdTable(db),
                                referencedColumn: $RelationsReferences
                                    ._sourceIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (targetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.targetId,
                                referencedTable: $RelationsReferences
                                    ._targetIdTable(db),
                                referencedColumn: $RelationsReferences
                                    ._targetIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $RelationsProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      Relations,
      Relation,
      $RelationsFilterComposer,
      $RelationsOrderingComposer,
      $RelationsAnnotationComposer,
      $RelationsCreateCompanionBuilder,
      $RelationsUpdateCompanionBuilder,
      (Relation, $RelationsReferences),
      Relation,
      PrefetchHooks Function({bool sourceId, bool targetId})
    >;
typedef $FactsCreateCompanionBuilder =
    FactsCompanion Function({
      Value<int> id,
      required int entityId,
      required String factKey,
      required String factValue,
      Value<String> valueType,
      Value<int?> validAt,
      Value<int?> invalidAt,
      Value<int> ingestedAt,
      Value<int?> expiredAt,
      Value<double> confidence,
      Value<String?> sourceText,
    });
typedef $FactsUpdateCompanionBuilder =
    FactsCompanion Function({
      Value<int> id,
      Value<int> entityId,
      Value<String> factKey,
      Value<String> factValue,
      Value<String> valueType,
      Value<int?> validAt,
      Value<int?> invalidAt,
      Value<int> ingestedAt,
      Value<int?> expiredAt,
      Value<double> confidence,
      Value<String?> sourceText,
    });

final class $FactsReferences
    extends BaseReferences<_$KnowledgeGraphDB, Facts, Fact> {
  $FactsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Entities _entityIdTable(_$KnowledgeGraphDB db) => db.entities
      .createAlias($_aliasNameGenerator(db.facts.entityId, db.entities.id));

  $EntitiesProcessedTableManager get entityId {
    final $_column = $_itemColumn<int>('entity_id')!;

    final manager = $EntitiesTableManager(
      $_db,
      $_db.entities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $FactsFilterComposer extends Composer<_$KnowledgeGraphDB, Facts> {
  $FactsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factKey => $composableBuilder(
    column: $table.factKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factValue => $composableBuilder(
    column: $table.factValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get validAt => $composableBuilder(
    column: $table.validAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get invalidAt => $composableBuilder(
    column: $table.invalidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiredAt => $composableBuilder(
    column: $table.expiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  $EntitiesFilterComposer get entityId {
    final $EntitiesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entityId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesFilterComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $FactsOrderingComposer extends Composer<_$KnowledgeGraphDB, Facts> {
  $FactsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factKey => $composableBuilder(
    column: $table.factKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factValue => $composableBuilder(
    column: $table.factValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get validAt => $composableBuilder(
    column: $table.validAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get invalidAt => $composableBuilder(
    column: $table.invalidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiredAt => $composableBuilder(
    column: $table.expiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  $EntitiesOrderingComposer get entityId {
    final $EntitiesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entityId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesOrderingComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $FactsAnnotationComposer extends Composer<_$KnowledgeGraphDB, Facts> {
  $FactsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get factKey =>
      $composableBuilder(column: $table.factKey, builder: (column) => column);

  GeneratedColumn<String> get factValue =>
      $composableBuilder(column: $table.factValue, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<int> get validAt =>
      $composableBuilder(column: $table.validAt, builder: (column) => column);

  GeneratedColumn<int> get invalidAt =>
      $composableBuilder(column: $table.invalidAt, builder: (column) => column);

  GeneratedColumn<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiredAt =>
      $composableBuilder(column: $table.expiredAt, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  $EntitiesAnnotationComposer get entityId {
    final $EntitiesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entityId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesAnnotationComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $FactsTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          Facts,
          Fact,
          $FactsFilterComposer,
          $FactsOrderingComposer,
          $FactsAnnotationComposer,
          $FactsCreateCompanionBuilder,
          $FactsUpdateCompanionBuilder,
          (Fact, $FactsReferences),
          Fact,
          PrefetchHooks Function({bool entityId})
        > {
  $FactsTableManager(_$KnowledgeGraphDB db, Facts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $FactsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $FactsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $FactsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> entityId = const Value.absent(),
                Value<String> factKey = const Value.absent(),
                Value<String> factValue = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<int?> validAt = const Value.absent(),
                Value<int?> invalidAt = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> expiredAt = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
              }) => FactsCompanion(
                id: id,
                entityId: entityId,
                factKey: factKey,
                factValue: factValue,
                valueType: valueType,
                validAt: validAt,
                invalidAt: invalidAt,
                ingestedAt: ingestedAt,
                expiredAt: expiredAt,
                confidence: confidence,
                sourceText: sourceText,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int entityId,
                required String factKey,
                required String factValue,
                Value<String> valueType = const Value.absent(),
                Value<int?> validAt = const Value.absent(),
                Value<int?> invalidAt = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> expiredAt = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
              }) => FactsCompanion.insert(
                id: id,
                entityId: entityId,
                factKey: factKey,
                factValue: factValue,
                valueType: valueType,
                validAt: validAt,
                invalidAt: invalidAt,
                ingestedAt: ingestedAt,
                expiredAt: expiredAt,
                confidence: confidence,
                sourceText: sourceText,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), $FactsReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({entityId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entityId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entityId,
                                referencedTable: $FactsReferences
                                    ._entityIdTable(db),
                                referencedColumn: $FactsReferences
                                    ._entityIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $FactsProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      Facts,
      Fact,
      $FactsFilterComposer,
      $FactsOrderingComposer,
      $FactsAnnotationComposer,
      $FactsCreateCompanionBuilder,
      $FactsUpdateCompanionBuilder,
      (Fact, $FactsReferences),
      Fact,
      PrefetchHooks Function({bool entityId})
    >;
typedef $AliasesCreateCompanionBuilder =
    AliasesCompanion Function({
      Value<int> id,
      required int entityId,
      required String aliasName,
      Value<String> aliasType,
      Value<double> confidence,
    });
typedef $AliasesUpdateCompanionBuilder =
    AliasesCompanion Function({
      Value<int> id,
      Value<int> entityId,
      Value<String> aliasName,
      Value<String> aliasType,
      Value<double> confidence,
    });

final class $AliasesReferences
    extends BaseReferences<_$KnowledgeGraphDB, Aliases, Aliase> {
  $AliasesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Entities _entityIdTable(_$KnowledgeGraphDB db) => db.entities
      .createAlias($_aliasNameGenerator(db.aliases.entityId, db.entities.id));

  $EntitiesProcessedTableManager get entityId {
    final $_column = $_itemColumn<int>('entity_id')!;

    final manager = $EntitiesTableManager(
      $_db,
      $_db.entities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $AliasesFilterComposer extends Composer<_$KnowledgeGraphDB, Aliases> {
  $AliasesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasName => $composableBuilder(
    column: $table.aliasName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasType => $composableBuilder(
    column: $table.aliasType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $EntitiesFilterComposer get entityId {
    final $EntitiesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entityId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesFilterComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AliasesOrderingComposer extends Composer<_$KnowledgeGraphDB, Aliases> {
  $AliasesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasName => $composableBuilder(
    column: $table.aliasName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasType => $composableBuilder(
    column: $table.aliasType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $EntitiesOrderingComposer get entityId {
    final $EntitiesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entityId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesOrderingComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AliasesAnnotationComposer extends Composer<_$KnowledgeGraphDB, Aliases> {
  $AliasesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get aliasName =>
      $composableBuilder(column: $table.aliasName, builder: (column) => column);

  GeneratedColumn<String> get aliasType =>
      $composableBuilder(column: $table.aliasType, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $EntitiesAnnotationComposer get entityId {
    final $EntitiesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entityId,
      referencedTable: $db.entities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EntitiesAnnotationComposer(
            $db: $db,
            $table: $db.entities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AliasesTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          Aliases,
          Aliase,
          $AliasesFilterComposer,
          $AliasesOrderingComposer,
          $AliasesAnnotationComposer,
          $AliasesCreateCompanionBuilder,
          $AliasesUpdateCompanionBuilder,
          (Aliase, $AliasesReferences),
          Aliase,
          PrefetchHooks Function({bool entityId})
        > {
  $AliasesTableManager(_$KnowledgeGraphDB db, Aliases table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AliasesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AliasesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AliasesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> entityId = const Value.absent(),
                Value<String> aliasName = const Value.absent(),
                Value<String> aliasType = const Value.absent(),
                Value<double> confidence = const Value.absent(),
              }) => AliasesCompanion(
                id: id,
                entityId: entityId,
                aliasName: aliasName,
                aliasType: aliasType,
                confidence: confidence,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int entityId,
                required String aliasName,
                Value<String> aliasType = const Value.absent(),
                Value<double> confidence = const Value.absent(),
              }) => AliasesCompanion.insert(
                id: id,
                entityId: entityId,
                aliasName: aliasName,
                aliasType: aliasType,
                confidence: confidence,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable(table), $AliasesReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entityId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entityId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entityId,
                                referencedTable: $AliasesReferences
                                    ._entityIdTable(db),
                                referencedColumn: $AliasesReferences
                                    ._entityIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $AliasesProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      Aliases,
      Aliase,
      $AliasesFilterComposer,
      $AliasesOrderingComposer,
      $AliasesAnnotationComposer,
      $AliasesCreateCompanionBuilder,
      $AliasesUpdateCompanionBuilder,
      (Aliase, $AliasesReferences),
      Aliase,
      PrefetchHooks Function({bool entityId})
    >;
typedef $EntitiesFtsCreateCompanionBuilder =
    EntitiesFtsCompanion Function({
      Value<String?> name,
      Value<String?> summary,
      Value<String?> entityType,
      Value<int> rowid,
    });
typedef $EntitiesFtsUpdateCompanionBuilder =
    EntitiesFtsCompanion Function({
      Value<String?> name,
      Value<String?> summary,
      Value<String?> entityType,
      Value<int> rowid,
    });

class $EntitiesFtsFilterComposer
    extends Composer<_$KnowledgeGraphDB, EntitiesFts> {
  $EntitiesFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );
}

class $EntitiesFtsOrderingComposer
    extends Composer<_$KnowledgeGraphDB, EntitiesFts> {
  $EntitiesFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $EntitiesFtsAnnotationComposer
    extends Composer<_$KnowledgeGraphDB, EntitiesFts> {
  $EntitiesFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );
}

class $EntitiesFtsTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          EntitiesFts,
          EntitiesFt,
          $EntitiesFtsFilterComposer,
          $EntitiesFtsOrderingComposer,
          $EntitiesFtsAnnotationComposer,
          $EntitiesFtsCreateCompanionBuilder,
          $EntitiesFtsUpdateCompanionBuilder,
          (
            EntitiesFt,
            BaseReferences<_$KnowledgeGraphDB, EntitiesFts, EntitiesFt>,
          ),
          EntitiesFt,
          PrefetchHooks Function()
        > {
  $EntitiesFtsTableManager(_$KnowledgeGraphDB db, EntitiesFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EntitiesFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EntitiesFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EntitiesFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> name = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> entityType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntitiesFtsCompanion(
                name: name,
                summary: summary,
                entityType: entityType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> name = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> entityType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntitiesFtsCompanion.insert(
                name: name,
                summary: summary,
                entityType: entityType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $EntitiesFtsProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      EntitiesFts,
      EntitiesFt,
      $EntitiesFtsFilterComposer,
      $EntitiesFtsOrderingComposer,
      $EntitiesFtsAnnotationComposer,
      $EntitiesFtsCreateCompanionBuilder,
      $EntitiesFtsUpdateCompanionBuilder,
      (EntitiesFt, BaseReferences<_$KnowledgeGraphDB, EntitiesFts, EntitiesFt>),
      EntitiesFt,
      PrefetchHooks Function()
    >;
typedef $FactsFtsCreateCompanionBuilder =
    FactsFtsCompanion Function({
      Value<String?> factKey,
      Value<String?> factValue,
      Value<int> rowid,
    });
typedef $FactsFtsUpdateCompanionBuilder =
    FactsFtsCompanion Function({
      Value<String?> factKey,
      Value<String?> factValue,
      Value<int> rowid,
    });

class $FactsFtsFilterComposer extends Composer<_$KnowledgeGraphDB, FactsFts> {
  $FactsFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get factKey => $composableBuilder(
    column: $table.factKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factValue => $composableBuilder(
    column: $table.factValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $FactsFtsOrderingComposer extends Composer<_$KnowledgeGraphDB, FactsFts> {
  $FactsFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get factKey => $composableBuilder(
    column: $table.factKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factValue => $composableBuilder(
    column: $table.factValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $FactsFtsAnnotationComposer
    extends Composer<_$KnowledgeGraphDB, FactsFts> {
  $FactsFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get factKey =>
      $composableBuilder(column: $table.factKey, builder: (column) => column);

  GeneratedColumn<String> get factValue =>
      $composableBuilder(column: $table.factValue, builder: (column) => column);
}

class $FactsFtsTableManager
    extends
        RootTableManager<
          _$KnowledgeGraphDB,
          FactsFts,
          FactsFt,
          $FactsFtsFilterComposer,
          $FactsFtsOrderingComposer,
          $FactsFtsAnnotationComposer,
          $FactsFtsCreateCompanionBuilder,
          $FactsFtsUpdateCompanionBuilder,
          (FactsFt, BaseReferences<_$KnowledgeGraphDB, FactsFts, FactsFt>),
          FactsFt,
          PrefetchHooks Function()
        > {
  $FactsFtsTableManager(_$KnowledgeGraphDB db, FactsFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $FactsFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $FactsFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $FactsFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> factKey = const Value.absent(),
                Value<String?> factValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactsFtsCompanion(
                factKey: factKey,
                factValue: factValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> factKey = const Value.absent(),
                Value<String?> factValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactsFtsCompanion.insert(
                factKey: factKey,
                factValue: factValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $FactsFtsProcessedTableManager =
    ProcessedTableManager<
      _$KnowledgeGraphDB,
      FactsFts,
      FactsFt,
      $FactsFtsFilterComposer,
      $FactsFtsOrderingComposer,
      $FactsFtsAnnotationComposer,
      $FactsFtsCreateCompanionBuilder,
      $FactsFtsUpdateCompanionBuilder,
      (FactsFt, BaseReferences<_$KnowledgeGraphDB, FactsFts, FactsFt>),
      FactsFt,
      PrefetchHooks Function()
    >;

class $KnowledgeGraphDBManager {
  final _$KnowledgeGraphDB _db;
  $KnowledgeGraphDBManager(this._db);
  $SummaryNodesTableManager get summaryNodes =>
      $SummaryNodesTableManager(_db, _db.summaryNodes);
  $EntitiesTableManager get entities =>
      $EntitiesTableManager(_db, _db.entities);
  $RelationsTableManager get relations =>
      $RelationsTableManager(_db, _db.relations);
  $FactsTableManager get facts => $FactsTableManager(_db, _db.facts);
  $AliasesTableManager get aliases => $AliasesTableManager(_db, _db.aliases);
  $EntitiesFtsTableManager get entitiesFts =>
      $EntitiesFtsTableManager(_db, _db.entitiesFts);
  $FactsFtsTableManager get factsFts =>
      $FactsFtsTableManager(_db, _db.factsFts);
}

class SearchEntitiesResult {
  final int id;
  final String name;
  final String entityType;
  final String? summary;
  final String properties;
  final Uint8List? embedding;
  final String? embeddingModel;
  final int? embeddingDim;
  final int createdAt;
  final int? validAt;
  final int? invalidAt;
  final int ingestedAt;
  final int? expiredAt;
  final int lastAccessed;
  final int accessCount;
  final String temperature;
  final double baseScore;
  final int? parentSummaryId;
  final int isActive;
  final double rank;
  SearchEntitiesResult({
    required this.id,
    required this.name,
    required this.entityType,
    this.summary,
    required this.properties,
    this.embedding,
    this.embeddingModel,
    this.embeddingDim,
    required this.createdAt,
    this.validAt,
    this.invalidAt,
    required this.ingestedAt,
    this.expiredAt,
    required this.lastAccessed,
    required this.accessCount,
    required this.temperature,
    required this.baseScore,
    this.parentSummaryId,
    required this.isActive,
    required this.rank,
  });
}

class SearchFactsResult {
  final int id;
  final int entityId;
  final String factKey;
  final String factValue;
  final String valueType;
  final int? validAt;
  final int? invalidAt;
  final int ingestedAt;
  final int? expiredAt;
  final double confidence;
  final String? sourceText;
  final double rank;
  SearchFactsResult({
    required this.id,
    required this.entityId,
    required this.factKey,
    required this.factValue,
    required this.valueType,
    this.validAt,
    this.invalidAt,
    required this.ingestedAt,
    this.expiredAt,
    required this.confidence,
    this.sourceText,
    required this.rank,
  });
}

class FindNeighborsResult {
  final int id;
  final String name;
  final String entityType;
  final String? summary;
  final String properties;
  final Uint8List? embedding;
  final String? embeddingModel;
  final int? embeddingDim;
  final int createdAt;
  final int? validAt;
  final int? invalidAt;
  final int ingestedAt;
  final int? expiredAt;
  final int lastAccessed;
  final int accessCount;
  final String temperature;
  final double baseScore;
  final int? parentSummaryId;
  final int isActive;
  final String predicate;
  final double weight;
  final double relConfidence;
  FindNeighborsResult({
    required this.id,
    required this.name,
    required this.entityType,
    this.summary,
    required this.properties,
    this.embedding,
    this.embeddingModel,
    this.embeddingDim,
    required this.createdAt,
    this.validAt,
    this.invalidAt,
    required this.ingestedAt,
    this.expiredAt,
    required this.lastAccessed,
    required this.accessCount,
    required this.temperature,
    required this.baseScore,
    this.parentSummaryId,
    required this.isActive,
    required this.predicate,
    required this.weight,
    required this.relConfidence,
  });
}

class GetActiveEntitiesResult {
  final int id;
  final double baseScore;
  final int lastAccessed;
  final int accessCount;
  final String temperature;
  GetActiveEntitiesResult({
    required this.id,
    required this.baseScore,
    required this.lastAccessed,
    required this.accessCount,
    required this.temperature,
  });
}
