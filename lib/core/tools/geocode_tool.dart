import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool.dart';

/// Geocoding tool: converts a text address into GPS coordinates
/// using the OpenRouteService Geocoding API (Pelias-based).
/// Reuses the same ORS API key as DirectionsTool.
class GeocodeTool extends Tool {
  final String? apiKey;

  GeocodeTool({this.apiKey});

  static const _baseUrl = 'https://api.openrouteservice.org/geocode/search';

  @override
  String get name => 'geocode';

  @override
  String get description =>
      'Convert a text address or place name into GPS coordinates (latitude, longitude). '
      'Returns up to N matching results with confidence scores. '
      'Use this before get_directions or get_transit when the user provides an address instead of coordinates. '
      'Requires an OpenRouteService API key (same as get_directions).';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'address': {
            'type': 'string',
            'description':
                'The address or place name to geocode (e.g. "Tour Eiffel, Paris")',
          },
          'country': {
            'type': 'string',
            'description':
                'Optional ISO 3166-1 alpha-2 country code to restrict results '
                    '(e.g. "FR", "DE", "US")',
          },
          'max_results': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 3, max: 10)',
          },
        },
        'required': ['address'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return ToolResult.error(
          'OpenRouteService API key not configured. '
          'Set it in Settings > Routing.');
    }

    final address = arguments['address'] as String?;
    if (address == null || address.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: address');
    }

    final maxResults =
        ((arguments['max_results'] as int?) ?? 3).clamp(1, 10);
    final country = arguments['country'] as String?;

    try {
      final queryParams = <String, String>{
        'text': address.trim(),
        'size': maxResults.toString(),
      };
      if (country != null && country.isNotEmpty) {
        queryParams['boundary.country'] = country.toUpperCase();
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'Authorization': apiKey!,
        'Accept': 'application/json',
      });

      if (response.statusCode == 429) {
        return ToolResult.error('Rate limit exceeded. Try again in a minute.');
      }

      if (response.statusCode != 200) {
        return _parseError(response);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      if (features.isEmpty) {
        return ToolResult.error(
            'No results found for "$address". '
            'Try a more specific address or different spelling.');
      }

      final results = <String>[];
      final userResults = <String>[];

      for (var i = 0; i < features.length; i++) {
        final feature = features[i] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
        final coords = geometry['coordinates'] as List? ?? [];
        final props = feature['properties'] as Map<String, dynamic>? ?? {};

        if (coords.length < 2) continue;

        // ORS returns [lon, lat] — present as lat, lon
        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        final label = props['label'] as String? ?? address;
        final confidence = (props['confidence'] as num?)?.toDouble();
        final country = props['country'] as String? ?? '';
        final region = props['region'] as String? ?? '';
        final locality = props['locality'] as String? ?? '';

        final confStr = confidence != null
            ? ' (confidence: ${confidence.toStringAsFixed(2)})'
            : '';

        // LLM gets structured data
        final llmEntry = StringBuffer()
          ..writeln('Result ${i + 1}:')
          ..writeln('  Label: $label')
          ..writeln('  Latitude: $lat')
          ..writeln('  Longitude: $lon');
        if (confidence != null) {
          llmEntry.writeln('  Confidence: ${confidence.toStringAsFixed(2)}');
        }
        if (locality.isNotEmpty) llmEntry.writeln('  Locality: $locality');
        if (region.isNotEmpty) llmEntry.writeln('  Region: $region');
        if (country.isNotEmpty) llmEntry.writeln('  Country: $country');
        results.add(llmEntry.toString().trimRight());

        // User gets compact display
        userResults.add('$label ($lat, $lon)$confStr');
      }

      if (results.isEmpty) {
        return ToolResult.error('No valid coordinates in results.');
      }

      final forLLM = 'Geocoding results for "$address":\n\n${results.join('\n\n')}';
      final forUser = userResults.join('\n');

      return ToolResult.dual(forLLM: forLLM, forUser: forUser);
    } catch (e) {
      return ToolResult.error('Geocoding failed: $e');
    }
  }

  ToolResult _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['error'] as String? ??
          (data['geocoding'] as Map<String, dynamic>?)?['errors'] ??
          response.body;
      return ToolResult.error(
          'ORS Geocoding error (${response.statusCode}): $message');
    } catch (_) {
      return ToolResult.error(
          'ORS Geocoding error (${response.statusCode}): ${response.body}');
    }
  }
}
