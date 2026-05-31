// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/algorithms/date_similarity.dart';

void main() {
  group('DateSimilarity.parse', () {
    test('ISO full: 2026-03-14', () {
      final d = DateSimilarity.parse('2026-03-14');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 3);
      expect(d.day, 14);
      expect(d.precision, 3);
    });

    test('ISO partial: 2026-03', () {
      final d = DateSimilarity.parse('2026-03');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 3);
      expect(d.day, isNull);
      expect(d.precision, 2);
    });

    test('FR slash: 14/03/2026', () {
      final d = DateSimilarity.parse('14/03/2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('FR dot: 14.03.2026', () {
      final d = DateSimilarity.parse('14.03.2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('FR dash: 14-03-2026', () {
      final d = DateSimilarity.parse('14-03-2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('FR text full: 14 mars 2026', () {
      final d = DateSimilarity.parse('14 mars 2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('FR text partial: mars 2026', () {
      final d = DateSimilarity.parse('mars 2026');
      expect(d, isNotNull);
      expect(d!.month, 3);
      expect(d.year, 2026);
      expect(d.day, isNull);
      expect(d.precision, 2);
    });

    test('FR accented: 14 février 2026', () {
      final d = DateSimilarity.parse('14 février 2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 2);
      expect(d.year, 2026);
    });

    test('FR accented: 15 août 1986', () {
      final d = DateSimilarity.parse('15 août 1986');
      expect(d, isNotNull);
      expect(d!.day, 15);
      expect(d.month, 8);
      expect(d.year, 1986);
    });

    test('FR accented: décembre 2025', () {
      final d = DateSimilarity.parse('décembre 2025');
      expect(d, isNotNull);
      expect(d!.month, 12);
      expect(d.year, 2025);
      expect(d.day, isNull);
    });

    test('EN text: March 14, 2026', () {
      final d = DateSimilarity.parse('March 14, 2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('EN text: 14 March 2026', () {
      final d = DateSimilarity.parse('14 March 2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('EN text partial: March 2026', () {
      final d = DateSimilarity.parse('March 2026');
      expect(d, isNotNull);
      expect(d!.month, 3);
      expect(d.year, 2026);
      expect(d.day, isNull);
    });

    test('ES text: 14 marzo 2026', () {
      final d = DateSimilarity.parse('14 marzo 2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('DE text: 14 März 2026', () {
      final d = DateSimilarity.parse('14 März 2026');
      expect(d, isNotNull);
      expect(d!.day, 14);
      expect(d.month, 3);
      expect(d.year, 2026);
    });

    test('Year only: 1986', () {
      final d = DateSimilarity.parse('1986');
      expect(d, isNotNull);
      expect(d!.year, 1986);
      expect(d.month, isNull);
      expect(d.day, isNull);
      expect(d.precision, 1);
    });

    test('Unparseable returns null', () {
      expect(DateSimilarity.parse(''), isNull);
      expect(DateSimilarity.parse('bientôt'), isNull);
      expect(DateSimilarity.parse('la semaine dernière'), isNull);
      expect(DateSimilarity.parse('42'), isNull); // too short for year
    });

    test('EN short months: Jan, Feb, Sep', () {
      expect(DateSimilarity.parse('14 Jan 2026')?.month, 1);
      expect(DateSimilarity.parse('Feb 2026')?.month, 2);
      expect(DateSimilarity.parse('Sep 14, 2026')?.month, 9);
    });
  });

  group('DateSimilarity.compare', () {
    test('Identical: same full dates', () {
      final a = DateSimilarity.parse('14/03/2026')!;
      final b = DateSimilarity.parse('2026-03-14')!;
      expect(DateSimilarity.compare(a, b), DateComparison.identical);
    });

    test('Identical: same partial dates (month+year)', () {
      final a = DateSimilarity.parse('mars 2026')!;
      final b = DateSimilarity.parse('March 2026')!;
      expect(DateSimilarity.compare(a, b), DateComparison.identical);
    });

    test('Identical: same year only', () {
      final a = DateSimilarity.parse('1986')!;
      final b = DateSimilarity.parse('1986')!;
      expect(DateSimilarity.compare(a, b), DateComparison.identical);
    });

    test('Compatible: year ⊂ full date', () {
      final a = DateSimilarity.parse('1986')!;
      final b = DateSimilarity.parse('14/03/1986')!;
      expect(DateSimilarity.compare(a, b), DateComparison.compatible);
    });

    test('Compatible: month+year ⊂ full date', () {
      final a = DateSimilarity.parse('mars 1986')!;
      final b = DateSimilarity.parse('14 mars 1986')!;
      expect(DateSimilarity.compare(a, b), DateComparison.compatible);
    });

    test('Compatible: year ⊂ month+year', () {
      final a = DateSimilarity.parse('1986')!;
      final b = DateSimilarity.parse('mars 1986')!;
      expect(DateSimilarity.compare(a, b), DateComparison.compatible);
    });

    test('Conflict: different days — NEVER merge', () {
      final a = DateSimilarity.parse('14/03/2026')!;
      final b = DateSimilarity.parse('15/03/2026')!;
      expect(DateSimilarity.compare(a, b), DateComparison.conflict);
    });

    test('Conflict: different months', () {
      final a = DateSimilarity.parse('14/03/2026')!;
      final b = DateSimilarity.parse('14/04/2026')!;
      expect(DateSimilarity.compare(a, b), DateComparison.conflict);
    });

    test('Conflict: different years', () {
      final a = DateSimilarity.parse('1985')!;
      final b = DateSimilarity.parse('1986')!;
      expect(DateSimilarity.compare(a, b), DateComparison.conflict);
    });

    test('Conflict: 14 mars 1985 vs 14 mars 1986', () {
      final a = DateSimilarity.parse('14 mars 1985')!;
      final b = DateSimilarity.parse('14 mars 1986')!;
      expect(DateSimilarity.compare(a, b), DateComparison.conflict);
    });

    test('Conflict: same day+month but different year', () {
      final a = DateSimilarity.parse('14/03/2025')!;
      final b = DateSimilarity.parse('14/03/2026')!;
      expect(DateSimilarity.compare(a, b), DateComparison.conflict);
    });
  });

  group('DateSimilarity.merge', () {
    test('Identical → returns date', () {
      final a = DateSimilarity.parse('2026-03-14')!;
      final b = DateSimilarity.parse('14/03/2026')!;
      final merged = DateSimilarity.merge(a, b);
      expect(merged, isNotNull);
      expect(merged!.day, 14);
      expect(merged.month, 3);
      expect(merged.year, 2026);
    });

    test('Compatible: keeps the more precise date', () {
      final partial = DateSimilarity.parse('mars 1986')!;
      final full = DateSimilarity.parse('14 mars 1986')!;
      final merged = DateSimilarity.merge(partial, full);
      expect(merged, isNotNull);
      expect(merged!.day, 14);
      expect(merged.month, 3);
      expect(merged.year, 1986);
    });

    test('Compatible: year + full date → keeps full', () {
      final year = DateSimilarity.parse('1986')!;
      final full = DateSimilarity.parse('14/03/1986')!;
      final merged = DateSimilarity.merge(year, full);
      expect(merged, isNotNull);
      expect(merged!.day, 14);
      expect(merged.month, 3);
      expect(merged.year, 1986);
    });

    test('Compatible: merge order does not matter', () {
      final a = DateSimilarity.parse('1986')!;
      final b = DateSimilarity.parse('14 mars 1986')!;
      final m1 = DateSimilarity.merge(a, b);
      final m2 = DateSimilarity.merge(b, a);
      expect(m1, isNotNull);
      expect(m2, isNotNull);
      expect(m1!.day, m2!.day);
      expect(m1.month, m2.month);
      expect(m1.year, m2.year);
    });

    test('Conflict: different days → returns null (NEVER merge)', () {
      final a = DateSimilarity.parse('14/03/2026')!;
      final b = DateSimilarity.parse('15/03/2026')!;
      expect(DateSimilarity.merge(a, b), isNull);
    });

    test('Conflict: different years → returns null', () {
      final a = DateSimilarity.parse('1985')!;
      final b = DateSimilarity.parse('1986')!;
      expect(DateSimilarity.merge(a, b), isNull);
    });

    test('Conflict: different months → returns null', () {
      final a = DateSimilarity.parse('mars 2026')!;
      final b = DateSimilarity.parse('avril 2026')!;
      expect(DateSimilarity.merge(a, b), isNull);
    });
  });

  group('DateSimilarity.score', () {
    test('Identical dates → 1.0', () {
      expect(DateSimilarity.score('2026-03-14', '14/03/2026'), 1.0);
      expect(DateSimilarity.score('mars 2026', 'March 2026'), 1.0);
      expect(DateSimilarity.score('1986', '1986'), 1.0);
    });

    test('Compatible dates → 0.7', () {
      expect(DateSimilarity.score('1986', '14/03/1986'), 0.7);
      expect(DateSimilarity.score('mars 1986', '14 mars 1986'), 0.7);
      expect(DateSimilarity.score('1986', 'mars 1986'), 0.7);
    });

    test('Conflicting dates → -0.3', () {
      expect(DateSimilarity.score('14/03/2026', '15/03/2026'), -0.3);
      expect(DateSimilarity.score('1985', '1986'), -0.3);
      expect(DateSimilarity.score('mars 2026', 'avril 2026'), -0.3);
    });

    test('Unparseable → 0.0', () {
      expect(DateSimilarity.score('bientôt', '2026-03-14'), 0.0);
      expect(DateSimilarity.score('2026-03-14', 'hier'), 0.0);
      expect(DateSimilarity.score('foo', 'bar'), 0.0);
    });
  });

  group('Real-world KB dedup scenarios', () {
    test('Same birthday, different formats → identical, merge', () {
      // Entity A: "anniversaire: 14 mars 1986"
      // Entity B: "anniversaire: 1986-03-14"
      final score = DateSimilarity.score('14 mars 1986', '1986-03-14');
      expect(score, 1.0);

      final merged = DateSimilarity.merge(
        DateSimilarity.parse('14 mars 1986')!,
        DateSimilarity.parse('1986-03-14')!,
      );
      expect(merged, isNotNull);
      expect(merged!.day, 14);
    });

    test('Partial birthday enriched → compatible, keep precise', () {
      // Entity A: "né en: 1986"
      // Entity B: "né le: 14/03/1986"
      final score = DateSimilarity.score('1986', '14/03/1986');
      expect(score, 0.7);

      final merged = DateSimilarity.merge(
        DateSimilarity.parse('1986')!,
        DateSimilarity.parse('14/03/1986')!,
      );
      expect(merged, isNotNull);
      expect(merged!.day, 14);
      expect(merged.month, 3);
      expect(merged.year, 1986);
    });

    test('Different birthdays → conflict, evidence of different people', () {
      // Entity A: "né le: 14 mars 1985"
      // Entity B: "né le: 14 mars 1986"
      final score = DateSimilarity.score('14 mars 1985', '14 mars 1986');
      expect(score, -0.3);
      expect(
        DateSimilarity.merge(
          DateSimilarity.parse('14 mars 1985')!,
          DateSimilarity.parse('14 mars 1986')!,
        ),
        isNull,
      );
    });

    test('Same event different day → conflict, NEVER merge', () {
      // Entity A: "rdv: 14/03/2026"
      // Entity B: "rdv: 15/03/2026"
      final score = DateSimilarity.score('14/03/2026', '15/03/2026');
      expect(score, -0.3);
      expect(
        DateSimilarity.merge(
          DateSimilarity.parse('14/03/2026')!,
          DateSimilarity.parse('15/03/2026')!,
        ),
        isNull,
      );
    });

    test('Cross-language same date → identical', () {
      // FR vs EN vs ES for same date
      final fr = DateSimilarity.parse('14 mars 2026')!;
      final en = DateSimilarity.parse('March 14, 2026')!;
      final es = DateSimilarity.parse('14 marzo 2026')!;

      expect(DateSimilarity.compare(fr, en), DateComparison.identical);
      expect(DateSimilarity.compare(fr, es), DateComparison.identical);
      expect(DateSimilarity.compare(en, es), DateComparison.identical);
    });

    test('Multilingual month partial → identical', () {
      final fr = DateSimilarity.parse('mars 2026')!;
      final en = DateSimilarity.parse('March 2026')!;
      expect(DateSimilarity.compare(fr, en), DateComparison.identical);
    });

    test('Score summary for all comparison types', () {
      final cases = <String, List<String>>{
        'Identical (full)': ['14/03/2026', '2026-03-14'],
        'Identical (partial)': ['mars 2026', 'March 2026'],
        'Compatible (year→full)': ['1986', '14/03/1986'],
        'Compatible (month→full)': ['mars 1986', '14 mars 1986'],
        'Conflict (diff day)': ['14/03/2026', '15/03/2026'],
        'Conflict (diff month)': ['mars 2026', 'avril 2026'],
        'Conflict (diff year)': ['1985', '1986'],
        'Unparseable': ['bientôt', '2026-03-14'],
      };

      for (final entry in cases.entries) {
        final s = DateSimilarity.score(entry.value[0], entry.value[1]);
        print('${entry.key.padRight(28)} '
            '${entry.value[0].padRight(14)} vs ${entry.value[1].padRight(14)} '
            '→ score=$s');
      }
    });
  });
}
