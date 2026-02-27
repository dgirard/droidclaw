import 'package:geolocator/geolocator.dart';

import 'tool.dart';

/// Tool that returns the device's current GPS/network location.
class LocationTool extends Tool {
  /// When false (service isolate), skip requestPermission() — return an error
  /// if permission was not pre-granted from the app.
  final bool canRequestPermission;

  LocationTool({this.canRequestPermission = true});

  @override
  String get name => 'get_location';

  @override
  String get description =>
      'Get the device current GPS location (latitude, longitude, accuracy). '
      'Use ONLY when you need the device real-time GPS coordinates '
      '(e.g., nearby places, weather, directions from current position). '
      'Do NOT use when the user tells you their address — they already know where they live.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return ToolResult.error(
            'Location services are disabled. Please enable GPS.');
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!canRequestPermission) {
          return ToolResult.error(
              'Location permission not granted. '
              'Please open the app and use get_location once to grant permission.');
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return ToolResult.error('Location permission denied by user.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return ToolResult.error(
            'Location permission permanently denied. '
            'Please enable it in device settings.');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final lat = position.latitude.toStringAsFixed(6);
      final lon = position.longitude.toStringAsFixed(6);
      final acc = position.accuracy.toStringAsFixed(0);

      return ToolResult.dual(
        forLLM: 'Current device location: '
            'latitude=$lat, longitude=$lon, '
            'accuracy=${acc}m, '
            'altitude=${position.altitude.toStringAsFixed(1)}m, '
            'timestamp=${position.timestamp}',
        forUser: 'Location: $lat, $lon (accuracy: ${acc}m)',
      );
    } catch (e) {
      return ToolResult.error('Failed to get location: $e');
    }
  }
}
