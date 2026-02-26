/// Entity types for Knowledge Graph nodes.
enum EntityType {
  person,
  place,
  organization,
  event,
  concept,
  date;

  String get label => name.toUpperCase();

  static EntityType fromString(String value) {
    return EntityType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => EntityType.concept,
    );
  }
}

/// Temperature classification for memory decay.
enum Temperature {
  hot,
  warm,
  cool,
  cold;

  static Temperature fromString(String value) {
    return Temperature.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Temperature.warm,
    );
  }
}

/// A Knowledge Graph entity (node).
class KnowledgeEntity {
  final int? id;
  final String name;
  final EntityType entityType;
  final String? summary;
  final Map<String, dynamic> properties;
  final List<double>? embedding;

  // Bi-temporal
  final int? createdAt;
  final int? validAt;
  final int? invalidAt;
  final int? ingestedAt;
  final int? expiredAt;

  // Activation & decay
  final int? lastAccessed;
  final int accessCount;
  final Temperature temperature;
  final double baseScore;

  // RAPTOR hierarchy
  final int? parentSummaryId;
  final bool isActive;

  const KnowledgeEntity({
    this.id,
    required this.name,
    this.entityType = EntityType.concept,
    this.summary,
    this.properties = const {},
    this.embedding,
    this.createdAt,
    this.validAt,
    this.invalidAt,
    this.ingestedAt,
    this.expiredAt,
    this.lastAccessed,
    this.accessCount = 1,
    this.temperature = Temperature.warm,
    this.baseScore = 0.5,
    this.parentSummaryId,
    this.isActive = true,
  });

  factory KnowledgeEntity.fromJson(Map<String, dynamic> json) =>
      KnowledgeEntity(
        id: json['id'] as int?,
        name: json['name'] as String,
        entityType: EntityType.fromString(
            json['entity_type'] as String? ?? 'CONCEPT'),
        summary: json['summary'] as String?,
        properties: json['properties'] is Map
            ? Map<String, dynamic>.from(json['properties'] as Map)
            : const {},
        createdAt: json['created_at'] as int?,
        validAt: json['valid_at'] as int?,
        invalidAt: json['invalid_at'] as int?,
        ingestedAt: json['ingested_at'] as int?,
        expiredAt: json['expired_at'] as int?,
        lastAccessed: json['last_accessed'] as int?,
        accessCount: json['access_count'] as int? ?? 1,
        temperature:
            Temperature.fromString(json['temperature'] as String? ?? 'warm'),
        baseScore: (json['base_score'] as num?)?.toDouble() ?? 0.5,
        parentSummaryId: json['parent_summary_id'] as int?,
        isActive: (json['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'entity_type': entityType.label,
        'summary': summary,
        'properties': properties,
        'created_at': createdAt,
        'valid_at': validAt,
        'invalid_at': invalidAt,
        'ingested_at': ingestedAt,
        'expired_at': expiredAt,
        'last_accessed': lastAccessed,
        'access_count': accessCount,
        'temperature': temperature.name,
        'base_score': baseScore,
        'parent_summary_id': parentSummaryId,
        'is_active': isActive ? 1 : 0,
      };

  KnowledgeEntity copyWith({
    int? id,
    String? name,
    EntityType? entityType,
    String? summary,
    Map<String, dynamic>? properties,
    List<double>? embedding,
    int? lastAccessed,
    int? accessCount,
    Temperature? temperature,
    double? baseScore,
    int? parentSummaryId,
    bool? isActive,
  }) =>
      KnowledgeEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        entityType: entityType ?? this.entityType,
        summary: summary ?? this.summary,
        properties: properties ?? this.properties,
        embedding: embedding ?? this.embedding,
        createdAt: createdAt,
        validAt: validAt,
        invalidAt: invalidAt,
        ingestedAt: ingestedAt,
        expiredAt: expiredAt,
        lastAccessed: lastAccessed ?? this.lastAccessed,
        accessCount: accessCount ?? this.accessCount,
        temperature: temperature ?? this.temperature,
        baseScore: baseScore ?? this.baseScore,
        parentSummaryId: parentSummaryId ?? this.parentSummaryId,
        isActive: isActive ?? this.isActive,
      );
}

/// A Knowledge Graph relation (edge / triplet).
class KnowledgeRelation {
  final int? id;
  final int sourceId;
  final int targetId;
  final String predicate;
  final double weight;
  final Map<String, dynamic> properties;
  final List<double>? embedding;

  // Bi-temporal
  final int? createdAt;
  final int? validAt;
  final int? invalidAt;
  final int? ingestedAt;
  final int? expiredAt;

  // Activation
  final int? lastAccessed;
  final int accessCount;
  final double confidence;
  final String? sourceText;
  final bool isActive;

  const KnowledgeRelation({
    this.id,
    required this.sourceId,
    required this.targetId,
    required this.predicate,
    this.weight = 1.0,
    this.properties = const {},
    this.embedding,
    this.createdAt,
    this.validAt,
    this.invalidAt,
    this.ingestedAt,
    this.expiredAt,
    this.lastAccessed,
    this.accessCount = 1,
    this.confidence = 1.0,
    this.sourceText,
    this.isActive = true,
  });

  factory KnowledgeRelation.fromJson(Map<String, dynamic> json) =>
      KnowledgeRelation(
        id: json['id'] as int?,
        sourceId: json['source_id'] as int,
        targetId: json['target_id'] as int,
        predicate: json['predicate'] as String,
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
        properties: json['properties'] is Map
            ? Map<String, dynamic>.from(json['properties'] as Map)
            : const {},
        createdAt: json['created_at'] as int?,
        validAt: json['valid_at'] as int?,
        invalidAt: json['invalid_at'] as int?,
        ingestedAt: json['ingested_at'] as int?,
        expiredAt: json['expired_at'] as int?,
        lastAccessed: json['last_accessed'] as int?,
        accessCount: json['access_count'] as int? ?? 1,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        sourceText: json['source_text'] as String?,
        isActive: (json['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'source_id': sourceId,
        'target_id': targetId,
        'predicate': predicate,
        'weight': weight,
        'properties': properties,
        'created_at': createdAt,
        'valid_at': validAt,
        'invalid_at': invalidAt,
        'ingested_at': ingestedAt,
        'expired_at': expiredAt,
        'last_accessed': lastAccessed,
        'access_count': accessCount,
        'confidence': confidence,
        'source_text': sourceText,
        'is_active': isActive ? 1 : 0,
      };
}

/// A Knowledge Graph fact (key-value pair on an entity).
class KnowledgeFact {
  final int? id;
  final int entityId;
  final String key;
  final String value;
  final String valueType;

  // Bi-temporal
  final int? validAt;
  final int? invalidAt;
  final int? ingestedAt;
  final int? expiredAt;

  final double confidence;
  final String? sourceText;

  const KnowledgeFact({
    this.id,
    required this.entityId,
    required this.key,
    required this.value,
    this.valueType = 'string',
    this.validAt,
    this.invalidAt,
    this.ingestedAt,
    this.expiredAt,
    this.confidence = 1.0,
    this.sourceText,
  });

  factory KnowledgeFact.fromJson(Map<String, dynamic> json) => KnowledgeFact(
        id: json['id'] as int?,
        entityId: json['entity_id'] as int,
        key: (json['fact_key'] ?? json['key']) as String,
        value: (json['fact_value'] ?? json['value']) as String,
        valueType: json['value_type'] as String? ?? 'string',
        validAt: json['valid_at'] as int?,
        invalidAt: json['invalid_at'] as int?,
        ingestedAt: json['ingested_at'] as int?,
        expiredAt: json['expired_at'] as int?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        sourceText: json['source_text'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'entity_id': entityId,
        'fact_key': key,
        'fact_value': value,
        'value_type': valueType,
        'valid_at': validAt,
        'invalid_at': invalidAt,
        'ingested_at': ingestedAt,
        'expired_at': expiredAt,
        'confidence': confidence,
        'source_text': sourceText,
      };
}

/// A Knowledge Graph relation enriched with source/target entity names.
class KnowledgeRelationWithNames {
  final KnowledgeRelation relation;
  final String sourceName;
  final String targetName;

  const KnowledgeRelationWithNames({
    required this.relation,
    required this.sourceName,
    required this.targetName,
  });
}

/// Full detail view of a Knowledge Graph entity.
class KnowledgeEntityDetail {
  final KnowledgeEntity entity;
  final List<KnowledgeFact> facts;
  final List<KnowledgeRelationWithNames> relations;
  final List<KnowledgeAlias> aliases;
  final double decayScore;

  const KnowledgeEntityDetail({
    required this.entity,
    required this.facts,
    required this.relations,
    required this.aliases,
    required this.decayScore,
  });
}

/// A Knowledge Graph alias for fuzzy entity resolution.
class KnowledgeAlias {
  final int? id;
  final int entityId;
  final String aliasName;
  final String aliasType;
  final double confidence;

  const KnowledgeAlias({
    this.id,
    required this.entityId,
    required this.aliasName,
    this.aliasType = 'name',
    this.confidence = 1.0,
  });

  factory KnowledgeAlias.fromJson(Map<String, dynamic> json) =>
      KnowledgeAlias(
        id: json['id'] as int?,
        entityId: json['entity_id'] as int,
        aliasName: json['alias_name'] as String,
        aliasType: json['alias_type'] as String? ?? 'name',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'entity_id': entityId,
        'alias_name': aliasName,
        'alias_type': aliasType,
        'confidence': confidence,
      };
}
