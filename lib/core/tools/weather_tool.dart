import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool.dart';

/// Weather forecast tool using Open-Meteo API with Météo-France models
/// (AROME 1.3km + ARPEGE). No API key required, pure HTTP.
class WeatherTool extends Tool {
  static const _baseUrl = 'https://api.open-meteo.com/v1/meteofrance';

  @override
  String get name => 'weather';

  @override
  String get description =>
      'Get weather forecast for a location (temperature, rain, wind, conditions). '
      'Uses Météo-France high-precision models (AROME 1.3km). No API key needed. '
      'Provide coordinates from get_location or geocode. '
      'Returns daily summary and hourly breakdown (morning/afternoon/evening).';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'latitude': {
            'type': 'number',
            'description': 'Latitude of the location',
          },
          'longitude': {
            'type': 'number',
            'description': 'Longitude of the location',
          },
          'days': {
            'type': 'integer',
            'description':
                'Number of forecast days (1-7, default: 2 = today + tomorrow)',
          },
        },
        'required': ['latitude', 'longitude'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final lat = (arguments['latitude'] as num?)?.toDouble();
    final lon = (arguments['longitude'] as num?)?.toDouble();

    if (lat == null || lon == null) {
      return ToolResult.error(
          'Missing required parameters: latitude and longitude');
    }

    final days = ((arguments['days'] as int?) ?? 2).clamp(1, 7);

    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$lat&longitude=$lon'
        '&hourly=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code'
        '&timezone=auto&forecast_days=$days',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'DroidClaw/1.0',
      });

      if (response.statusCode != 200) {
        return ToolResult.error(
            'Open-Meteo API error: HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final daily = data['daily'] as Map<String, dynamic>?;
      final hourly = data['hourly'] as Map<String, dynamic>?;

      if (daily == null || hourly == null) {
        return ToolResult.error('Unexpected API response: missing data');
      }

      final llmBuf = StringBuffer();
      final userBuf = StringBuffer();

      // --- Daily summaries ---
      final dates = (daily['time'] as List?)?.cast<String>() ?? [];
      final maxTemps = daily['temperature_2m_max'] as List? ?? [];
      final minTemps = daily['temperature_2m_min'] as List? ?? [];
      final precipSums = daily['precipitation_sum'] as List? ?? [];
      final windMaxs = daily['wind_speed_10m_max'] as List? ?? [];
      final dailyCodes = daily['weather_code'] as List? ?? [];

      for (var i = 0; i < dates.length; i++) {
        final date = dates[i];
        final tMin = (minTemps[i] as num?)?.toDouble();
        final tMax = (maxTemps[i] as num?)?.toDouble();
        final precip = (precipSums[i] as num?)?.toDouble() ?? 0;
        final wind = (windMaxs[i] as num?)?.toDouble();
        final code = (dailyCodes[i] as int?) ?? -1;
        final condition = _wmoToFrench(code);

        final dayLabel = i == 0 ? "Aujourd'hui ($date)" : date;

        llmBuf.writeln('=== $dayLabel ===');
        llmBuf.writeln('Condition: $condition (WMO $code)');
        if (tMin != null && tMax != null) {
          llmBuf.writeln('Temperature: ${tMin.round()}-${tMax.round()}°C');
        }
        if (precip > 0) llmBuf.writeln('Precipitation: ${precip}mm');
        if (wind != null) llmBuf.writeln('Wind max: ${wind.round()} km/h');
        llmBuf.writeln();

        // Hourly breakdown for this day
        llmBuf.writeln(_buildHourlyBreakdown(hourly, i));

        // User compact line
        final tempStr = tMin != null && tMax != null
            ? '${tMin.round()}-${tMax.round()}°C'
            : '?';
        final precipStr = precip > 0 ? ', ${precip}mm' : '';
        final label = i == 0 ? "Auj" : date.substring(5); // MM-DD
        userBuf.write('$label: $tempStr, $condition$precipStr');
        if (i < dates.length - 1) userBuf.write(' | ');
      }

      return ToolResult.dual(
        forLLM: llmBuf.toString().trimRight(),
        forUser: userBuf.toString(),
      );
    } catch (e) {
      return ToolResult.error('Weather fetch failed: $e');
    }
  }

  /// Build hourly breakdown for a given day index (morning/afternoon/evening).
  String _buildHourlyBreakdown(Map<String, dynamic> hourly, int dayIndex) {
    final temps = hourly['temperature_2m'] as List? ?? [];
    final humidities = hourly['relative_humidity_2m'] as List? ?? [];
    final precips = hourly['precipitation'] as List? ?? [];
    final winds = hourly['wind_speed_10m'] as List? ?? [];
    final codes = hourly['weather_code'] as List? ?? [];

    final buf = StringBuffer();
    final periods = {'Matin (9h)': 9, 'Après-midi (15h)': 15, 'Soir (21h)': 21};

    for (final entry in periods.entries) {
      final idx = entry.value + (dayIndex * 24);
      if (idx >= temps.length) continue;

      final temp = (temps[idx] as num?)?.toDouble();
      final humidity = (humidities[idx] as num?)?.toInt();
      final precip = (precips[idx] as num?)?.toDouble() ?? 0;
      final wind = (winds[idx] as num?)?.toDouble();
      final code = (codes[idx] as int?) ?? -1;

      buf.write('  ${entry.key}: ${_wmoToFrench(code)}');
      if (temp != null) buf.write(', ${temp.round()}°C');
      if (humidity != null) buf.write(', $humidity%');
      if (wind != null) buf.write(', vent ${wind.round()} km/h');
      if (precip > 0) buf.write(', ${precip}mm');
      buf.writeln();
    }

    return buf.toString();
  }

  /// Interpret WMO weather codes to French descriptions.
  static String _wmoToFrench(int code) {
    return switch (code) {
      0 => 'Ciel dégagé',
      1 => 'Peu nuageux',
      2 => 'Partiellement nuageux',
      3 => 'Couvert',
      45 || 48 => 'Brouillard',
      51 => 'Bruine légère',
      53 => 'Bruine modérée',
      55 => 'Bruine dense',
      56 || 57 => 'Bruine verglaçante',
      61 => 'Pluie légère',
      63 => 'Pluie modérée',
      65 => 'Pluie forte',
      66 || 67 => 'Pluie verglaçante',
      71 => 'Neige légère',
      73 => 'Neige modérée',
      75 => 'Neige forte',
      77 => 'Grésil',
      80 => 'Averses légères',
      81 => 'Averses modérées',
      82 => 'Averses violentes',
      85 => 'Averses de neige légères',
      86 => 'Averses de neige fortes',
      95 => 'Orage',
      96 => 'Orage avec grêle légère',
      99 => 'Orage avec grêle forte',
      _ => 'Inconnu (code $code)',
    };
  }
}
