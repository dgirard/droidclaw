/// Date parsing, comparison, and merging for KB entity deduplication.
///
/// Handles multiple formats (ISO, FR, EN, partial) and computes
/// compatibility between date facts. Two dates with different days
/// are always a conflict — never merged.
class DateSimilarity {
  /// Parse a date string into a [ParsedDate].
  ///
  /// Supports:
  /// - ISO: "2026-03-14", "2026-03"
  /// - FR: "14 mars 2026", "14/03/2026", "mars 2026"
  /// - EN: "March 14, 2026", "March 2026", "14 March 2026"
  /// - Year only: "1986"
  /// - Partial: "mars 2026" → day=null
  static ParsedDate? parse(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    // ISO: 2026-03-14 or 2026-03
    final iso = RegExp(r'^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?$').firstMatch(s);
    if (iso != null) {
      return ParsedDate(
        year: int.parse(iso.group(1)!),
        month: int.parse(iso.group(2)!),
        day: iso.group(3) != null ? int.parse(iso.group(3)!) : null,
        original: s,
      );
    }

    // dd/mm/yyyy or dd-mm-yyyy
    final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(s);
    if (dmy != null) {
      return ParsedDate(
        day: int.parse(dmy.group(1)!),
        month: int.parse(dmy.group(2)!),
        year: int.parse(dmy.group(3)!),
        original: s,
      );
    }

    // mm/dd/yyyy is ambiguous — we favor dd/mm/yyyy (FR context)
    // But handle yyyy/mm/dd
    final ymd = RegExp(r'^(\d{4})[/.](\d{1,2})[/.](\d{1,2})$').firstMatch(s);
    if (ymd != null) {
      return ParsedDate(
        year: int.parse(ymd.group(1)!),
        month: int.parse(ymd.group(2)!),
        day: int.parse(ymd.group(3)!),
        original: s,
      );
    }

    // "14 mars 2026", "mars 2026", "14 March 2026", "March 14, 2026"
    final lower = _normalize(s);

    // Try: day month year
    final dmyText = RegExp(r'^(\d{1,2})\s+([a-zàâäéèêëïîôùûüçñß]+)\s+(\d{4})$').firstMatch(lower);
    if (dmyText != null) {
      final month = _monthFromName(dmyText.group(2)!);
      if (month != null) {
        return ParsedDate(
          day: int.parse(dmyText.group(1)!),
          month: month,
          year: int.parse(dmyText.group(3)!),
          original: s,
        );
      }
    }

    // Try: month day, year (EN: "March 14, 2026")
    final mdyText = RegExp(r'^([a-zàâäéèêëïîôùûüçñß]+)\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(lower);
    if (mdyText != null) {
      final month = _monthFromName(mdyText.group(1)!);
      if (month != null) {
        return ParsedDate(
          day: int.parse(mdyText.group(2)!),
          month: month,
          year: int.parse(mdyText.group(3)!),
          original: s,
        );
      }
    }

    // Try: month year ("mars 2026", "March 2026")
    final myText = RegExp(r'^([a-zàâäéèêëïîôùûüçñß]+)\s+(\d{4})$').firstMatch(lower);
    if (myText != null) {
      final month = _monthFromName(myText.group(1)!);
      if (month != null) {
        return ParsedDate(
          month: month,
          year: int.parse(myText.group(2)!),
          original: s,
        );
      }
    }

    // Year only: "1986"
    final yearOnly = RegExp(r'^(\d{4})$').firstMatch(s);
    if (yearOnly != null) {
      return ParsedDate(
        year: int.parse(yearOnly.group(1)!),
        original: s,
      );
    }

    return null; // Unparseable
  }

  /// Compare two parsed dates.
  ///
  /// Rules:
  /// - identical: all non-null fields match
  /// - compatible: one is a subset of the other (1986 ⊂ 14/03/1986)
  /// - conflict: any non-null fields disagree (different days = always conflict)
  static DateComparison compare(ParsedDate a, ParsedDate b) {
    // Check conflicts on each field (only when both non-null)
    if (a.year != null && b.year != null && a.year != b.year) {
      return DateComparison.conflict;
    }
    if (a.month != null && b.month != null && a.month != b.month) {
      return DateComparison.conflict;
    }
    if (a.day != null && b.day != null && a.day != b.day) {
      return DateComparison.conflict;
    }

    // Check if identical (same precision and values)
    if (a.year == b.year && a.month == b.month && a.day == b.day) {
      return DateComparison.identical;
    }

    // One is more precise than the other → compatible
    return DateComparison.compatible;
  }

  /// Merge two dates by keeping the most precise non-conflicting values.
  ///
  /// Returns null on conflict (never merges conflicting dates).
  static ParsedDate? merge(ParsedDate a, ParsedDate b) {
    final cmp = compare(a, b);
    if (cmp == DateComparison.conflict) return null;
    if (cmp == DateComparison.identical) return a.precision >= b.precision ? a : b;

    // Compatible: take the more precise one
    return a.precision >= b.precision ? a : b;
  }

  /// Score the similarity between two date fact values.
  ///
  /// Returns:
  /// - 1.0 for identical dates
  /// - 0.7 for compatible dates (one is subset of the other)
  /// - -0.3 for conflicting dates (penalty — evidence of non-duplicate)
  /// - 0.0 if either date is unparseable
  static double score(String valueA, String valueB) {
    final a = parse(valueA);
    final b = parse(valueB);
    if (a == null || b == null) return 0.0;

    switch (compare(a, b)) {
      case DateComparison.identical:
        return 1.0;
      case DateComparison.compatible:
        return 0.7;
      case DateComparison.conflict:
        return -0.3;
    }
  }

  // -- Private helpers --

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[,.]'), '').trim();
  }

  static int? _monthFromName(String name) {
    return _monthNames[name];
  }

  static const _monthNames = <String, int>{
    // FR
    'janvier': 1, 'fevrier': 2, 'février': 2, 'mars': 3, 'avril': 4,
    'mai': 5, 'juin': 6, 'juillet': 7, 'aout': 8, 'août': 8,
    'septembre': 9, 'octobre': 10, 'novembre': 11, 'decembre': 12, 'décembre': 12,
    // EN
    'january': 1, 'february': 2, 'march': 3, 'april': 4,
    'may': 5, 'june': 6, 'july': 7, 'august': 8,
    'september': 9, 'october': 10, 'november': 11, 'december': 12,
    // EN short
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    // FR short
    'janv': 1, 'fev': 2, 'fév': 2, 'avr': 4, 'juil': 7,
    'sept': 9, 'déc': 12,
    // ES
    'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4,
    'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
    'septiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
    // DE
    'januar': 1, 'februar': 2, 'marz': 3, 'märz': 3,
    'juni': 6, 'juli': 7, 'oktober': 10, 'dezember': 12,
    // IT
    'gennaio': 1, 'febbraio': 2, 'aprile': 4,
    'maggio': 5, 'giugno': 6, 'luglio': 7,
    'settembre': 9, 'ottobre': 10, 'dicembre': 12,
  };
}

/// A parsed date with optional year, month, day.
class ParsedDate {
  final int? year;
  final int? month;
  final int? day;
  final String original;

  const ParsedDate({
    this.year,
    this.month,
    this.day,
    required this.original,
  });

  /// Precision level: 0=unknown, 1=year, 2=month, 3=day.
  int get precision {
    if (day != null) return 3;
    if (month != null) return 2;
    if (year != null) return 1;
    return 0;
  }

  @override
  String toString() => 'ParsedDate($year-$month-$day "$original")';

  @override
  bool operator ==(Object other) =>
      other is ParsedDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Result of comparing two dates.
enum DateComparison {
  /// All non-null fields match with same precision.
  identical,

  /// One date is a subset of the other (e.g., "1986" ⊂ "14/03/1986").
  compatible,

  /// Non-null fields disagree — never merge.
  conflict,
}
