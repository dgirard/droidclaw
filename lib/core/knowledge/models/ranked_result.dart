import 'entity.dart';

/// A ranked entity result from the hybrid query pipeline.
class RankedEntity {
  final KnowledgeEntity entity;
  final List<KnowledgeFact> facts;
  final List<KnowledgeRelation> relations;
  final double score;

  /// Individual signal scores for debugging/tuning.
  final double bm25Score;
  final double activationScore;
  final double decayScore;

  const RankedEntity({
    required this.entity,
    this.facts = const [],
    this.relations = const [],
    required this.score,
    this.bm25Score = 0.0,
    this.activationScore = 0.0,
    this.decayScore = 0.0,
  });

  /// Format as XML for system prompt injection.
  String toXml() {
    final buf = StringBuffer();
    buf.write('<entity name="${_escapeXml(entity.name)}" '
        'type="${entity.entityType.label}">');
    for (final f in facts) {
      buf.write('<fact key="${_escapeXml(f.key)}">${_escapeXml(f.value)}</fact>');
    }
    for (final r in relations) {
      // Determine direction relative to this entity
      final isSource = r.sourceId == entity.id;
      if (isSource) {
        buf.write('<relation predicate="${_escapeXml(r.predicate)}" '
            'target_id="${r.targetId}"/>');
      } else {
        buf.write('<relation predicate="${_escapeXml(r.predicate)}" '
            'source_id="${r.sourceId}"/>');
      }
    }
    buf.write('</entity>');
    return buf.toString();
  }

  /// Format as readable text for the user display (ToolResult.forUser).
  String toReadable() {
    final buf = StringBuffer();
    buf.writeln('${entity.name} (${entity.entityType.label})');
    if (entity.summary != null) {
      buf.writeln('  ${entity.summary}');
    }
    for (final f in facts) {
      buf.writeln('  ${f.key}: ${f.value}');
    }
    return buf.toString().trimRight();
  }

  Map<String, dynamic> toJson() => {
        'entity': entity.toJson(),
        'facts': facts.map((f) => f.toJson()).toList(),
        'relations': relations.map((r) => r.toJson()).toList(),
        'score': score,
        'bm25_score': bm25Score,
        'activation_score': activationScore,
        'decay_score': decayScore,
      };

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

/// Format a list of ranked results as XML for system prompt injection.
/// Respects a character budget to avoid blowing up the context window.
String formatKnowledgeContext(List<RankedEntity> results, {int maxChars = 2000}) {
  if (results.isEmpty) return '';
  final buf = StringBuffer('<knowledge_context>\n');
  for (final r in results) {
    final xml = r.toXml();
    if (buf.length + xml.length + 25 > maxChars) break;
    buf.writeln('  $xml');
  }
  buf.write('</knowledge_context>');
  return buf.toString();
}
