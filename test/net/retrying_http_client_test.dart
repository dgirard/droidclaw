import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:droidclaw/core/net/retrying_http_client.dart';
import 'package:droidclaw/shared/constants.dart';

void main() {
  group('RetryingHttpClient', () {
    test('429 then 200: retries once with backoff and succeeds', () async {
      var calls = 0;
      final delays = <Duration>[];
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response('rate limited', 429);
          return http.Response('ok', 200);
        }),
        delay: (d) async => delays.add(d),
      );

      final response = await client.get(Uri.parse('https://x.test/'));

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      expect(calls, 2);
      expect(delays, [
        const Duration(milliseconds: AppConstants.httpRetryBaseDelayMs),
      ]);
    });

    test('persistent 500: exhausts retries with exponential backoff and '
        'returns the final response (consumer decides how to fail)', () async {
      var calls = 0;
      final delays = <Duration>[];
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          return http.Response('server error', 500);
        }),
        delay: (d) async => delays.add(d),
      );

      final response = await client.post(Uri.parse('https://x.test/'),
          body: '{}');

      expect(response.statusCode, 500);
      expect(calls, 3); // initial + httpMaxRetries (2)
      expect(delays, [
        const Duration(milliseconds: AppConstants.httpRetryBaseDelayMs),
        const Duration(milliseconds: AppConstants.httpRetryBaseDelayMs * 2),
      ]);
    });

    test('non-transient status (404) is returned without retry', () async {
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          return http.Response('nope', 404);
        }),
        delay: (_) async {},
      );

      final response = await client.get(Uri.parse('https://x.test/'));

      expect(response.statusCode, 404);
      expect(calls, 1);
    });

    test('shouldRetry predicate triggers retry on otherwise-final response',
        () async {
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          return http.Response(calls == 1 ? '{"choices":[]}' : '{"choices":[1]}', 200);
        }),
        shouldRetry: (r) => r.body.contains('"choices":[]'),
        delay: (_) async {},
      );

      final response = await client.get(Uri.parse('https://x.test/'));

      expect(calls, 2);
      expect(response.body, '{"choices":[1]}');
    });

    test('shouldRetry predicate exhausts retries and returns final response',
        () async {
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          return http.Response('{"choices":[]}', 200);
        }),
        shouldRetry: (r) => true,
        delay: (_) async {},
      );

      final response = await client.get(Uri.parse('https://x.test/'));

      expect(calls, 3);
      expect(response.statusCode, 200);
    });

    test('honors Retry-After header (seconds) over computed backoff',
        () async {
      var calls = 0;
      final delays = <Duration>[];
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          if (calls == 1) {
            return http.Response('slow down', 429,
                headers: {'retry-after': '7'});
          }
          return http.Response('ok', 200);
        }),
        delay: (d) async => delays.add(d),
      );

      await client.get(Uri.parse('https://x.test/'));

      expect(delays, [const Duration(seconds: 7)]);
    });

    test('caps Retry-After and ignores non-numeric values', () async {
      var calls = 0;
      final delays = <Duration>[];
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          if (calls == 1) {
            return http.Response('', 503, headers: {'retry-after': '999'});
          }
          if (calls == 2) {
            // HTTP-date form is not parsed — falls back to backoff.
            return http.Response('', 503,
                headers: {'retry-after': 'Wed, 21 Oct 2026 07:28:00 GMT'});
          }
          return http.Response('ok', 200);
        }),
        delay: (d) async => delays.add(d),
      );

      await client.get(Uri.parse('https://x.test/'));

      expect(delays, [
        const Duration(seconds: AppConstants.httpRetryAfterCapSeconds),
        const Duration(milliseconds: AppConstants.httpRetryBaseDelayMs * 2),
      ]);
    });

    test('maxRetries is configurable', () async {
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        maxRetries: 5,
        delay: (_) async {},
      );

      await client.get(Uri.parse('https://x.test/'));

      expect(calls, 6);
    });

    test('send() rebuilds the request for every retry attempt', () async {
      var built = 0;
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((req) async {
          calls++;
          expect(req.followRedirects, isFalse);
          return calls == 1
              ? http.Response('', 500)
              : http.Response('page', 200);
        }),
        delay: (_) async {},
      );

      final response = await client.send(() {
        built++;
        return http.Request('GET', Uri.parse('https://x.test/'))
          ..followRedirects = false;
      });

      expect(response.body, 'page');
      expect(built, 2); // one fresh Request per attempt
    });

    test('send() returns 3xx without retrying (redirect handling stays with '
        'the caller, e.g. web_scrape SSRF loop)', () async {
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((_) async {
          calls++;
          return http.Response('', 302,
              headers: {'location': 'https://elsewhere.test/'});
        }),
        delay: (_) async {},
      );

      final response = await client
          .send(() => http.Request('GET', Uri.parse('https://x.test/')));

      expect(response.statusCode, 302);
      expect(calls, 1);
    });

    test('a hung request throws TimeoutException promptly without retrying',
        () async {
      var calls = 0;
      final client = RetryingHttpClient(
        inner: MockClient((_) {
          calls++;
          return Completer<http.Response>().future; // never completes
        }),
        timeout: const Duration(milliseconds: 50),
        delay: (_) async => fail('a timed-out attempt must not be retried'),
      );

      await expectLater(
        client.get(Uri.parse('https://x.test/')),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 1, reason: 'no retry attempt after a timeout');
    });

    test('a fast response is unaffected by the timeout', () async {
      final client = RetryingHttpClient(
        inner: MockClient((_) async => http.Response('ok', 200)),
        timeout: const Duration(seconds: 5),
        delay: (_) async {},
      );

      final response = await client.get(Uri.parse('https://x.test/'));

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
    });

    test('default timeout matches AppConstants.httpRequestTimeoutSeconds',
        () {
      final client = RetryingHttpClient(
        inner: MockClient((_) async => http.Response('', 200)),
      );
      expect(client.timeout,
          const Duration(seconds: AppConstants.httpRequestTimeoutSeconds));
    });
  });
}
