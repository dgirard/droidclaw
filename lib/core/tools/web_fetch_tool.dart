import 'package:http/http.dart' as http;

import '../../shared/constants.dart';
import 'tool.dart';

/// Fetches content from a URL, strips HTML, returns plain text.
class WebFetchTool extends Tool {
  final int maxChars;
  final int maxRedirects;

  WebFetchTool({
    this.maxChars = AppConstants.webFetchMaxChars,
    this.maxRedirects = AppConstants.webFetchMaxRedirects,
  });

  @override
  String get name => 'web_fetch';

  @override
  String get description =>
      'Fetch the content of a web page. Returns the text content of the page.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'The URL to fetch',
          },
        },
        'required': ['url'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final url = arguments['url'] as String?;
    if (url == null || url.isEmpty) {
      return ToolResult.error('Missing required parameter: url');
    }

    try {
      final client = http.Client();
      try {
        var currentUrl = url;
        http.Response? response;

        // Follow redirects manually
        for (var i = 0; i <= maxRedirects; i++) {
          final request = http.Request('GET', Uri.parse(currentUrl))
            ..followRedirects = false;
          final streamedResponse = await client.send(request);
          response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode >= 300 &&
              response.statusCode < 400 &&
              response.headers['location'] != null) {
            final location = response.headers['location']!;
            currentUrl = location.startsWith('http')
                ? location
                : Uri.parse(currentUrl).resolve(location).toString();
            continue;
          }
          break;
        }

        if (response == null) {
          return ToolResult.error('Failed to fetch URL: no response');
        }

        if (response.statusCode != 200) {
          return ToolResult.error(
              'HTTP error ${response.statusCode} fetching $url');
        }

        var content = response.body;

        // Strip HTML tags to extract text content
        content = _stripHtml(content);

        // Truncate if needed
        if (content.length > maxChars) {
          content =
              '${content.substring(0, maxChars)}\n\n[Content truncated at $maxChars characters]';
        }

        if (content.trim().isEmpty) {
          return ToolResult.simple('Page fetched but no text content found.');
        }

        return ToolResult.dual(
          forLLM: content,
          forUser: 'Fetched ${content.length} chars from $url',
        );
      } finally {
        client.close();
      }
    } catch (e) {
      return ToolResult.error('Failed to fetch $url: $e');
    }
  }

  /// Basic HTML stripping: remove tags, decode common entities, collapse whitespace.
  String _stripHtml(String html) {
    // Remove script and style blocks
    var text = html.replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), '');
    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // Decode common HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    // Restore some line breaks
    text = text.replaceAll(RegExp(r' {3,}'), '\n');
    return text.trim();
  }
}
