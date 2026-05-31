// ignore_for_file: avoid_print, depend_on_referenced_packages
// ignore_for_file: prefer_function_declarations_over_variables

import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/algorithms/string_similarity.dart';
import 'package:droidclaw/core/knowledge/services/entity_resolver.dart';
import 'package:droidclaw/core/knowledge/services/kb_maintenance_service.dart';

void main() {
  group('Céline variants deduplication', () {
    const variants = [
      'Céline Torris',
      'Céline Thoris',
      'Céline Taurisse',
      'Céline Thooris',
      'Céline',
    ];

    test('Jaro-Winkler scores between Céline variants are high', () {
      for (var i = 0; i < variants.length; i++) {
        for (var j = i + 1; j < variants.length; j++) {
          final a = variants[i].toLowerCase();
          final b = variants[j].toLowerCase();
          final jw = EntityResolver.jaroWinkler(a, b);
          print('JW("${variants[i]}", "${variants[j]}") = ${jw.toStringAsFixed(3)}');
        }
      }
    });

    test('StringSimilarity.combined scores between Céline variants', () {
      for (var i = 0; i < variants.length; i++) {
        for (var j = i + 1; j < variants.length; j++) {
          final score = StringSimilarity.combined(variants[i], variants[j]);
          print('combined("${variants[i]}", "${variants[j]}") = ${score.toStringAsFixed(3)}');
        }
      }
    });

    test('All full-name Céline variants should pass name floor (>= 0.60)', () {
      final fullNames = [
        'Céline Torris',
        'Céline Thoris',
        'Céline Taurisse',
        'Céline Thooris',
      ];
      for (var i = 0; i < fullNames.length; i++) {
        for (var j = i + 1; j < fullNames.length; j++) {
          final score = StringSimilarity.combined(fullNames[i], fullNames[j]);
          expect(
            score,
            greaterThanOrEqualTo(0.60),
            reason: '"${fullNames[i]}" vs "${fullNames[j]}" score=$score should be >= 0.60',
          );
        }
      }
    });

    test('All full-name Céline variants should pass composite threshold (>= 0.60 name-only)', () {
      final fullNames = [
        'Céline Torris',
        'Céline Thoris',
        'Céline Taurisse',
        'Céline Thooris',
      ];
      for (var i = 0; i < fullNames.length; i++) {
        for (var j = i + 1; j < fullNames.length; j++) {
          final score = StringSimilarity.combined(fullNames[i], fullNames[j]);
          // In name-only mode (no relations/facts), composite = nameScore
          // and threshold = 0.60
          expect(
            score,
            greaterThanOrEqualTo(0.60),
            reason: '"${fullNames[i]}" vs "${fullNames[j]}" score=$score should be >= 0.60 (name-only threshold)',
          );
        }
      }
    });

    test('Token blocking: all Céline variants share the "céline" token', () {
      final tokenize = (String s) => s
          .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
          .split(RegExp(r'\s+'))
          .map((t) => t.toLowerCase())
          .where((t) => t.length > 1)
          .toSet();

      final allTokens = variants.map(tokenize).toList();
      for (var i = 0; i < variants.length; i++) {
        expect(allTokens[i], contains('céline'),
            reason: '"${variants[i]}" should tokenize to include "céline"');
      }

      // All pairs share at least the "céline" token
      for (var i = 0; i < variants.length; i++) {
        for (var j = i + 1; j < variants.length; j++) {
          final shared = allTokens[i].intersection(allTokens[j]);
          expect(shared, isNotEmpty,
              reason: '"${variants[i]}" and "${variants[j]}" should share tokens');
        }
      }
    });

    test('"Lena" and "Léna Girard" should be candidate for fusion (>= 0.60)', () {
      final score = StringSimilarity.combined('Lena', 'Léna Girard');
      print('combined("Lena", "Léna Girard") = ${score.toStringAsFixed(3)}');

      // Check individual components
      final jw = EntityResolver.jaroWinkler('lena', 'léna girard');
      final jaccard = StringSimilarity.tokenJaccard('lena', 'léna girard');
      final trigram = StringSimilarity.trigramSimilarity('lena', 'léna girard');
      print('  JW: ${jw.toStringAsFixed(3)}');
      print('  Jaccard: ${jaccard.toStringAsFixed(3)}');
      print('  Trigram: ${trigram.toStringAsFixed(3)}');

      // Token blocking check
      final tokenize = (String s) => s
          .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
          .split(RegExp(r'\s+'))
          .map((t) => t.toLowerCase())
          .where((t) => t.length > 1)
          .toSet();
      print('  Tokens "Lena": ${tokenize('Lena')}');
      print('  Tokens "Léna Girard": ${tokenize('Léna Girard')}');
      print('  Shared: ${tokenize('Lena').intersection(tokenize('Léna Girard'))}');

      // bestCombined with aliases
      final bestScore = StringSimilarity.bestCombined(
        ['Lena'],
        ['Léna Girard', 'Léna'],
      );
      print('  bestCombined with alias "Léna": ${bestScore.toStringAsFixed(3)}');

      expect(
        score,
        greaterThanOrEqualTo(0.60),
        reason: '"Lena" vs "Léna Girard" score=$score should be >= 0.60',
      );
    });

    test('"Papa" and "Père" should be candidate for fusion (>= 0.60)', () {
      final score = StringSimilarity.combined('Papa', 'Père');
      print('combined("Papa", "Père") = ${score.toStringAsFixed(3)}');
      expect(score, greaterThanOrEqualTo(0.60),
          reason: 'Papa/Père are synonyms, should score >= 0.60');
      expect(StringSimilarity.areSynonyms(
          StringSimilarity.normalize('Papa'),
          StringSimilarity.normalize('Père')), isTrue);
    });

    test('"Maman" and "Mère" should be candidate for fusion (>= 0.60)', () {
      final score = StringSimilarity.combined('Maman', 'Mère');
      print('combined("Maman", "Mère") = ${score.toStringAsFixed(3)}');
      expect(score, greaterThanOrEqualTo(0.60),
          reason: 'Maman/Mère are synonyms, should score >= 0.60');
      expect(StringSimilarity.areSynonyms(
          StringSimilarity.normalize('Maman'),
          StringSimilarity.normalize('Mère')), isTrue);
    });

    test('Pairs requiring LLM (no string similarity, no synonym table)', () {
      // These pairs are semantic synonyms that string similarity cannot detect.
      // They need the embedding path → LLM verification.
      // Note: Vélo/Bicyclette, Voiture/Automobile, Docteur/Médecin
      // are now in the synonym table → moved to synonym test.
      final semanticPairs = <List<String>>[
        ['Téléphone', 'Portable'],
        ['Appartement', 'Logement'],
        ['Collègue', 'Camarade'],
        ['Chien', 'Toutou'],
        ['Chat', 'Minou'],
      ];

      for (final pair in semanticPairs) {
        final score = StringSimilarity.combined(pair[0], pair[1]);
        final isSynonym = StringSimilarity.areSynonyms(
            StringSimilarity.normalize(pair[0]),
            StringSimilarity.normalize(pair[1]));
        print('${pair[0].padRight(14)} / ${pair[1].padRight(14)} '
            'combined=${score.toStringAsFixed(3)}  synonym=$isSynonym');
        // These must NOT pass string similarity — they need LLM
        expect(score, lessThan(0.60),
            reason: '"${pair[0]}" vs "${pair[1]}" should NOT pass string '
                'similarity — needs embedding+LLM path');
        expect(isSynonym, isFalse,
            reason: '"${pair[0]}" vs "${pair[1]}" should NOT be in synonym table');
      }
    });

    test('Pairs correctly handled by string similarity (no LLM needed)', () {
      // These pairs have enough character overlap to be detected deterministically.
      final stringPairs = <List<String>, double>{
        ['Céline Torris', 'Céline Thoris']: 0.60,
        ['Céline Thoris', 'Céline Thooris']: 0.60,
        ['Lena', 'Léna Girard']: 0.60,
      };

      for (final entry in stringPairs.entries) {
        final pair = entry.key;
        final threshold = entry.value;
        final score = StringSimilarity.combined(pair[0], pair[1]);
        print('${pair[0].padRight(18)} / ${pair[1].padRight(18)} '
            'combined=${score.toStringAsFixed(3)}  (threshold=$threshold)');
        expect(score, greaterThanOrEqualTo(threshold),
            reason: '"${pair[0]}" vs "${pair[1]}" should pass string similarity');
      }
    });

    test('Pairs correctly handled by synonym table (no LLM needed)', () {
      // These pairs are in the synonym table → score 0.85
      final synonymPairs = [
        ['Papa', 'Père'],
        ['Maman', 'Mère'],
        ['Maison', 'Domicile'],
        ['Travail', 'Boulot'],
        ['Bureau', 'Office'],
        ['Frère', 'Brother'],
        ['Vélo', 'Bicyclette'],
        ['Voiture', 'Automobile'],
        ['Docteur', 'Médecin'],
      ];

      for (final pair in synonymPairs) {
        final score = StringSimilarity.combined(pair[0], pair[1]);
        print('${pair[0].padRight(10)} / ${pair[1].padRight(10)} '
            'combined=${score.toStringAsFixed(3)}');
        expect(score, equals(0.85),
            reason: '"${pair[0]}" vs "${pair[1]}" should get synonym boost 0.85');
      }
    });

    test('"Maison" and "Domicile" should be candidate for fusion (>= 0.60)', () {
      final score = StringSimilarity.combined('Maison', 'Domicile');
      print('combined("Maison", "Domicile") = ${score.toStringAsFixed(3)}');
      expect(score, greaterThanOrEqualTo(0.60),
          reason: 'Maison/Domicile are synonyms, should score >= 0.60');
      expect(StringSimilarity.areSynonyms(
          StringSimilarity.normalize('Maison'),
          StringSimilarity.normalize('Domicile')), isTrue);
    });

    test('"Vélo" and "Bicyclette" now in synonym table → 0.85', () {
      final score = StringSimilarity.combined('Vélo', 'Bicyclette');
      print('combined("Vélo", "Bicyclette") = ${score.toStringAsFixed(3)}');
      expect(score, equals(0.85));
      expect(StringSimilarity.areSynonyms(
          StringSimilarity.normalize('Vélo'),
          StringSimilarity.normalize('Bicyclette')), isTrue);
    });

    test('Synonym detection covers multilingual family and place terms', () {
      // FR family
      expect(StringSimilarity.areSynonyms('papa', 'pere'), isTrue);
      expect(StringSimilarity.areSynonyms('maman', 'mere'), isTrue);
      expect(StringSimilarity.areSynonyms('frere', 'brother'), isTrue);
      expect(StringSimilarity.areSynonyms('soeur', 'sister'), isTrue);
      // EN family
      expect(StringSimilarity.areSynonyms('dad', 'father'), isTrue);
      expect(StringSimilarity.areSynonyms('mom', 'mother'), isTrue);
      // Places
      expect(StringSimilarity.areSynonyms('maison', 'domicile'), isTrue);
      expect(StringSimilarity.areSynonyms('maison', 'home'), isTrue);
      expect(StringSimilarity.areSynonyms('travail', 'boulot'), isTrue);
      expect(StringSimilarity.areSynonyms('travail', 'work'), isTrue);
      expect(StringSimilarity.areSynonyms('ecole', 'school'), isTrue);
      expect(StringSimilarity.areSynonyms('bureau', 'office'), isTrue);
      // Non-synonyms
      expect(StringSimilarity.areSynonyms('papa', 'maman'), isFalse);
      expect(StringSimilarity.areSynonyms('maison', 'bureau'), isFalse);
      expect(StringSimilarity.areSynonyms('papa', 'maison'), isFalse);
    });

    test('Individual similarity components', () {
      // Check each component individually for the hardest pair
      const a = 'céline taurisse';
      const b = 'céline thooris';

      final jw = EntityResolver.jaroWinkler(a, b);
      final jaccard = StringSimilarity.tokenJaccard(a, b);
      final trigram = StringSimilarity.trigramSimilarity(a, b);

      print('Components for "$a" vs "$b":');
      print('  Jaro-Winkler: ${jw.toStringAsFixed(3)}');
      print('  Token Jaccard: ${jaccard.toStringAsFixed(3)}');
      print('  Trigram: ${trigram.toStringAsFixed(3)}');
      print('  Combined: ${(0.5 * jw + 0.25 * jaccard + 0.25 * trigram).toStringAsFixed(3)}');
    });
  });

  group('Verification table generation', () {
    // Build candidates from the same test data
    final candidates = <DuplicateCandidate>[
      // Céline Torris vs Céline Thoris (typo variant)
      DuplicateCandidate(
        idA: 1,
        idB: 2,
        nameA: 'Céline Torris',
        nameB: 'Céline Thoris',
        nameScore: StringSimilarity.combined('Céline Torris', 'Céline Thoris'),
        relationScore: 0.8,
        factScore: 0.5,
        compositeScore: 0.0, // will be computed below
        aliasesA: ['Céline T.'],
        aliasesB: [],
        factSummariesA: ['tel: 06 12 34 56 78'],
        factSummariesB: ['tel: 06 12 34 56 78'],
      ),
      // Céline Taurisse vs Céline Thooris (harder variant)
      DuplicateCandidate(
        idA: 1,
        idB: 3,
        nameA: 'Céline Torris',
        nameB: 'Céline Taurisse',
        nameScore: StringSimilarity.combined('Céline Torris', 'Céline Taurisse'),
        relationScore: 0.6,
        factScore: 0.0,
        compositeScore: 0.0,
        aliasesA: ['Céline T.'],
        aliasesB: [],
        factSummariesA: ['tel: 06 12 34 56 78'],
        factSummariesB: [],
      ),
      // Lena vs Léna Girard (accent variant)
      DuplicateCandidate(
        idA: 10,
        idB: 11,
        nameA: 'Léna Girard',
        nameB: 'Lena',
        nameScore: StringSimilarity.combined('Léna Girard', 'Lena'),
        relationScore: 0.0,
        factScore: 0.0,
        compositeScore: StringSimilarity.combined('Léna Girard', 'Lena'),
        aliasesA: ['Léna'],
        aliasesB: [],
        factSummariesA: [],
        factSummariesB: [],
      ),
      // Papa vs Père (synonym)
      DuplicateCandidate(
        idA: 20,
        idB: 21,
        nameA: 'Papa',
        nameB: 'Père',
        nameScore: StringSimilarity.combined('Papa', 'Père'),
        relationScore: 0.9,
        factScore: 0.3,
        compositeScore: 0.0,
        aliasesA: [],
        aliasesB: [],
        factSummariesA: ['role: father'],
        factSummariesB: ['role: père'],
      ),
      // Maman vs Mère (synonym)
      DuplicateCandidate(
        idA: 30,
        idB: 31,
        nameA: 'Maman',
        nameB: 'Mère',
        nameScore: StringSimilarity.combined('Maman', 'Mère'),
        relationScore: 0.9,
        factScore: 0.4,
        compositeScore: 0.0,
        aliasesA: [],
        aliasesB: [],
        factSummariesA: ['role: mother'],
        factSummariesB: ['role: mère'],
      ),
    ];

    test('Table has correct header and row count', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      final lines = table.trim().split('\n');

      // Header + separator + 5 data rows
      expect(lines.length, equals(7));
      expect(lines[0], contains('ID_A'));
      expect(lines[0], contains('Name A'));
      expect(lines[0], contains('Aliases A'));
      expect(lines[0], contains('Facts A'));
      expect(lines[0], contains('Det. Score'));
      expect(lines[1], contains('---'));
    });

    test('Table contains all entity names', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      expect(table, contains('Céline Torris'));
      expect(table, contains('Céline Thoris'));
      expect(table, contains('Céline Taurisse'));
      expect(table, contains('Léna Girard'));
      expect(table, contains('Lena'));
      expect(table, contains('Papa'));
      expect(table, contains('Père'));
      expect(table, contains('Maman'));
      expect(table, contains('Mère'));
    });

    test('Table contains aliases and facts', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      expect(table, contains('Céline T.'));
      expect(table, contains('Léna'));
      expect(table, contains('tel: 06 12 34 56 78'));
      expect(table, contains('role: father'));
      expect(table, contains('role: père'));
      expect(table, contains('role: mother'));
      expect(table, contains('role: mère'));
    });

    test('Table contains all IDs', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      for (final id in [1, 2, 3, 10, 11, 20, 21, 30, 31]) {
        expect(table, contains('| $id |'));
      }
    });

    test('Table rows are numbered sequentially', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      for (var i = 1; i <= candidates.length; i++) {
        expect(table, contains('| $i |'));
      }
    });

    test('Table contains deterministic score percentages', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      // Lena/Léna Girard has a computed compositeScore
      final lenaScore = (StringSimilarity.combined('Léna Girard', 'Lena') * 100).round();
      expect(table, contains('$lenaScore%'));
    });

    test('Table is more compact than JSON equivalent', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      final json = candidates.map((c) => {
            'id_a': c.idA,
            'name_a': c.nameA,
            'aliases_a': c.aliasesA,
            'facts_a': c.factSummariesA,
            'id_b': c.idB,
            'name_b': c.nameB,
            'aliases_b': c.aliasesB,
            'facts_b': c.factSummariesB,
            'score': (c.compositeScore * 100).round(),
          }).toList().toString();

      print('Table length: ${table.length} chars');
      print('JSON length: ${json.length} chars');
      expect(table.length, lessThan(json.length),
          reason: 'Markdown table should be more compact than JSON');
    });

    test('Empty batch produces header-only table', () {
      final table = KbMaintenanceService.buildVerificationTable([]);
      final lines = table.trim().split('\n');
      expect(lines.length, equals(2)); // header + separator only
    });

    test('Print full table for visual inspection', () {
      final table = KbMaintenanceService.buildVerificationTable(candidates);
      print('--- Verification Table ---');
      print(table);
      print('--- End ---');
    });
  });

  group('LLM response parsing (simulated)', () {
    // Docteur lié à Léna vs Médecin lié à Léna → même personne
    final docteurSame = DuplicateCandidate(
      idA: 42,
      idB: 87,
      nameA: 'Docteur Martin',
      nameB: 'Médecin Martin',
      nameScore: 0.30,
      relationScore: 0.0,
      factScore: 0.0,
      compositeScore: 0.80,
      aliasesA: ['Dr Martin'],
      aliasesB: ['Martin'],
      factSummariesA: ['specialite: generaliste'],
      factSummariesB: ['specialite: generaliste'],
    );

    // Docteur lié à Léna vs Médecin lié à Marc → personnes différentes
    final docteurDiff = DuplicateCandidate(
      idA: 42,
      idB: 99,
      nameA: 'Docteur',
      nameB: 'Médecin',
      nameScore: 0.25,
      relationScore: 0.0,
      factScore: 0.0,
      compositeScore: 0.76,
      aliasesA: [],
      aliasesB: [],
      factSummariesA: ['patient: Léna'],
      factSummariesB: ['patient: Marc'],
    );

    // Vélo vs Bicyclette — même concept
    final veloBicyclette = DuplicateCandidate(
      idA: 50,
      idB: 51,
      nameA: 'Vélo',
      nameB: 'Bicyclette',
      nameScore: 0.22,
      relationScore: 0.0,
      factScore: 0.0,
      compositeScore: 0.78,
      aliasesA: [],
      aliasesB: [],
      factSummariesA: ['type: transport'],
      factSummariesB: ['type: transport'],
    );

    test('Table shows context for LLM to distinguish same vs different entities', () {
      final table = KbMaintenanceService.buildVerificationTable(
        [docteurSame, docteurDiff, veloBicyclette],
      );
      print(table);

      // Same person: shared alias and facts
      expect(table, contains('Dr Martin'));
      expect(table, contains('specialite: generaliste'));

      // Different people: different patient facts
      expect(table, contains('patient: Léna'));
      expect(table, contains('patient: Marc'));

      // Semantic synonyms: same type
      expect(table, contains('Vélo'));
      expect(table, contains('Bicyclette'));
      expect(table, contains('type: transport'));
    });

    test('LLM merges Docteur/Médecin with shared relations (score 90)', () {
      final batch = [docteurSame];
      final validIds = {42, 87};
      final llmResponse = '{"pairs":[{"id_a":42,"id_b":87,"score":90,"justification":"Same doctor, alias match + same specialty"}]}';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      expect(pairs, hasLength(1));
      expect(pairs[0].primaryId, equals(42));
      expect(pairs[0].secondaryId, equals(87));
      expect(pairs[0].score, equals(0.90));
      expect(pairs[0].level, equals(1)); // > 85% = level 1
      print('Docteur Martin / Médecin Martin: score=${pairs[0].score} '
          'level=${pairs[0].level} → MERGE');
    });

    test('LLM rejects Docteur/Médecin with different relations (score 25)', () {
      final batch = [docteurDiff];
      final validIds = {42, 99};
      final llmResponse = '{"pairs":[{"id_a":42,"id_b":99,"score":25,"justification":"Different people, no shared relations"}]}';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      expect(pairs, hasLength(1));
      expect(pairs[0].score, equals(0.25));
      expect(pairs[0].level, equals(3)); // < 50% = level 3
      print('Docteur / Médecin (different): score=${pairs[0].score} '
          'level=${pairs[0].level} → NO MERGE');
    });

    test('LLM merges Vélo/Bicyclette as same concept (score 95)', () {
      final batch = [veloBicyclette];
      final validIds = {50, 51};
      final llmResponse = '{"pairs":[{"id_a":50,"id_b":51,"score":95,"justification":"Exact synonym, same transport type"}]}';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      expect(pairs, hasLength(1));
      expect(pairs[0].score, equals(0.95));
      expect(pairs[0].level, equals(1)); // > 85% = level 1
      print('Vélo / Bicyclette: score=${pairs[0].score} '
          'level=${pairs[0].level} → MERGE');
    });

    test('LLM handles mixed batch: merge some, reject others', () {
      final batch = [docteurSame, docteurDiff, veloBicyclette];
      final validIds = {42, 87, 99, 50, 51};
      final llmResponse = '{"pairs":['
          '{"id_a":42,"id_b":87,"score":90,"justification":"Same doctor"},'
          '{"id_a":42,"id_b":99,"score":25,"justification":"Different people"},'
          '{"id_a":50,"id_b":51,"score":95,"justification":"Exact synonym"}'
          ']}';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      expect(pairs, hasLength(3));

      // Sort by score to verify classification
      pairs.sort((a, b) => b.score.compareTo(a.score));

      // Vélo/Bicyclette → level 1 (merge)
      expect(pairs[0].primaryName, equals('Vélo'));
      expect(pairs[0].level, equals(1));

      // Docteur Martin / Médecin Martin → level 1 (merge)
      expect(pairs[1].primaryName, equals('Docteur Martin'));
      expect(pairs[1].level, equals(1));

      // Docteur / Médecin (different) → level 3 (no merge)
      expect(pairs[2].primaryName, equals('Docteur'));
      expect(pairs[2].level, equals(3));

      for (final p in pairs) {
        final action = p.level == 1 ? 'MERGE' : p.level == 2 ? 'ASK USER' : 'NO MERGE';
        print('${p.primaryName.padRight(18)} / ${p.secondaryName.padRight(18)} '
            'score=${p.score}  level=${p.level}  → $action');
      }
    });

    test('LLM response with markdown fences is parsed correctly', () {
      final batch = [veloBicyclette];
      final validIds = {50, 51};
      final llmResponse = '```json\n{"pairs":[{"id_a":50,"id_b":51,"score":95,"justification":"Synonym"}]}\n```';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      expect(pairs, hasLength(1));
      expect(pairs[0].score, equals(0.95));
    });

    test('LLM returns unknown IDs → ignored, fallback to deterministic', () {
      final batch = [veloBicyclette];
      final validIds = {50, 51};
      // LLM hallucinated IDs 999/888
      final llmResponse = '{"pairs":[{"id_a":999,"id_b":888,"score":90,"justification":"Hallucinated"}]}';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      // The hallucinated pair is ignored, vélo/bicyclette falls back to deterministic
      expect(pairs, hasLength(1));
      expect(pairs[0].primaryName, equals('Vélo'));
      expect(pairs[0].score, equals(0.78)); // compositeScore fallback
      expect(pairs[0].justification, equals('Deterministic score only'));
    });

    test('Malformed LLM response → fallback to deterministic scores', () {
      final batch = [docteurSame, veloBicyclette];
      final validIds = {42, 87, 50, 51};
      final llmResponse = 'This is not JSON at all!';

      final pairs = KbMaintenanceService.parseLlmResponse(
        llmResponse, batch, validIds,
      );

      // All fall back to deterministic
      expect(pairs, hasLength(2));
      for (final p in pairs) {
        expect(p.justification, equals('Deterministic score only'));
      }
    });
  });

  group('Fact-level deduplication: souliers vs chaussures', () {
    test('String similarity between souliers and chaussures is too low for automatic dedup', () {
      final score = StringSimilarity.combined('souliers', 'chaussures');
      print('combined("souliers", "chaussures") = ${score.toStringAsFixed(3)}');
      // These are French synonyms (shoes) but look very different as strings
      expect(score, lessThan(0.60),
          reason: 'souliers/chaussures should be below name floor — needs LLM');
    });

    test('souliers/chaussures not in synonym table either', () {
      // Synonym table has common pairs but not every French synonym
      final score = StringSimilarity.combined('souliers', 'chaussures');
      expect(score, isNot(equals(0.85)),
          reason: 'souliers/chaussures should not be in synonym table');
    });

    test('DuplicateFactCandidate models souliers/chaussures on same entity', () {
      // Entity "Didier" has two facts:
      //   fact #101: key="accessoire", value="souliers"
      //   fact #102: key="accessoire", value="chaussures"
      // These are cross-key or same-key candidates depending on how they were stored.
      // Either way, string similarity is too low → must go to LLM.

      final candidate = DuplicateFactCandidate(
        entityId: 1,
        entityName: 'Didier',
        factIdA: 101,
        factIdB: 102,
        factKey: 'accessoire',
        valueA: 'souliers',
        valueB: 'chaussures',
        similarity: StringSimilarity.combined('souliers', 'chaussures'),
        source: 'cross-key', // LLM needed for semantic detection
      );

      expect(candidate.entityName, equals('Didier'));
      expect(candidate.valueA, equals('souliers'));
      expect(candidate.valueB, equals('chaussures'));
      expect(candidate.similarity, lessThan(0.60));
      expect(candidate.source, equals('cross-key'));
      print(
          'Fact dedup candidate: "${candidate.valueA}" vs "${candidate.valueB}" '
          'on entity "${candidate.entityName}" '
          '(similarity=${candidate.similarity.toStringAsFixed(3)}, source=${candidate.source})');
    });

    test('ScoredFactPair after LLM confirms souliers=chaussures', () {
      // After LLM confirms these are duplicates, we get a scored pair
      // with the fact to keep and the fact to remove.
      final scored = ScoredFactPair(
        entityId: 1,
        entityName: 'Didier',
        factIdKeep: 102, // chaussures (more common term)
        factIdRemove: 101, // souliers (old-fashioned synonym)
        factKey: 'accessoire',
        valueKeep: 'chaussures',
        valueRemove: 'souliers',
        score: 0.90,
        justification: 'Souliers et chaussures sont synonymes (types de chaussures)',
      );

      expect(scored.entityName, equals('Didier'));
      expect(scored.valueKeep, equals('chaussures'));
      expect(scored.valueRemove, equals('souliers'));
      expect(scored.score, greaterThan(0.85));
      expect(scored.factIdKeep, isNot(equals(scored.factIdRemove)));
      print(
          'LLM verdict: remove "${scored.valueRemove}" (fact #${scored.factIdRemove}), '
          'keep "${scored.valueKeep}" (fact #${scored.factIdKeep}) — '
          'score=${(scored.score * 100).round()}% "${scored.justification}"');
    });

    test('Similar French shoe synonyms also need LLM', () {
      // Other shoe-related synonyms that string similarity cannot catch
      final pairs = {
        'souliers': 'chaussures',
        'baskets': 'sneakers',
        'bottes': 'bottines', // these are actually different but close
      };

      for (final entry in pairs.entries) {
        final score = StringSimilarity.combined(entry.key, entry.value);
        print(
            'combined("${entry.key}", "${entry.value}") = ${score.toStringAsFixed(3)}');
      }

      // souliers/chaussures: very different strings
      expect(
        StringSimilarity.combined('souliers', 'chaussures'),
        lessThan(0.60),
      );
      // baskets/sneakers: completely different languages
      expect(
        StringSimilarity.combined('baskets', 'sneakers'),
        lessThan(0.60),
      );
    });
  });

  group('KB diagnostic: real duplicate pairs from export', () {
    // Each pair: names A (with aliases), names B (with aliases), expected result
    final realPairs = <String, List<List<String>>>{
      'Céline Torris <-> Céline Thooris': [
        ['Céline Torris', 'Céline Thoris', 'Céline Taurisse'],
        ['Céline Thooris'],
      ],
      'Proof Editor.ai <-> ProofEditor': [
        ['Proof Editor.ai', 'Proof Editor'],
        ['ProofEditor'],
      ],
      'papa <-> Père': [
        ['papa'],
        ['Père'],
      ],
      'Noé <-> Noé Girard': [
        ['Noé'],
        ['Noé Girard'],
      ],
      'Léna <-> Lena Girard': [
        ['Léna'],
        ['Lena Girard', 'Léna Girard'],
      ],
      'vélo <-> bicyclette': [
        ['vélo'],
        ['bicyclette'],
      ],
      'La Madeleine <-> Église de la Madeleine': [
        ['La Madeleine'],
        ['Église de la Madeleine'],
      ],
      'full dream <-> dream': [
        ['full dream'],
        ['dream'],
      ],
      'Documents interactifs <-> Explication des documents interactifs': [
        ['Documents interactifs avec un agent'],
        ['Explication des documents interactifs avec un agent'],
      ],
    };

    // Helper: tokenize with camelCase splitting + synonym expansion (mirrors _tokenize + synonym step)
    Set<String> tokenizeWithSynonyms(String name) {
      final words = name
          .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty);
      final tokens = <String>{};
      for (final word in words) {
        final normalized = StringSimilarity.normalize(word);
        if (normalized.length > 1) tokens.add(normalized);
        // CamelCase splitting
        final camelParts = word
            .replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (m) => '${m.group(1)} ${m.group(2)}',
            )
            .split(' ')
            .map((t) => StringSimilarity.normalize(t))
            .where((t) => t.length > 1);
        tokens.addAll(camelParts);
      }
      // Synonym expansion
      final expanded = <String>{...tokens};
      for (final token in tokens) {
        expanded.addAll(StringSimilarity.synonymsOf(token));
      }
      return expanded;
    }

    // Helper: containment check (mirrors _anyNameContained)
    bool anyContained(List<String> namesA, List<String> namesB) {
      for (final a in namesA) {
        final na = StringSimilarity.normalize(a);
        if (na.length < 3) continue;
        for (final b in namesB) {
          final nb = StringSimilarity.normalize(b);
          if (nb.length < 3) continue;
          if (na != nb && (nb.contains(na) || na.contains(nb))) return true;
        }
      }
      return false;
    }

    test('Diagnostic: name scores + token blocking for all real pairs', () {
      print('\n${"="*90}');
      print('DIAGNOSTIC: Real duplicate pairs from KB export (WITH FIXES)');
      print('=' * 90);
      print('${"Pair".padRight(50)} ${"Score".padRight(8)} ${"Tokens?".padRight(10)} ${"Contained?".padRight(12)} Verdict');
      print('${"-"*50} ${"-"*8} ${"-"*10} ${"-"*12} ${"-"*10}');

      var okCount = 0;
      var missCount = 0;

      for (final entry in realPairs.entries) {
        final namesA = entry.value[0];
        final namesB = entry.value[1];

        final nameScore = StringSimilarity.bestCombined(namesA, namesB);

        // Token blocking with camelCase + synonyms
        final tokensA = <String>{};
        for (final n in namesA) {
          tokensA.addAll(tokenizeWithSynonyms(n));
        }
        final tokensB = <String>{};
        for (final n in namesB) {
          tokensB.addAll(tokenizeWithSynonyms(n));
        }
        final shared = tokensA.intersection(tokensB);
        final blocked = shared.isNotEmpty;

        // Containment check
        final contained = anyContained(namesA, namesB);
        final nameFloor = contained ? 0.20 : 0.60;
        final passesFloor = nameScore >= nameFloor;

        String verdict;
        if (!blocked) {
          verdict = 'MISS (no token)';
          missCount++;
        } else if (!passesFloor) {
          verdict = 'MISS (< ${nameFloor.toStringAsFixed(2)})';
          missCount++;
        } else {
          verdict = 'OK';
          okCount++;
        }

        print(
          '${entry.key.padRight(50)} '
          '${nameScore.toStringAsFixed(3).padRight(8)} '
          '${(blocked ? "YES" : "NO").padRight(10)} '
          '${(contained ? "YES" : "NO").padRight(12)} '
          '$verdict',
        );
      }

      print('\nResult: $okCount OK, $missCount MISS out of ${realPairs.length} pairs');
      // All real pairs should now be detected
      expect(missCount, equals(0), reason: 'All real duplicate pairs should be detected');
    });
  });

  // ─── Cleanup operation parsing tests ───────────────────────────────

  group('Cleanup: _parseCleanupResponse', () {
    // We test the sealed classes and JSON parsing logic directly.

    test('CleanupOperation sealed class subtypes with confidence', () {
      const merge = CleanupMerge(primaryId: 1, secondaryId: 2, reason: 'dup', confidence: 85);
      const delete = CleanupDelete(entityId: 3, reason: 'garbage', confidence: 95);
      const delRel = CleanupDeleteRelation(relationId: 4, reason: 'stale');

      expect(merge.primaryId, 1);
      expect(merge.secondaryId, 2);
      expect(merge.reason, 'dup');
      expect(merge.confidence, 85);

      expect(delete.entityId, 3);
      expect(delete.reason, 'garbage');
      expect(delete.confidence, 95);

      expect(delRel.relationId, 4);
      expect(delRel.reason, 'stale');
      expect(delRel.confidence, isNull);

      // Exhaustive switch works
      for (final op in <CleanupOperation>[merge, delete, delRel]) {
        final type = switch (op) {
          CleanupMerge() => 'merge',
          CleanupDelete() => 'delete',
          CleanupDeleteRelation() => 'delete_relation',
        };
        expect(type, isNotEmpty);
      }
    });

    test('CleanupResult counts and execution log', () {
      const result = CleanupResult(
        mergeCount: 3,
        deleteCount: 5,
        deleteRelationCount: 2,
        errors: ['err1'],
        executedOps: [
          'MERGE: "Foo" (#2) → "Bar" (#1) (85%) — duplicate',
          'DELETE: "blabla" (#3, CONCEPT) (95%) — garbage',
        ],
      );
      expect(result.totalExecuted, 10);
      expect(result.errors.length, 1);
      expect(result.executedOps.length, 2);
      expect(result.executedOps[0], contains('MERGE'));
      expect(result.executedOps[0], contains('85%'));
      expect(result.executedOps[1], contains('DELETE'));
    });

    test('parseCleanupResponse with confidence values', () {
      final ops = KbMaintenanceService.parseCleanupResponse('''
      {"operations":[
        {"type":"delete","entity_id":34,"confidence":95,"reason":"garbage"},
        {"type":"merge","primary_id":7,"secondary_id":86,"confidence":72,"reason":"duplicates"},
        {"type":"delete_relation","relation_id":42,"confidence":60,"reason":"stale"},
        {"type":"delete","entity_id":50,"reason":"no confidence field"}
      ],"summary":"test"}
      ''');

      expect(ops.length, 4);
      expect(ops[0], isA<CleanupDelete>());
      expect((ops[0] as CleanupDelete).confidence, 95);
      expect(ops[1], isA<CleanupMerge>());
      expect((ops[1] as CleanupMerge).confidence, 72);
      expect(ops[2], isA<CleanupDeleteRelation>());
      expect((ops[2] as CleanupDeleteRelation).confidence, 60);
      // Missing confidence → null
      expect(ops[3].confidence, isNull);
    });

    test('parseCleanupResponse clamps out-of-range confidence', () {
      final ops = KbMaintenanceService.parseCleanupResponse('''
      {"operations":[
        {"type":"delete","entity_id":1,"confidence":150,"reason":"too high"},
        {"type":"delete","entity_id":2,"confidence":-10,"reason":"negative"},
        {"type":"delete","entity_id":3,"confidence":85.7,"reason":"float"},
        {"type":"delete","entity_id":4,"confidence":"42","reason":"string"}
      ]}
      ''');

      expect(ops.length, 4);
      expect(ops[0].confidence, 100); // clamped from 150
      expect(ops[1].confidence, 0);   // clamped from -10
      expect(ops[2].confidence, 85);  // float truncated to int
      expect(ops[3].confidence, 42);  // string parsed
    });

    test('parseCleanupResponse with markdown fences', () {
      final ops = KbMaintenanceService.parseCleanupResponse('''```json
{"operations":[{"type":"delete","entity_id":1,"confidence":90,"reason":"test"}]}
```''');

      expect(ops.length, 1);
      expect(ops[0].confidence, 90);
    });

    test('parseCleanupResponse with "score" fallback key', () {
      final ops = KbMaintenanceService.parseCleanupResponse('''
      {"operations":[
        {"type":"delete","entity_id":1,"score":88,"reason":"using score key"}
      ]}
      ''');

      expect(ops.length, 1);
      expect(ops[0].confidence, 88);
    });
  });
}
