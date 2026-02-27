import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool.dart';

/// Reverse geocoding tool: converts GPS coordinates to a street address
/// using the Nominatim (OpenStreetMap) API. Free, no API key required.
class ReverseGeocodeTool extends Tool {
  @override
  String get name => 'get_address';

  @override
  String get description =>
      'Convert GPS coordinates into a street address (reverse geocoding). '
      'Use ONLY after get_location when you need the current position as a street address. '
      'Not needed if the knowledge context already has the address.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'latitude': {
            'type': 'number',
            'description': 'Latitude coordinate',
          },
          'longitude': {
            'type': 'number',
            'description': 'Longitude coordinate',
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

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$lat&lon=$lon',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'DroidClaw/1.0',
        'Accept-Language': 'fr',
      });

      if (response.statusCode != 200) {
        return ToolResult.error(
            'Nominatim API error: HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        return ToolResult.error(
            'Reverse geocoding failed: ${data['error']}');
      }

      final displayName = data['display_name'] as String? ?? 'Unknown';
      final address = data['address'] as Map<String, dynamic>? ?? {};

      // Build structured details for the LLM
      final details = StringBuffer();
      details.writeln('Address: $displayName');
      if (address.isNotEmpty) {
        final road = address['road'] ?? address['pedestrian'] ?? '';
        final houseNumber = address['house_number'] ?? '';
        final postcode = address['postcode'] ?? '';
        final city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['municipality'] ??
            '';
        final state = address['state'] ?? '';
        final country = address['country'] ?? '';

        if (road.toString().isNotEmpty) {
          details.writeln(
              'Street: ${houseNumber.toString().isNotEmpty ? "$houseNumber " : ""}$road');
        }
        if (postcode.toString().isNotEmpty || city.toString().isNotEmpty) {
          details.writeln('City: $postcode $city'.trim());
        }
        if (state.toString().isNotEmpty) details.writeln('State: $state');
        if (country.toString().isNotEmpty) {
          details.writeln('Country: $country');
        }
      }

      return ToolResult.dual(
        forLLM: details.toString().trim(),
        forUser: displayName,
      );
    } catch (e) {
      return ToolResult.error('Reverse geocoding failed: $e');
    }
  }
}
