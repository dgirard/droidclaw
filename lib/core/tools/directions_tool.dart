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

  /// Fallback profiles when the primary is unavailable (ORS maintenance).
  static List<String> _fallbacks(String profile) => switch (profile) {
        'foot-walking' => ['foot-hiking', 'driving-car'],
        'foot-hiking' => ['foot-walking', 'driving-car'],
        'cycling-regular' || 'cycling-road' || 'cycling-mountain' =>
          ['driving-car'],
        'wheelchair' => ['foot-walking', 'driving-car'],
        _ => ['driving-car'],
      };

  @override
  String get name => 'get_directions';

  @override
  String get description =>
      'Calculate a route between two points by car, bike, or on foot. '
      'Returns distance, duration, elevation, and turn-by-turn instructions. '
      'Can also compute isochrones (reachable area in N minutes). '
      'Coordinates: geocode a known address (from knowledge context or user), '
      'or get_location for current position. Chain with geocode to resolve place names. '
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
            'description': 'Transport mode: car (default), bike, walk, hike, wheelchair',
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
    final profile = _profiles[mode] ?? _profiles['car']!;

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

    // Try primary profile, then fallbacks if ORS returns 400 (maintenance)
    final (response, usedProfile) =
        await _postWithFallback('directions', profile, body);

    if (response.statusCode == 429) {
      return ToolResult.error('Rate limit exceeded. Try again in a minute.');
    }

    if (response.statusCode != 200) {
      return _parseError(response, requestedProfile: profile);
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

    // Detect fallback: usedProfile differs from requested profile
    final isFallback = usedProfile != profile;
    final usedMode = isFallback ? _modeForProfile(usedProfile) : mode;
    final fallbackNote = isFallback
        ? ' (NOTE: $mode profile temporarily unavailable — using $usedMode instead)'
        : '';

    final forLLM = StringBuffer()
      ..writeln('Route ($usedMode): ${distance.toStringAsFixed(1)} km, '
          '$durationStr$elevationStr$fallbackNote')
      ..writeln()
      ..writeln('Turn-by-turn instructions:')
      ..writeln(steps.join('\n'));

    final forUser = isFallback
        ? '${distance.toStringAsFixed(1)} km, $durationStr ($usedMode — $mode unavailable)$elevationStr'
        : '${distance.toStringAsFixed(1)} km, $durationStr ($mode)$elevationStr';

    return ToolResult.dual(forLLM: forLLM.toString(), forUser: forUser);
  }

  Future<ToolResult> _isochrones(Map<String, dynamic> args) async {
    final lat = (args['origin_lat'] as num?)?.toDouble();
    final lon = (args['origin_lon'] as num?)?.toDouble();

    if (lat == null || lon == null) {
      return ToolResult.error('Missing origin coordinates (origin_lat, origin_lon).');
    }

    final mode = (args['mode'] as String?) ?? 'car';
    final profile = _profiles[mode] ?? _profiles['car']!;

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

    // Try primary profile, then fallbacks if ORS returns 400 (maintenance)
    final (response, usedProfile) =
        await _postWithFallback('isochrones', profile, body);

    if (response.statusCode == 429) {
      return ToolResult.error('Rate limit exceeded. Try again in a minute.');
    }

    if (response.statusCode != 200) {
      return _parseError(response, requestedProfile: profile);
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

    final isFallback = usedProfile != profile;
    final usedMode = isFallback ? _modeForProfile(usedProfile) : mode;
    final fallbackNote = isFallback
        ? ' (NOTE: $mode profile temporarily unavailable — using $usedMode instead)'
        : '';

    return ToolResult.dual(
      forLLM: 'Isochrone ($usedMode, $rangeMinutes min): reachable area = $areaStr '
          'from ($lat, $lon).$fallbackNote',
      forUser: isFallback
          ? '$rangeMinutes min by $usedMode: $areaStr reachable ($mode unavailable)'
          : '$rangeMinutes min by $mode: $areaStr reachable',
    );
  }

  /// POST to ORS, retrying with fallback profiles on 400 (maintenance).
  /// Returns the successful response and the profile that was actually used.
  Future<(http.Response, String)> _postWithFallback(
      String endpoint, String profile, String body) async {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': apiKey!,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint/$profile'),
      headers: headers,
      body: body,
    );

    // Only retry on 400 with known maintenance signature.
    if (response.statusCode != 400 || !_isMaintenanceError(response)) {
      return (response, profile);
    }

    // Profile is down (maintenance). Try fallbacks in order.
    for (final fallback in _fallbacks(profile)) {
      final retryResponse = await http.post(
        Uri.parse('$_baseUrl/$endpoint/$fallback'),
        headers: headers,
        body: body,
      );
      if (retryResponse.statusCode != 400 || !_isMaintenanceError(retryResponse)) {
        return (retryResponse, fallback);
      }
    }

    // All fallbacks also failed — return the original error.
    return (response, profile);
  }

  /// Check if a 400 response is an ORS maintenance error (profile reported as 'unknown').
  static bool _isMaintenanceError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ?? '';
      return message.contains("incorrect value of 'unknown'");
    } catch (_) {
      return false;
    }
  }

  /// Reverse-lookup: ORS profile identifier → user-facing mode name.
  static String _modeForProfile(String profile) {
    for (final entry in _profiles.entries) {
      if (entry.value == profile) return entry.key;
    }
    return profile; // fallback: return raw profile name
  }

  ToolResult _parseError(http.Response response, {String? requestedProfile}) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ?? response.body;

      // Detect ORS maintenance: profile reported as 'unknown'
      if (message.contains("incorrect value of 'unknown'") &&
          requestedProfile != null) {
        final mode = _modeForProfile(requestedProfile);
        return ToolResult.error(
            'The $mode routing profile is currently unavailable on '
            'OpenRouteService (server maintenance). '
            'Try "car" mode, or wait and retry later.');
      }

      return ToolResult.error('ORS API error (${response.statusCode}): $message');
    } catch (_) {
      return ToolResult.error('ORS API error (${response.statusCode}): ${response.body}');
    }
  }
}
