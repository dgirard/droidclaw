import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:droidclaw/core/providers/embedding_provider.dart';
import 'package:droidclaw/core/providers/gemini_embedding_provider.dart';
import 'package:droidclaw/core/providers/openai_embedding_provider.dart';
import 'package:droidclaw/shared/constants.dart';

/// `BaseCloudEmbeddingProvider` constructs its own `http.Client()` (no
/// constructor seam). package:http's zone-based `runWithClient` makes the
/// `http.Client()` factory return the mock during construction, so no
/// production change is needed.
T _withClient<T>(http.Client client, T Function() body) =>
    http.runWithClient(body, () => client);

OpenAIEmbeddingProvider _openAI(http.Client client,
        {String apiBase = 'https://api.test/v1'}) =>
    _withClient(
      client,
      () => OpenAIEmbeddingProvider(
        apiKey: 'test-key',
        apiBase: apiBase,
        dimensions: 4,
        providerId: 'openai',
      ),
    );

GeminiEmbeddingProvider _gemini(http.Client client) => _withClient(
      client,
      () => GeminiEmbeddingProvider(
        apiKey: 'test-key',
        apiBase: AppConstants.geminiEmbeddingApiBase,
        dimensions: 4,
      ),
    );

String _openAIBody(List<List<double>> embeddings, {int? promptTokens}) =>
    jsonEncode({
      'data': [
        for (var i = 0; i < embeddings.length; i++)
          {'index': i, 'embedding': embeddings[i]},
      ],
      if (promptTokens != null) 'usage': {'prompt_tokens': promptTokens},
    });

void main() {
  group('BaseCloudEmbeddingProvider retry', () {
    test('429 then 200 — one retry then success', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('rate limited', 429);
        return http.Response(
          _openAIBody([
            [0.1, 0.2, 0.3, 0.4]
          ]),
          200,
        );
      });

      final result = await _openAI(client)
          .embed(texts: ['hello'], model: 'text-embedding-3-small');

      expect(calls, 2);
      expect(result.embeddings.single, [0.1, 0.2, 0.3, 0.4]);
    });

    test('persistent 5xx exhausts retries and throws (3 attempts)', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('server error', 503);
      });

      await expectLater(
        _openAI(client).embed(texts: ['x'], model: 'm'),
        throwsA(isA<HttpRetryException>()),
      );
      expect(calls, 3); // initial + 2 retries
    });

    test('non-retriable 400 throws immediately without retrying', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('bad request', 400);
      });

      await expectLater(
        _openAI(client).embed(texts: ['x'], model: 'm'),
        throwsA(isA<EmbeddingApiException>()),
      );
      expect(calls, 1);
    });
  });

  group('GeminiEmbeddingProvider', () {
    test(
        'single embed hits the native REST endpoint (NOT the OpenAI-compatible one) '
        'with model + dimensions, and parses the response', () async {
      http.Request? sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode({
            'embedding': {
              'values': [0.5, 0.25, 0.0, -0.5]
            }
          }),
          200,
        );
      });

      final result = await _gemini(client).embed(
        texts: ['hello world'],
        model: 'gemini-embedding-001',
        dimensions: 4,
        taskType: 'RETRIEVAL_QUERY',
      );

      // Native Gemini REST API, not the OpenAI-compatible wrapper.
      expect(sent!.url.host, 'generativelanguage.googleapis.com');
      expect(sent!.url.path, contains('/v1beta/'));
      expect(sent!.url.path,
          endsWith('/models/gemini-embedding-001:embedContent'));
      expect(sent!.url.path, isNot(contains('/embeddings')));
      expect(sent!.url.path, isNot(contains('/chat/completions')));

      // Auth via x-goog-api-key, not Bearer token.
      expect(sent!.headers['x-goog-api-key'], 'test-key');
      expect(sent!.headers.containsKey('Authorization'), isFalse);

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['output_dimensionality'], 4);
      expect(body['taskType'], 'RETRIEVAL_QUERY');
      expect(body['content']['parts'][0]['text'], 'hello world');

      expect(result.embeddings.single, [0.5, 0.25, 0.0, -0.5]);
    });

    test('batch embed uses batchEmbedContents and parses every vector',
        () async {
      http.Request? sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode({
            'embeddings': [
              {
                'values': [1.0, 0.0]
              },
              {
                'values': [0.0, 1.0]
              },
            ]
          }),
          200,
        );
      });

      final result = await _gemini(client).embed(
        texts: ['a', 'b'],
        model: 'gemini-embedding-001',
        dimensions: 2,
      );

      expect(sent!.url.path,
          endsWith('/models/gemini-embedding-001:batchEmbedContents'));

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      final requests = body['requests'] as List;
      expect(requests, hasLength(2));
      // Batch requests carry the fully-qualified model name per item.
      expect(requests[0]['model'], 'models/gemini-embedding-001');
      expect(requests[0]['output_dimensionality'], 2);
      expect(requests[1]['content']['parts'][0]['text'], 'b');

      expect(result.embeddings, [
        [1.0, 0.0],
        [0.0, 1.0],
      ]);
    });
  });

  group('OpenAIEmbeddingProvider', () {
    test('request shape: /embeddings endpoint, Bearer auth, model + dimensions',
        () async {
      http.Request? sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(
          _openAIBody([
            [0.1, 0.2]
          ]),
          200,
        );
      });

      await _openAI(client).embed(
        texts: ['only one'],
        model: 'text-embedding-3-small',
        dimensions: 2,
      );

      expect(sent!.url.toString(), 'https://api.test/v1/embeddings');
      expect(sent!.headers['Authorization'], 'Bearer test-key');

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['model'], 'text-embedding-3-small');
      // Single text is sent as a plain string, not a one-element list.
      expect(body['input'], 'only one');
      expect(body['dimensions'], 2);
      expect(body['encoding_format'], 'float');
    });

    test('response parsing: sorts by index and surfaces usage', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'data': [
                // Deliberately out of order — the provider must re-sort.
                {
                  'index': 1,
                  'embedding': [0.0, 1.0]
                },
                {
                  'index': 0,
                  'embedding': [1.0, 0.0]
                },
              ],
              'usage': {'prompt_tokens': 7},
            }),
            200,
          ));

      final result = await _openAI(client).embed(
        texts: ['first', 'second'],
        model: 'm',
      );

      expect(result.embeddings, [
        [1.0, 0.0],
        [0.0, 1.0],
      ]);
      expect(result.promptTokens, 7);
    });

    test('batch input is sent as a list', () async {
      http.Request? sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(
          _openAIBody([
            [1.0],
            [2.0]
          ]),
          200,
        );
      });

      await _openAI(client).embed(texts: ['a', 'b'], model: 'm');

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['input'], ['a', 'b']);
    });
  });
}
