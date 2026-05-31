import '../services/entity_resolver.dart';

/// Hybrid string similarity for entity name matching.
///
/// Combines Jaro-Winkler (50%), token Jaccard (25%), and
/// character trigram overlap (25%) for multilingual fuzzy matching.
/// All comparisons normalize diacritics (é→e, ü→u, etc.) for
/// accent-insensitive matching.
class StringSimilarity {
  /// Combined similarity score (0.0–1.0).
  ///
  /// Reuses [EntityResolver.jaroWinkler] for the JW component.
  static double combined(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final aNorm = normalize(a);
    final bNorm = normalize(b);
    if (aNorm == bNorm) return 1.0;

    // Check synonym boost before string similarity
    if (areSynonyms(aNorm, bNorm)) return 0.85;

    final jw = EntityResolver.jaroWinkler(aNorm, bNorm);
    final jaccard = tokenJaccard(aNorm, bNorm);
    final trigram = trigramSimilarity(aNorm, bNorm);
    return 0.5 * jw + 0.25 * jaccard + 0.25 * trigram;
  }

  /// Best combined score across all name/alias combinations.
  ///
  /// [namesA] and [namesB] are lists containing the entity name
  /// plus all aliases. Returns the maximum pairwise score.
  static double bestCombined(List<String> namesA, List<String> namesB) {
    var best = 0.0;
    for (final a in namesA) {
      for (final b in namesB) {
        final score = combined(a, b);
        if (score > best) best = score;
        if (best >= 1.0) return 1.0;
      }
    }
    return best;
  }

  /// Token Jaccard similarity: |A∩B| / |A∪B| on word tokens.
  ///
  /// Handles word reordering (e.g., "John Smith" vs "Smith, John").
  static double tokenJaccard(String a, String b) {
    final tokensA = _tokenize(a);
    final tokensB = _tokenize(b);
    if (tokensA.isEmpty && tokensB.isEmpty) return 1.0;
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    return union > 0 ? intersection / union : 0.0;
  }

  /// Character trigram similarity: |A∩B| / |A∪B| on 3-char substrings.
  ///
  /// Language-agnostic fuzzy matching that handles phonetic similarity
  /// better than Soundex/Metaphone for non-English names.
  static double trigramSimilarity(String a, String b) {
    final triA = _trigrams(a);
    final triB = _trigrams(b);
    if (triA.isEmpty && triB.isEmpty) return 1.0;
    if (triA.isEmpty || triB.isEmpty) return 0.0;
    final intersection = triA.intersection(triB).length;
    final union = triA.union(triB).length;
    return union > 0 ? intersection / union : 0.0;
  }

  /// Normalize: lowercase + strip diacritics (é→e, ü→u, ñ→n, etc.)
  static String normalize(String s) {
    return _stripDiacritics(s.toLowerCase());
  }

  /// Strip diacritical marks using Unicode NFD decomposition.
  ///
  /// NFD splits "é" into "e" + combining accent (U+0301).
  /// We then remove all combining marks (U+0300–U+036F).
  static String _stripDiacritics(String s) {
    // Dart doesn't have built-in NFD normalization, so use a lookup table
    // for common Latin diacritics used in FR/ES/DE/IT/PT.
    final buf = StringBuffer();
    for (final rune in s.runes) {
      buf.writeCharCode(_diacriticMap[rune] ?? rune);
    }
    return buf.toString();
  }

  static final _nonWordRe = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _whitespaceRe = RegExp(r'\s+');

  static Set<String> _tokenize(String s) {
    return s
        .replaceAll(_nonWordRe, ' ')
        .split(_whitespaceRe)
        .where((t) => t.length > 1)
        .toSet();
  }

  /// Check if two normalized strings are known synonyms.
  ///
  /// Handles family terms, common abbreviations, and other semantic
  /// equivalences that string similarity cannot detect.
  static bool areSynonyms(String aNorm, String bNorm) {
    final aKey = _synonymKey(aNorm);
    final bKey = _synonymKey(bNorm);
    if (aKey == null || bKey == null) return false;
    return aKey == bKey;
  }

  /// Map from word → canonical key (first element of its synonym group).
  /// Built lazily from [_synonymGroups] for O(1) lookup.
  static final _synonymIndex = _buildSynonymIndex();

  static Map<String, String> _buildSynonymIndex() {
    final index = <String, String>{};
    for (final group in _synonymGroups) {
      final canonical = group.first;
      for (final word in group) {
        index[word] = canonical;
      }
    }
    return index;
  }

  /// Returns a canonical key if the word belongs to a synonym group.
  static String? _synonymKey(String s) => _synonymIndex[s];

  /// Returns all synonyms of a normalized word (excluding itself).
  ///
  /// Used by token blocking to ensure entities with synonymous names
  /// (papa/père, vélo/bicyclette) end up in the same blocking bucket.
  static List<String> synonymsOf(String normalizedWord) {
    final canonical = _synonymIndex[normalizedWord];
    if (canonical == null) return const [];
    // Find the group with this canonical key
    for (final group in _synonymGroups) {
      if (group.first == canonical) {
        return group.where((s) => s != normalizedWord).toList();
      }
    }
    return const [];
  }

  /// Synonym groups: first element is the canonical form.
  /// All entries must be lowercase, accent-stripped.
  static const _synonymGroups = <List<String>>[
    // Family — FR/EN/ES/DE/IT
    ['papa', 'pere', 'father', 'padre', 'vater', 'dad', 'daddy', 'pa'],
    ['maman', 'mere', 'mother', 'madre', 'mutter', 'mom', 'mum', 'mommy', 'ma'],
    ['frere', 'brother', 'hermano', 'bruder', 'fratello', 'bro'],
    ['soeur', 'sister', 'hermana', 'schwester', 'sorella', 'sis'],
    ['fils', 'son', 'hijo', 'sohn', 'figlio'],
    ['fille', 'daughter', 'hija', 'tochter', 'figlia'],
    ['oncle', 'uncle', 'tio', 'onkel', 'zio'],
    ['tante', 'aunt', 'tia', 'tante', 'zia'],
    ['grand-pere', 'grandpere', 'grandfather', 'abuelo', 'grossvater', 'nonno', 'grandpa', 'papy', 'papi'],
    ['grand-mere', 'grandmere', 'grandmother', 'abuela', 'grossmutter', 'nonna', 'grandma', 'mamie', 'mami'],
    ['mari', 'husband', 'epoux', 'marido', 'esposo', 'ehemann', 'marito'],
    ['femme', 'wife', 'epouse', 'esposa', 'ehefrau', 'moglie'],
    ['cousin', 'cousine', 'prima', 'primo', 'kusine', 'vetter', 'cugino', 'cugina'],
    ['neveu', 'nephew', 'sobrino', 'neffe', 'nipote'],
    ['niece', 'niece', 'sobrina', 'nichte', 'nipote'],
    // Places / Housing
    ['maison', 'domicile', 'home', 'house', 'casa', 'haus', 'hogar', 'heim'],
    ['travail', 'boulot', 'work', 'job', 'trabajo', 'arbeit', 'lavoro'],
    ['ecole', 'school', 'escuela', 'schule', 'scuola'],
    ['bureau', 'office', 'oficina', 'buro', 'ufficio'],
    // Transport
    ['velo', 'bicyclette', 'bicycle', 'bike', 'bicicleta', 'fahrrad', 'bici'],
    ['voiture', 'automobile', 'car', 'auto', 'coche', 'wagen', 'macchina'],
    // Medical
    ['docteur', 'medecin', 'doctor', 'physician', 'arzt', 'medico'],
  ];

  static Set<String> _trigrams(String s) {
    final clean = s.replaceAll(_nonWordRe, '');
    if (clean.length < 3) return {clean};
    return {
      for (var i = 0; i <= clean.length - 3; i++) clean.substring(i, i + 3),
    };
  }

  /// Map of accented characters to their base Latin equivalents.
  static const _diacriticMap = <int, int>{
    // À-Å
    0xC0: 0x41, 0xC1: 0x41, 0xC2: 0x41, 0xC3: 0x41, 0xC4: 0x41, 0xC5: 0x41,
    // Æ → ae not possible with single char map, keep as-is
    0xC7: 0x43, // Ç
    // È-Ë
    0xC8: 0x45, 0xC9: 0x45, 0xCA: 0x45, 0xCB: 0x45,
    // Ì-Ï
    0xCC: 0x49, 0xCD: 0x49, 0xCE: 0x49, 0xCF: 0x49,
    0xD0: 0x44, // Ð
    0xD1: 0x4E, // Ñ
    // Ò-Ö
    0xD2: 0x4F, 0xD3: 0x4F, 0xD4: 0x4F, 0xD5: 0x4F, 0xD6: 0x4F,
    0xD8: 0x4F, // Ø
    // Ù-Ü
    0xD9: 0x55, 0xDA: 0x55, 0xDB: 0x55, 0xDC: 0x55,
    0xDD: 0x59, // Ý
    // à-å
    0xE0: 0x61, 0xE1: 0x61, 0xE2: 0x61, 0xE3: 0x61, 0xE4: 0x61, 0xE5: 0x61,
    0xE7: 0x63, // ç
    // è-ë
    0xE8: 0x65, 0xE9: 0x65, 0xEA: 0x65, 0xEB: 0x65,
    // ì-ï
    0xEC: 0x69, 0xED: 0x69, 0xEE: 0x69, 0xEF: 0x69,
    0xF0: 0x64, // ð
    0xF1: 0x6E, // ñ
    // ò-ö
    0xF2: 0x6F, 0xF3: 0x6F, 0xF4: 0x6F, 0xF5: 0x6F, 0xF6: 0x6F,
    0xF8: 0x6F, // ø
    // ù-ü
    0xF9: 0x75, 0xFA: 0x75, 0xFB: 0x75, 0xFC: 0x75,
    0xFD: 0x79, 0xFF: 0x79, // ý, ÿ
    // Extended Latin
    0x0100: 0x41, 0x0101: 0x61, // Ā ā
    0x0102: 0x41, 0x0103: 0x61, // Ă ă
    0x0104: 0x41, 0x0105: 0x61, // Ą ą
    0x0106: 0x43, 0x0107: 0x63, // Ć ć
    0x010C: 0x43, 0x010D: 0x63, // Č č
    0x010E: 0x44, 0x010F: 0x64, // Ď ď
    0x0110: 0x44, 0x0111: 0x64, // Đ đ
    0x0112: 0x45, 0x0113: 0x65, // Ē ē
    0x0118: 0x45, 0x0119: 0x65, // Ę ę
    0x011A: 0x45, 0x011B: 0x65, // Ě ě
    0x011E: 0x47, 0x011F: 0x67, // Ğ ğ
    0x0130: 0x49, 0x0131: 0x69, // İ ı
    0x0141: 0x4C, 0x0142: 0x6C, // Ł ł
    0x0143: 0x4E, 0x0144: 0x6E, // Ń ń
    0x0147: 0x4E, 0x0148: 0x6E, // Ň ň
    0x0150: 0x4F, 0x0151: 0x6F, // Ő ő
    0x0158: 0x52, 0x0159: 0x72, // Ř ř
    0x015A: 0x53, 0x015B: 0x73, // Ś ś
    0x015E: 0x53, 0x015F: 0x73, // Ş ş
    0x0160: 0x53, 0x0161: 0x73, // Š š
    0x0162: 0x54, 0x0163: 0x74, // Ţ ţ
    0x0164: 0x54, 0x0165: 0x74, // Ť ť
    0x016E: 0x55, 0x016F: 0x75, // Ů ů
    0x0170: 0x55, 0x0171: 0x75, // Ű ű
    0x0179: 0x5A, 0x017A: 0x7A, // Ź ź
    0x017B: 0x5A, 0x017C: 0x7A, // Ż ż
    0x017D: 0x5A, 0x017E: 0x7A, // Ž ž
  };
}
