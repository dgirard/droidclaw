import 'package:http/http.dart' as http;

import '../../shared/constants.dart';

/// Decides whether an otherwise-final response should be retried.
///
/// Called for responses that are NOT already transient (429/5xx) — use it for
/// consumer-specific transient conditions (e.g. an LLM API returning 200 with
/// an empty `choices` array). Keep domain semantics in the consumer: this
/// layer only re-sends the request.
typedef RetryPredicate = bool Function(http.Response response);

/// Shared HTTP retry policy: retries on 429 and 5xx with exponential backoff
/// (baseDelay * 2^attempt), honoring a server-sent `Retry-After` header
/// (integer seconds, capped at [AppConstants.httpRetryAfterCapSeconds]).
///
/// Extracted from `HttpProvider`'s tested retry loop (U16). Design contract:
/// - After exhausting retries the FINAL response is returned, never thrown —
///   consumers map status codes to their own error types (LLMException,
///   ToolResult.error, ...). No LLM/ToolResult semantics live here.
/// - `inner` is the test seam: pass a `MockClient` in tests. When omitted,
///   the client owns a fresh `http.Client` and [close] disposes it; an
///   injected client is never closed (caller owns it).
/// - `shouldRetry` hooks consumer-specific "this response is transient"
///   checks without baking them into the net layer.
class RetryingHttpClient {
  final http.Client _inner;
  final bool _ownsInner;
  final int maxRetries;
  final Duration baseDelay;
  final RetryPredicate? shouldRetry;
  final Future<void> Function(Duration) _delay;

  RetryingHttpClient({
    http.Client? inner,
    this.maxRetries = AppConstants.httpMaxRetries,
    this.baseDelay =
        const Duration(milliseconds: AppConstants.httpRetryBaseDelayMs),
    this.shouldRetry,
    Future<void> Function(Duration)? delay,
  })  : _inner = inner ?? http.Client(),
        _ownsInner = inner == null,
        _delay = delay ?? ((d) => Future<void>.delayed(d));

  /// GET with retry.
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _withRetry(() => _inner.get(url, headers: headers));

  /// POST with retry. [body] follows `http.Client.post` semantics
  /// (`String`, `List<int>`, or `Map<String, String>` form fields).
  Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _withRetry(() => _inner.post(url, headers: headers, body: body));

  /// Send a request built by [buildRequest] with retry. The factory is
  /// invoked once per attempt (an `http.Request` can only be sent once).
  /// Use this for requests needing `followRedirects = false` etc. — retries
  /// always re-send the exact request the factory builds, so per-hop URL
  /// validation done by the caller (e.g. UrlGuard) stays intact.
  Future<http.Response> send(http.BaseRequest Function() buildRequest) =>
      _withRetry(() async =>
          http.Response.fromStream(await _inner.send(buildRequest())));

  /// Releases the owned inner client. No-op when the inner client was
  /// injected (the caller owns its lifecycle).
  void close() {
    if (_ownsInner) _inner.close();
  }

  Future<http.Response> _withRetry(
      Future<http.Response> Function() attempt) async {
    http.Response response;
    for (var i = 0;; i++) {
      response = await attempt();
      final transient =
          response.statusCode == 429 || response.statusCode >= 500;
      if (i >= maxRetries ||
          !(transient || (shouldRetry?.call(response) ?? false))) {
        return response;
      }
      await _delay(_delayFor(i, response));
    }
  }

  Duration _delayFor(int attempt, http.Response response) {
    final retryAfter = int.tryParse(
        response.headers['retry-after']?.trim() ?? '');
    if (retryAfter != null && retryAfter >= 0) {
      return Duration(
          seconds: retryAfter > AppConstants.httpRetryAfterCapSeconds
              ? AppConstants.httpRetryAfterCapSeconds
              : retryAfter);
    }
    return baseDelay * (1 << attempt);
  }
}
