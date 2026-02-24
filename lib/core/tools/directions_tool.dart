import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool.dart';

/// Tool that calculates routes via the OpenRouteService API v2.
class DirectionsTool extends Tool {
  final String? apiKey;

  DirectionsTool({this.apiKey});

  static const _baseUrl = 'https://api.openrouteservice.org/v2';

  /// Map user-facing modes to ORS profile identifiers.
  static const _profiles = {
    'car': 'driving-car',
    'bike': 'cycling-regular',
    'road_bike': 'cycling-road',
    'mtb': 'cycling-mountain',
    'walk': 'foot-walking',
    'hike': 'foot-hiking',
    'wheelchair': 'wheelchair',
  };

  @override
  String get name => 'get_directions';

  @override
  String get description =>
      'Calculate a route between two points by car, bike, or on foot. '
      'Returns distance, duration, elevation, and turn-by-turn instructions. '
      'Can also compute isochrones (reachable area in N minutes). '
      'Coordinates: use get_location for current position, or provide lat/lon. '
      'Chain with geocode to resolve place names to coordinates. '
      'Requires an OpenRouteService API key (free at openrouteservice.org).';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['directions', 'isochrones'],
            'description':
                '"directions" for A→B routing (default), '
                    '"isochrones" for reachable area from a point.',
          },
          'origin_lat': {
            'type': 'number',
            'description': 'Origin latitude (required for directions)',
          },
          'origin_lon': {
            'type': 'number',
            'description': 'Origin longitude (required for directions)',
          },
          'dest_lat': {
            'type': 'number',
            'description': 'Destination latitude (required for directions)',
          },
          'dest_lon': {
            'type': 'number',
            'description': 'Destination longitude (required for directions)',
          },
          'mode': {
            'type': 'string',
            'enum': [
              'car',
              'bike',
              'road_bike',
              'mtb',
              'walk',
              'hike',
              'wheelchair'
            ],
            'description': 'Transport mode (default: car)',
          },
          'range_minutes': {
            'type': 'integer',
            'description':
                'Isochrone range in minutes (default: 15). '
                    'Only for isochrones operation.',
          },
        },
        'required': ['origin_lat', 'origin_lon'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return ToolResult.error(
          'OpenRouteService API key not configured. '
          'Set it in Settings > Routing.');
    }

    final operation =
        (arguments['operation'] as String?) ?? 'directions';

    try {
      return switch (operation) {
        'directions' => await _directions(arguments),
        'isochrones' => await _isochrones(arguments),
        _ => ToolResult.error(
            'Unknown operation: $operation. Use "directions" or "isochrones".'),
      };
    } catch (e) {
      return ToolResult.error('Routing failed: $e');
    }
  }

  Future<ToolResult> _directions(Map<String, dynamic> args) async {
    final originLat = (args['origin_lat'] as num?)?.toDouble();
    final originLon = (args['origin_lon'] as num?)?.toDouble();
    final destLat = (args['dest_lat'] as num?)?.toDouble();
    final destLon = (args['dest_lon'] as num?)?.toDouble();

    if (originLat == null || originLon == null) {
      return ToolResult.error('Missing origin coordinates (origin_lat, origin_lon).');
    }
    if (destLat == null || destLon == null) {
      return ToolResult.error('Missing destination coordinates (dest_lat, dest_lon).');
    }

    final mode = (args['mode'] as String?) ?? 'car';
    final profile = _profiles[mode];
    if (profile == null) {
      return ToolResult.error(
          'Unknown mode: $mode. Use: ${_profiles.keys.join(', ')}');
    }

    final body = jsonEncode({
      'coordinates': [
        [originLon, originLat], // ORS uses [lon, lat]
        [destLon, destLat],
      ],
      'instructions': true,
      'language': 'fr',
      'units': 'km',
      'elevation': true,
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/directions/$profile'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': apiKey!,
      },
      body: body,
    );

    if (response.statusCode == 429) {
      return ToolResult.error('Rate limit exceeded. Try again in a minute.');
    }

    if (response.statusCode != 200) {
      return _parseError(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      return ToolResult.error('No route found between the given points.');
    }

    final route = routes[0] as Map<String, dynamic>;
    final summary = route['summary'] as Map<String, dynamic>;
    final distance = (summary['distance'] as num).toDouble();
    final durationSec = (summary['duration'] as num).toDouble();
    final ascent = (summary['ascent'] as num?)?.toDouble();
    final descent = (summary['descent'] as num?)?.toDouble();

    final durationMin = (durationSec / 60).round();
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = hours > 0 ? '${hours}h${mins.toString().padLeft(2, '0')}' : '$mins min';

    // Build turn-by-turn instructions
    final segments = route['segments'] as List? ?? [];
    final steps = <String>[];
    for (final segment in segments) {
      final segSteps = (segment as Map<String, dynamic>)['steps'] as List? ?? [];
      for (final step in segSteps) {
        final s = step as Map<String, dynamic>;
        final instruction = s['instruction'] as String? ?? '';
        final stepDist = (s['distance'] as num?)?.toDouble() ?? 0;
        if (instruction.isNotEmpty) {
          steps.add('- $instruction (${stepDist.toStringAsFixed(1)} km)');
        }
      }
    }

    final elevationStr = ascent != null && descent != null
        ? ', elevation +${ascent.round()}m / -${descent.round()}m'
        : '';

    final forLLM = StringBuffer()
      ..writeln('Route ($mode): ${distance.toStringAsFixed(1)} km, '
          '$durationStr$elevationStr')
      ..writeln()
      ..writeln('Turn-by-turn instructions:')
      ..writeln(steps.join('\n'));

    final forUser =
        '${distance.toStringAsFixed(1)} km, $durationStr ($mode)$elevationStr';

    return ToolResult.dual(forLLM: forLLM.toString(), forUser: forUser);
  }

  Future<ToolResult> _isochrones(Map<String, dynamic> args) async {
    final lat = (args['origin_lat'] as num?)?.toDouble();
    final lon = (args['origin_lon'] as num?)?.toDouble();

    if (lat == null || lon == null) {
      return ToolResult.error('Missing origin coordinates (origin_lat, origin_lon).');
    }

    final mode = (args['mode'] as String?) ?? 'car';
    final profile = _profiles[mode];
    if (profile == null) {
      return ToolResult.error(
          'Unknown mode: $mode. Use: ${_profiles.keys.join(', ')}');
    }

    final rangeMinutes = (args['range_minutes'] as int?) ?? 15;
    final rangeSec = rangeMinutes * 60;

    final body = jsonEncode({
      'locations': [
        [lon, lat],
      ],
      'range': [rangeSec],
      'range_type': 'time',
      'attributes': ['area'],
      'area_units': 'km',
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/isochrones/$profile'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': apiKey!,
      },
      body: body,
    );

    if (response.statusCode == 429) {
      return ToolResult.error('Rate limit exceeded. Try again in a minute.');
    }

    if (response.statusCode != 200) {
      return _parseError(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List? ?? [];
    if (features.isEmpty) {
      return ToolResult.error('No isochrone data returned.');
    }

    final feature = features[0] as Map<String, dynamic>;
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final areaSqKm = (props['area'] as num?)?.toDouble();

    final areaStr = areaSqKm != null
        ? '${areaSqKm.toStringAsFixed(1)} km²'
        : 'unknown area';

    return ToolResult.dual(
      forLLM: 'Isochrone ($mode, $rangeMinutes min): reachable area = $areaStr '
          'from ($lat, $lon).',
      forUser: '$rangeMinutes min by $mode: $areaStr reachable',
    );
  }

  ToolResult _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ?? response.body;
      return ToolResult.error('ORS API error (${response.statusCode}): $message');
    } catch (_) {
      return ToolResult.error('ORS API error (${response.statusCode}): ${response.body}');
    }
  }
}
