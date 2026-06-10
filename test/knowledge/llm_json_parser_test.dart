// ignore_for_file: depend_on_referenced_packages

// U17: tests for the shared LLM JSON parser that replaced the fence-strip
// blocks previously re-implemented in kb_maintenance_service.dart (4 sites)
// and entity_extractor.dart.

import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/services/llm_json_parser.dart';

void main() {
  group('stripFences', () {
    test('strips ```json fences', () {
      expect(
        LlmJsonParser.stripFences('```json\n{"a":1}\n```'),
        '{"a":1}',
      );
    });

    test('strips bare ``` fences', () {
      expect(LlmJsonParser.stripFences('```\n[1,2]\n```'), '[1,2]');
    });

    test('strips fence without trailing newline before closer', () {
      expect(LlmJsonParser.stripFences('```json\n{"a":1}```'), '{"a":1}');
    });

    test('trims surrounding whitespace', () {
      expect(LlmJsonParser.stripFences('  {"a":1}\n'), '{"a":1}');
    });

    test('leaves unfenced content untouched', () {
      expect(LlmJsonParser.stripFences('{"a":1}'), '{"a":1}');
    });

    test('does not touch fences in the middle of content', () {
      const content = '{"text":"use ``` for code"}';
      expect(LlmJsonParser.stripFences(content), content);
    });
  });

  group('decodeObject (throwing variant — parseCleanupResponse behavior)', () {
    test('decodes a plain JSON object', () {
      expect(LlmJsonParser.decodeObject('{"pairs":[]}'), {'pairs': []});
    });

    test('decodes a fenced JSON object', () {
      expect(
        LlmJsonParser.decodeObject('```json\n{"operations":[],"summary":"ok"}\n```'),
        {'operations': [], 'summary': 'ok'},
      );
    });

    test('throws on malformed JSON', () {
      expect(
        () => LlmJsonParser.decodeObject('not json at all'),
        throwsFormatException,
      );
    });

    test('throws when top-level is not an object', () {
      expect(() => LlmJsonParser.decodeObject('[1,2,3]'), throwsA(anything));
    });
  });

  group('tryDecodeObject (null on malformed, never throws)', () {
    test('decodes plain and fenced objects', () {
      expect(LlmJsonParser.tryDecodeObject('{"a":1}'), {'a': 1});
      expect(
        LlmJsonParser.tryDecodeObject('```json\n{"a":1}\n```'),
        {'a': 1},
      );
    });

    test('returns null on malformed JSON', () {
      expect(LlmJsonParser.tryDecodeObject('{"a":'), isNull);
      expect(LlmJsonParser.tryDecodeObject('garbage'), isNull);
      expect(LlmJsonParser.tryDecodeObject(''), isNull);
    });

    test('returns null when top-level is not an object', () {
      expect(LlmJsonParser.tryDecodeObject('[1,2]'), isNull);
      expect(LlmJsonParser.tryDecodeObject('"str"'), isNull);
    });
  });

  group('tryDecodeList (null on malformed, never throws)', () {
    test('decodes plain and fenced lists', () {
      expect(LlmJsonParser.tryDecodeList('[1,2]'), [1, 2]);
      expect(LlmJsonParser.tryDecodeList('```json\n["a"]\n```'), ['a']);
    });

    test('returns null on malformed JSON', () {
      expect(LlmJsonParser.tryDecodeList('[1,'), isNull);
      expect(LlmJsonParser.tryDecodeList(''), isNull);
    });

    test('returns null when top-level is not a list', () {
      expect(LlmJsonParser.tryDecodeList('{"a":1}'), isNull);
    });
  });
}
