import 'package:http/http.dart' as http;

import '../../shared/constants.dart';
import '../net/url_guard.dart';
import 'html_to_markdown.dart';
import 'tool.dart';

/// Lightweight web scraper: HTTP GET + HTML parsing + Markdown output.
/// For static sites, blogs, news, documentation.
class WebScrapeTool extends Tool {
  final int maxChars;
  final int maxRedirects;

  WebScrapeTool({
    this.maxChars = AppConstants.webScrapeMaxChars,
    this.maxRedirects = AppConstants.webFetchMaxRedirects,
  });

  @override
  String get name => 'web_scrape';

  @override
  String get description =>
      'Fetch a web page and extract its content as structured Markdown. '
      'Works on static sites, blogs, news, documentation. '
      'If the result is empty, the page likely requires JavaScript — '
      'use web_scrape_js instead.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'The URL to scrape',
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
          // SSRF guard: re-checked on every hop so a public page cannot
          // redirect into a private/loopback address.
          try {
            await UrlGuard.validate(currentUrl);
          } on UrlGuardException catch (e) {
            return ToolResult.error('Blocked URL: ${e.message}');
          }
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

        // Convert HTML to structured Markdown
        final markdown = htmlToMarkdown(response.body, maxChars: maxChars);

        if (markdown.isEmpty) {
          return ToolResult.simple(
              'Page fetched but no text content found. '
              'The page may require JavaScript — try web_scrape_js.');
        }

        return ToolResult.dual(
          forLLM: markdown,
          forUser: 'Scraped ${markdown.length} chars from $url',
        );
      } finally {
        client.close();
      }
    } catch (e) {
      return ToolResult.error('Failed to scrape $url: $e');
    }
  }
}
