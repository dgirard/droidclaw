import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';
import 'tool.dart';

/// Tool that finds public transit routes via SNCF and PRIM/IDFM APIs.
///
/// Both APIs use Navitia technology and return identical JSON formats.
/// Auto-routes requests: IDF-only trips use PRIM, others use SNCF.
class TransitTool extends Tool {
  final String? sncfApiKey;
  final String? primApiKey;
  final String locale;

  TransitTool({this.sncfApiKey, this.primApiKey, this.locale = 'en'});

  // Ile-de-France bounding box (generous, includes suburban rail endpoints).
  static const _idfMinLat = 48.1;
  static const _idfMaxLat = 49.25;
  static const _idfMinLon = 1.4;
  static const _idfMaxLon = 3.6;

  /// Map Navitia physical_mode values to French display labels.
  static const _modeLabels = {
    'Metro': 'Metro',
    'Métro': 'Metro',
    'RapidTransit': 'RER',
    'Bus': 'Bus',
    'Tramway': 'Tram',
    'Train': 'Train',
    'LocalTrain': 'Train',
    'LongDistanceTrain': 'TGV/IC',
    'Funicular': 'Funiculaire',
    'Coach': 'Car',
    'Ferry': 'Ferry',
  };

  @override
  String get name => 'get_transit';

  @override
  String get description =>
      'Find public transit routes in France (metro, RER, bus, tram, train). '
      'Covers Ile-de-France (RATP, Transilien) and national trains (TGV, TER). '
      'Auto-selects the best API based on trip location. '
      'Coordinates: use get_location for current position, or provide lat/lon. '
      'Chain with get_address to resolve place names to coordinates.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'origin_lat': {
            'type': 'number',
            'description': 'Origin latitude',
          },
          'origin_lon': {
            'type': 'number',
            'description': 'Origin longitude',
          },
          'dest_lat': {
            'type': 'number',
            'description': 'Destination latitude',
          },
          'dest_lon': {
            'type': 'number',
            'description': 'Destination longitude',
          },
          'datetime': {
            'type': 'string',
            'description':
                'Departure or arrival time in YYYYMMDDTHHMMSS format '
                    '(e.g. 20260220T080000). Default: now.',
          },
          'datetime_represents': {
            'type': 'string',
            'enum': ['departure', 'arrival'],
            'description':
                '"departure" (default) or "arrival" — whether datetime '
                    'is the desired departure or arrival time.',
          },
          'wheelchair': {
            'type': 'boolean',
            'description':
                'If true, only return wheelchair-accessible routes. Default: false.',
          },
        },
        'required': ['origin_lat', 'origin_lon', 'dest_lat', 'dest_lon'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final l = tr(locale);
    final hasSncf = sncfApiKey != null && sncfApiKey!.isNotEmpty;
    final hasPrim = primApiKey != null && primApiKey!.isNotEmpty;

    if (!hasSncf && !hasPrim) {
      return ToolResult.error(l.transitNoApiKey);
    }

    final originLat = (arguments['origin_lat'] as num?)?.toDouble();
    final originLon = (arguments['origin_lon'] as num?)?.toDouble();
    final destLat = (arguments['dest_lat'] as num?)?.toDouble();
    final destLon = (arguments['dest_lon'] as num?)?.toDouble();

    if (originLat == null || originLon == null) {
      return ToolResult.error(
          'Missing origin coordinates (origin_lat, origin_lon).');
    }
    if (destLat == null || destLon == null) {
      return ToolResult.error(
          'Missing destination coordinates (dest_lat, dest_lon).');
    }

    try {
      final api = _chooseApi(originLat, originLon, destLat, destLon,
          hasSncf: hasSncf, hasPrim: hasPrim);
      if (api == null) {
        return ToolResult.error(l.transitSncfRequired);
      }

      return await _queryJourneys(
        api: api,
        originLat: originLat,
        originLon: originLon,
        destLat: destLat,
        destLon: destLon,
        datetime: arguments['datetime'] as String?,
        datetimeRepresents:
            (arguments['datetime_represents'] as String?) ?? 'departure',
        wheelchair: (arguments['wheelchair'] as bool?) ?? false,
      );
    } catch (e) {
      return ToolResult.error('Transit query failed: $e');
    }
  }

  bool _isInIdf(double lat, double lon) =>
      lat >= _idfMinLat &&
      lat <= _idfMaxLat &&
      lon >= _idfMinLon &&
      lon <= _idfMaxLon;

  _ApiConfig? _chooseApi(
    double originLat,
    double originLon,
    double destLat,
    double destLon, {
    required bool hasSncf,
    required bool hasPrim,
  }) {
    final originInIdf = _isInIdf(originLat, originLon);
    final destInIdf = _isInIdf(destLat, destLon);

    // Both points in IDF -> prefer PRIM
    if (originInIdf && destInIdf) {
      if (hasPrim) {
        return _ApiConfig(
          baseUrl:
              'https://prim.iledefrance-mobilites.fr/marketplace/v2/navitia/journeys',
          headers: {'apiKey': primApiKey!},
          name: 'PRIM (Ile-de-France)',
        );
      }
      if (hasSncf) return _sncfConfig();
      return null;
    }

    // At least one point outside IDF -> use SNCF
    if (hasSncf) return _sncfConfig();

    // Only PRIM key, but trip is not IDF-only
    return null;
  }

  _ApiConfig _sncfConfig() => _ApiConfig(
        baseUrl: 'https://api.sncf.com/v1/coverage/sncf/journeys',
        headers: {'Authorization': sncfApiKey!},
        name: 'SNCF',
      );

  Future<ToolResult> _queryJourneys({
    required _ApiConfig api,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String? datetime,
    required String datetimeRepresents,
    required bool wheelchair,
  }) async {
    final l = tr(locale);

    // Navitia uses lon;lat (semicolon separator, GeoJSON order)
    final from = '$originLon;$originLat';
    final to = '$destLon;$destLat';

    final queryParams = <String, String>{
      'from': from,
      'to': to,
      'datetime_represents': datetimeRepresents,
      'data_freshness': 'realtime',
    };

    if (datetime != null && datetime.isNotEmpty) {
      queryParams['datetime'] = datetime;
    }
    if (wheelchair) {
      queryParams['wheelchair'] = 'true';
    }

    final uri = Uri.parse(api.baseUrl).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: {
      ...api.headers,
      'Accept': 'application/json',
    });

    if (response.statusCode == 429) {
      return ToolResult.error(l.transitRateLimit);
    }

    if (response.statusCode == 401) {
      return ToolResult.error(l.transitInvalidKey(api.name));
    }

    if (response.statusCode != 200) {
      return _parseError(response, api.name);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final journeys = data['journeys'] as List?;

    if (journeys == null || journeys.isEmpty) {
      return ToolResult.error(l.transitNoRoutes);
    }

    // Take up to 3 best journeys
    final topJourneys = journeys.take(3).toList();
    final forLLM = StringBuffer();
    final forUser = StringBuffer();

    for (var i = 0; i < topJourneys.length; i++) {
      final journey = topJourneys[i] as Map<String, dynamic>;
      final result = _formatJourney(journey, i + 1, api.name);
      forLLM.writeln(result.llm);
      if (i == 0) {
        forUser.write(result.user);
      }
    }

    return ToolResult.dual(
      forLLM: forLLM.toString().trimRight(),
      forUser: forUser.toString(),
    );
  }

  _FormattedJourney _formatJourney(
    Map<String, dynamic> journey,
    int index,
    String apiName,
  ) {
    final l = tr(locale);
    final durationSec = (journey['duration'] as num?)?.toInt() ?? 0;
    final transfers = (journey['nb_transfers'] as num?)?.toInt() ?? 0;
    final departure = journey['departure_date_time'] as String? ?? '';
    final arrival = journey['arrival_date_time'] as String? ?? '';
    final co2 = journey['co2_emission'] as Map<String, dynamic>?;
    final sections = journey['sections'] as List? ?? [];

    final durationMin = (durationSec / 60).round();
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr =
        hours > 0 ? '${hours}h${mins.toString().padLeft(2, '0')}' : '$mins min';

    final depStr = _formatNavitiaTime(departure);
    final arrStr = _formatNavitiaTime(arrival);

    // Build section summaries
    final sectionLines = <String>[];
    final transitLabels = <String>[];

    for (final section in sections) {
      final s = section as Map<String, dynamic>;
      final type = s['type'] as String? ?? '';
      final secDuration = ((s['duration'] as num?)?.toInt() ?? 0);
      final secMin = (secDuration / 60).round();
      final from = (s['from'] as Map<String, dynamic>?)?['name'] as String?;
      final to = (s['to'] as Map<String, dynamic>?)?['name'] as String?;

      switch (type) {
        case 'street_network' || 'crow_fly':
          final mode = s['mode'] as String? ?? 'walking';
          if (secMin > 0) {
            sectionLines.add(
                '  [$mode] $secMin min${from != null && to != null ? ' — $from → $to' : ''}');
          }

        case 'public_transport':
          final display =
              s['display_informations'] as Map<String, dynamic>? ?? {};
          final physicalMode = display['physical_mode'] as String? ?? '';
          final label = display['label'] as String? ?? display['code'] as String? ?? '';
          final direction = display['direction'] as String? ?? '';
          final modeLabel = _modeLabels[physicalMode] ?? physicalMode;
          final lineStr = label.isNotEmpty ? '$modeLabel $label' : modeLabel;
          transitLabels.add(lineStr);
          sectionLines.add(
              '  [$lineStr] $secMin min${from != null ? ' — $from' : ''}'
              '${to != null ? ' → $to' : ''}'
              '${direction.isNotEmpty ? ' (dir. $direction)' : ''}');

        case 'transfer' || 'waiting':
          if (secMin > 0) {
            final transferLabel =
                type == 'transfer' ? l.transitTransfer : l.transitWaiting;
            sectionLines.add('  [$transferLabel] $secMin min');
          }
      }
    }

    final co2Str = co2 != null
        ? ', CO2: ${(co2['value'] as num?)?.toStringAsFixed(1)} ${co2['unit']}'
        : '';
    final transferStr =
        transfers > 0 ? l.transitTransferCount(transfers) : l.transitDirect;

    final llm = StringBuffer()
      ..writeln('--- ${l.transitOption(index, apiName)} ---')
      ..writeln('${l.transitDuration} $durationStr, $transferStr$co2Str')
      ..writeln('${l.transitDeparture} $depStr → ${l.transitArrival} $arrStr')
      ..writeln(l.transitSections)
      ..writeln(sectionLines.join('\n'));

    final routeStr =
        transitLabels.isNotEmpty ? transitLabels.join(' → ') : 'transit';
    final user = '$routeStr, $durationStr, $transferStr\n'
        '${l.transitDeparture} $depStr → ${l.transitArrival} $arrStr';

    return _FormattedJourney(llm: llm.toString(), user: user);
  }

  /// Convert Navitia datetime (YYYYMMDDTHHMMSS) to HH:MM display.
  String _formatNavitiaTime(String dt) {
    if (dt.length < 13) return dt;
    return '${dt.substring(9, 11)}:${dt.substring(11, 13)}';
  }

  ToolResult _parseError(http.Response response, String apiName) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message =
          error?['message'] as String? ?? data['message'] as String? ?? response.body;
      return ToolResult.error(
          '$apiName API error (${response.statusCode}): $message');
    } catch (_) {
      return ToolResult.error(
          '$apiName API error (${response.statusCode}): ${response.body}');
    }
  }
}

class _ApiConfig {
  final String baseUrl;
  final Map<String, String> headers;
  final String name;

  const _ApiConfig({
    required this.baseUrl,
    required this.headers,
    required this.name,
  });
}

class _FormattedJourney {
  final String llm;
  final String user;

  const _FormattedJourney({required this.llm, required this.user});
}
