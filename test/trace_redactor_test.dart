// ignore_for_file: depend_on_referenced_packages

import 'package:test/test.dart';

import 'package:droidclaw/core/config/trace_redactor.dart';

void main() {
  group('TraceRedactor.redactText', () {
    test('redacts email addresses', () {
      final out = TraceRedactor.redactText('contact me at jane.doe@example.com please');
      expect(out, isNot(contains('jane.doe@example.com')));
      expect(out, contains('[redacted-email]'));
    });

    test('redacts phone numbers', () {
      final out = TraceRedactor.redactText('call +33 6 12 34 56 78 tomorrow');
      expect(out, isNot(contains('12 34 56 78')));
      expect(out, contains('[redacted-phone]'));
    });

    test('redacts bearer tokens and token params', () {
      expect(
        TraceRedactor.redactText('Authorization: Bearer abc123.def-456'),
        isNot(contains('abc123.def-456')),
      );
      expect(
        TraceRedactor.redactText('url?token=sekret_value&x=1'),
        isNot(contains('sekret_value')),
      );
    });

    test('redacts known API key prefixes', () {
      final out =
          TraceRedactor.redactText('key sk-ABCDEFGH12345678 and AIzaSyABCDEFGH12345');
      expect(out, isNot(contains('sk-ABCDEFGH12345678')));
      expect(out, isNot(contains('AIzaSyABCDEFGH12345')));
      expect(out, contains('[redacted-key]'));
    });

    test('redacts the injected knowledge_context block', () {
      final out = TraceRedactor.redactText(
          'You are an assistant.\n<knowledge_context data-only="true">\nUser address: 9 rue la Paix\n</knowledge_context>\nEnd.');
      expect(out, isNot(contains('9 rue la Paix')));
      expect(out, contains('<knowledge_context>[redacted]</knowledge_context>'));
    });

    test('redacts an unterminated knowledge_context block (truncated preview)', () {
      final out = TraceRedactor.redactText(
          'prefix <knowledge_context>User secret fact about hea');
      expect(out, isNot(contains('secret fact')));
    });

    test('preserves non-sensitive content', () {
      const weather = 'The weather in Paris is 18C and sunny.';
      expect(TraceRedactor.redactText(weather), weather);
    });

    test('is idempotent', () {
      const input = 'mail a@b.com and call +1 555 123 4567';
      final once = TraceRedactor.redactText(input);
      final twice = TraceRedactor.redactText(once);
      expect(twice, once);
    });
  });

  group('TraceRedactor.redactTraceJson', () {
    test('wholesale-redacts sensitive tool-role message previews', () {
      final json = {
        'messages': [
          {
            'role': 'tool',
            'toolName': 'contacts',
            'contentLength': 120,
            'preview': 'Jane Doe, +33 6 12 34 56 78, jane@example.com',
          },
        ],
      };
      final out = TraceRedactor.redactTraceJson(json);
      final msg = (out['messages'] as List).first as Map;
      expect(msg['preview'], '[redacted: contacts result]');
      expect(msg['preview'].toString(), isNot(contains('jane@example.com')));
    });

    test('pattern-redacts non-sensitive tool previews but keeps structure', () {
      final json = {
        'messages': [
          {
            'role': 'tool',
            'toolName': 'weather',
            'contentLength': 40,
            'preview': 'Paris 18C. Support: help@vendor.com',
          },
        ],
      };
      final out = TraceRedactor.redactTraceJson(json);
      final msg = (out['messages'] as List).first as Map;
      expect(msg['preview'].toString(), contains('Paris 18C'));
      expect(msg['preview'].toString(), isNot(contains('help@vendor.com')));
    });

    test('redacts PII already present in prior session-history messages', () {
      final json = {
        'messages': [
          {'role': 'user', 'contentLength': 10, 'preview': 'what is my address?'},
          {
            'role': 'tool',
            'toolName': 'kb_query',
            'contentLength': 30,
            'preview': 'address: 9 rue la Paix, Paris',
          },
        ],
      };
      final out = TraceRedactor.redactTraceJson(json);
      final toolMsg = (out['messages'] as List)[1] as Map;
      expect(toolMsg['preview'], '[redacted: kb_query result]');
    });

    test('redacts systemPromptPreview and responseContent', () {
      final json = {
        'systemPromptPreview':
            'Assistant.\n<knowledge_context>fact: phone +1 555 867 5309</knowledge_context>',
        'responseContent': 'Your token=abc.def123 is set',
      };
      final out = TraceRedactor.redactTraceJson(json);
      expect(out['systemPromptPreview'].toString(), isNot(contains('555 867 5309')));
      expect(out['responseContent'].toString(), isNot(contains('abc.def123')));
    });
  });
}
