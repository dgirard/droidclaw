import 'package:url_launcher/url_launcher.dart';

import 'tool.dart';

/// Tool that opens URLs and apps on the device via url_launcher.
class OpenAppTool extends Tool {
  static const _allowedSchemes = [
    'https',
    'http',
    'tel',
    'mailto',
    'sms',
    'geo',
  ];

  @override
  String get name => 'open_app';

  @override
  String get description =>
      'Open a URL or app on the device. Supports web URLs (https://), '
      'phone dialer (tel:+33...), email (mailto:...), SMS composer (sms:...), '
      'and map locations (geo:lat,lon or geo:0,0?q=address). '
      'The target app opens on the device screen.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'URL to open. Examples: "https://example.com", '
                '"tel:+33123456789", "mailto:user@example.com", '
                '"sms:+33123456789?body=Hello", '
                '"geo:48.8566,2.3522?q=Eiffel+Tower"',
          },
        },
        'required': ['url'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final urlStr = arguments['url'] as String?;
    if (urlStr == null || urlStr.isEmpty) {
      return ToolResult.error('Missing required parameter: url');
    }

    try {
      final uri = Uri.parse(urlStr);

      // Validate scheme
      if (!_allowedSchemes.contains(uri.scheme.toLowerCase())) {
        return ToolResult.error(
            'Unsupported URL scheme: "${uri.scheme}". '
            'Allowed: ${_allowedSchemes.join(", ")}');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        return ToolResult.error(
            'Could not open "$urlStr". No app available to handle this URL.');
      }

      final schemeLabel = switch (uri.scheme.toLowerCase()) {
        'tel' => 'phone dialer',
        'mailto' => 'email app',
        'sms' => 'SMS app',
        'geo' => 'maps app',
        _ => 'browser',
      };

      return ToolResult.dual(
        forLLM: 'Opened $schemeLabel with URL: $urlStr',
        forUser: 'Opened $schemeLabel',
      );
    } catch (e) {
      return ToolResult.error('Failed to open URL: $e');
    }
  }
}
