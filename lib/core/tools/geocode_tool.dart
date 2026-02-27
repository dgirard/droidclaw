import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool.dart';

/// Geocoding tool: converts a text address into GPS coordinates
/// using the Nominatim (OpenStreetMap) Search API. Free, no API key required.
class GeocodeTool extends Tool {
  @override
  String get name => 'geocode';

  @override
  String get description =>
      'Convert a text address or place name into GPS coordinates. '
      'Use before get_directions, get_transit, or weather when a tool needs coordinates. '
      'You can pass addresses from the knowledge context directly. '
      'Do NOT use when the user is simply sharing their address.';

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
    final address = arguments['address'] as String?;
    if (address == null || address.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: address');
    }

    final maxResults =
        ((arguments['max_results'] as int?) ?? 3).clamp(1, 10);
    final country = arguments['country'] as String?;

    try {
      final queryParams = <String, String>{
        'q': address.trim(),
        'format': 'jsonv2',
        'limit': maxResults.toString(),
        'addressdetails': '1',
      };
      if (country != null && country.isNotEmpty) {
        queryParams['countrycodes'] = country.toLowerCase();
      }

      final uri = Uri.https(
          'nominatim.openstreetmap.org', '/search', queryParams);

      final response = await http.get(uri, headers: {
        'User-Agent': 'DroidClaw/1.0',
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        return ToolResult.error(
            'Nominatim API error: HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List;

      if (data.isEmpty) {
        return ToolResult.error(
            'No results found for "$address". '
            'Try a more specific address or different spelling.');
      }

      final results = <String>[];
      final userResults = <String>[];

      for (var i = 0; i < data.length; i++) {
        final item = data[i] as Map<String, dynamic>;

        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final label = item['display_name'] as String? ?? address;
        final type = item['type'] as String? ?? '';
        final importance = (item['importance'] as num?)?.toDouble();
        final addr = item['address'] as Map<String, dynamic>? ?? {};

        // LLM gets structured data
        final llmEntry = StringBuffer()
          ..writeln('Result ${i + 1}:')
          ..writeln('  Label: $label')
          ..writeln('  Latitude: $lat')
          ..writeln('  Longitude: $lon');
        if (type.isNotEmpty) llmEntry.writeln('  Type: $type');
        if (importance != null) {
          llmEntry.writeln('  Importance: ${importance.toStringAsFixed(3)}');
        }
        // Address components
        final road = addr['road'] ?? addr['pedestrian'] ?? '';
        final city = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'] ??
            '';
        final state = addr['state'] ?? '';
        final countryName = addr['country'] ?? '';
        final postcode = addr['postcode'] ?? '';
        if (road.toString().isNotEmpty) llmEntry.writeln('  Road: $road');
        if (city.toString().isNotEmpty) llmEntry.writeln('  City: $city');
        if (postcode.toString().isNotEmpty) {
          llmEntry.writeln('  Postcode: $postcode');
        }
        if (state.toString().isNotEmpty) llmEntry.writeln('  State: $state');
        if (countryName.toString().isNotEmpty) {
          llmEntry.writeln('  Country: $countryName');
        }
        results.add(llmEntry.toString().trimRight());

        // User gets compact display
        userResults.add('$label ($lat, $lon)');
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
}
