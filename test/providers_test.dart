import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:droidclaw/core/providers/anthropic_provider.dart';
import 'package:droidclaw/core/providers/http_provider.dart';
import 'package:droidclaw/core/providers/llm_response.dart';

HttpProvider _httpProvider(http.Client client) => HttpProvider(
      apiKey: 'k',
      apiBase: 'https://example.test/v1',
      defaultModel: 'm',
      providerName: 'test',
      client: client,
      retryBaseDelay: Duration.zero,
    );

void main() {
  group('HttpProvider (OpenAI-compatible)', () {
    test('parses tool calls and usage from an OpenAI response', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': '',
                    'tool_calls': [
                      {
                        'id': 'c1',
                        'type': 'function',
                        'function': {
                          'name': 'web_search',
                          'arguments': '{"query":"x"}',
                        },
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
              'usage': {
                'prompt_tokens': 10,
                'completion_tokens': 5,
                'total_tokens': 15,
              },
            }),
            200,
          ));

      final r = await _httpProvider(client)
          .chat(messages: const [Message(role: 'user', content: 'hi')], model: 'm');

      expect(r.toolCalls.single.name, 'web_search');
      expect(r.toolCalls.single.arguments['query'], 'x');
      expect(r.finishReason, 'tool_calls');
      expect(r.usage?.promptTokens, 10);
      expect(r.usage?.completionTokens, 5);
    });

    test('retries on 429 then succeeds', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('rate limited', 429);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'ok'},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
        );
      });

      final r = await _httpProvider(client).chat(messages: const [], model: 'm');
      expect(r.content, 'ok');
      expect(calls, 2);
    });

    test('exhausts retries on persistent 500 and throws (3 attempts)', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('server error', 500);
      });

      await expectLater(
        _httpProvider(client).chat(messages: const [], model: 'm'),
        throwsA(isA<LLMException>()),
      );
      expect(calls, 3); // initial + 2 retries
    });
  });

  group('AnthropicProvider', () {
    test('extracts system prompt and parses content blocks', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'thinking'},
              {
                'type': 'tool_use',
                'id': 't1',
                'name': 'weather',
                'input': {'city': 'Paris'},
              },
            ],
            'stop_reason': 'tool_use',
            'usage': {'input_tokens': 3, 'output_tokens': 4},
          }),
          200,
        );
      });

      final r = await AnthropicProvider(
        apiKey: 'k',
        apiBase: 'https://anthropic.test/v1',
        client: client,
      ).chat(
        messages: const [
          Message(role: 'system', content: 'be brief'),
          Message(role: 'user', content: 'weather?'),
        ],
        model: 'claude',
      );

      // System prompt goes to the separate Anthropic `system` field.
      expect(sentBody!['system'], 'be brief');
      expect((sentBody!['messages'] as List).length, 1);
      expect(r.content, 'thinking');
      expect(r.toolCalls.single.name, 'weather');
      expect(r.toolCalls.single.arguments['city'], 'Paris');
      expect(r.finishReason, 'tool_use');
      expect(r.usage?.promptTokens, 3);
    });

    test('retries on 429 then succeeds (U16 parity with HttpProvider)',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('rate limited', 429);
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
            'stop_reason': 'end_turn',
          }),
          200,
        );
      });

      final r = await AnthropicProvider(
        apiKey: 'k',
        apiBase: 'https://a.test',
        client: client,
        retryBaseDelay: Duration.zero,
      ).chat(messages: const [], model: 'claude');

      expect(r.content, 'ok');
      expect(calls, 2);
    });

    test('exhausts retries on persistent 5xx and throws LLMException',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('overloaded', 529);
      });

      await expectLater(
        AnthropicProvider(
          apiKey: 'k',
          apiBase: 'https://a.test',
          client: client,
          retryBaseDelay: Duration.zero,
        ).chat(messages: const [], model: 'claude'),
        throwsA(isA<LLMException>()
            .having((e) => e.statusCode, 'statusCode', 529)),
      );
      expect(calls, 3); // initial + 2 retries
    });
  });
}
