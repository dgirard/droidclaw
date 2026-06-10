import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:droidclaw/core/tools/weather_tool.dart';

/// Minimal Open-Meteo response: one forecast day, no hourly samples
/// (the tool skips hourly rows that are out of range).
String _forecastJson() => jsonEncode({
      'daily': {
        'time': ['2026-06-10'],
        'temperature_2m_max': [21.4],
        'temperature_2m_min': [12.6],
        'precipitation_sum': [0.0],
        'wind_speed_10m_max': [18.0],
        'weather_code': [1],
      },
      'hourly': <String, dynamic>{},
    });

void main() {
  group('WeatherTool (injected client seam, U16)', () {
    test('retries on 429 then returns a clean dual result', () async {
      var calls = 0;
      final tool = WeatherTool(
        client: MockClient((req) async {
          calls++;
          expect(req.url.host, 'api.open-meteo.com');
          if (calls == 1) return http.Response('rate limited', 429);
          return http.Response(_forecastJson(), 200);
        }),
      );

      final result = await tool
          .execute({'latitude': 48.85, 'longitude': 2.35, 'days': 1});

      expect(calls, 2);
      expect(result.isError, isFalse);
      expect(result.forLLM, contains('Temperature: 13-21°C'));
      expect(result.forUser, contains('13-21°C'));
    });

    test('exhausted retries surface a clean tool error, not a crash',
        () async {
      var calls = 0;
      final tool = WeatherTool(
        client: MockClient((_) async {
          calls++;
          return http.Response('boom', 500);
        }),
      );

      final result =
          await tool.execute({'latitude': 48.85, 'longitude': 2.35});

      expect(calls, 3); // initial + 2 retries (shared policy)
      expect(result.isError, isTrue);
      expect(result.forLLM, 'Open-Meteo API error: HTTP 500');
    });
  });
}
