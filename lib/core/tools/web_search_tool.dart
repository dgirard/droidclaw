import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants.dart';
import 'tool.dart';

/// Web search tool using Brave Search API (primary) or DuckDuckGo (fallback).
class WebSearchTool extends Tool {
  final String? braveApiKey;
  final int maxResults;

  WebSearchTool({
    this.braveApiKey,
    this.maxResults = AppConstants.webSearchMaxResults,
  });

  @override
  String get name => 'web_search';

  @override
  String get description =>
      'Search the web for current information. Returns titles, URLs, and descriptions.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query',
          },
        },
        'required': ['query'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String?;
    if (query == null || query.isEmpty) {
      return ToolResult.error('Missing required parameter: query');
    }

    try {
      if (braveApiKey != null && braveApiKey!.isNotEmpty) {
        return await _searchBrave(query);
      }
      return await _searchDuckDuckGo(query);
    } catch (e) {
      return ToolResult.error('Search failed: $e');
    }
  }

  Future<ToolResult> _searchBrave(String query) async {
    final uri = Uri.parse('https://api.search.brave.com/res/v1/web/search')
        .replace(queryParameters: {'q': query, 'count': '$maxResults'});

    final response = await http.get(uri, headers: {
      'X-Subscription-Token': braveApiKey!,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      return ToolResult.error('Brave search error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results =
        (data['web']?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (results.isEmpty) {
      return ToolResult.simple('No results found for: $query');
    }

    // Build dual content
    final llmBuffer = StringBuffer();
    final userBuffer = StringBuffer();

    for (final result in results.take(maxResults)) {
      final title = result['title'] ?? 'No title';
      final url = result['url'] ?? '';
      final desc = result['description'] ?? 'No description';

      llmBuffer.writeln('Title: $title');
      llmBuffer.writeln('URL: $url');
      llmBuffer.writeln('Description: $desc');
      llmBuffer.writeln();

      userBuffer.writeln('**[$title]($url)**');
      userBuffer.writeln('$desc\n');
    }

    return ToolResult.dual(
      forLLM: llmBuffer.toString().trimRight(),
      forUser: userBuffer.toString().trimRight(),
    );
  }

  Future<ToolResult> _searchDuckDuckGo(String query) async {
    // Use DuckDuckGo HTML search endpoint (the JSON Instant Answer API
    // only returns results for well-known entities, not general queries).
    final uri = Uri.parse('https://html.duckduckgo.com/html/');

    final response = await http.post(uri, body: {'q': query}, headers: {
      'User-Agent': 'DroidClaw/1.0',
    });

    if (response.statusCode != 200) {
      return ToolResult.error(
          'DuckDuckGo search error: ${response.statusCode}');
    }

    final html = response.body;

    // Parse search results from HTML.
    // Each result is in a <div class="result..."> with:
    //   <a class="result__a" href="...">title</a>
    //   <a class="result__snippet">description</a>
    final resultPattern = RegExp(
      r'class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>'
      r'[\s\S]*?'
      r'class="result__snippet"[^>]*>(.*?)</a>',
    );

    final matches = resultPattern.allMatches(html).take(maxResults).toList();

    if (matches.isEmpty) {
      return ToolResult.simple('No results found for: $query');
    }

    final llmBuffer = StringBuffer();
    final userBuffer = StringBuffer();

    for (final match in matches) {
      var url = match.group(1) ?? '';
      final title = _stripHtml(match.group(2) ?? 'No title');
      final desc = _stripHtml(match.group(3) ?? 'No description');

      // DuckDuckGo wraps URLs through a redirect — extract the real URL.
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (uddgMatch != null) {
        url = Uri.decodeComponent(uddgMatch.group(1)!);
      }

      llmBuffer.writeln('Title: $title');
      llmBuffer.writeln('URL: $url');
      llmBuffer.writeln('Description: $desc');
      llmBuffer.writeln();

      userBuffer.writeln('**[$title]($url)**');
      userBuffer.writeln('$desc\n');
    }

    return ToolResult.dual(
      forLLM: llmBuffer.toString().trimRight(),
      forUser: userBuffer.toString().trimRight(),
    );
  }

  /// Strip HTML tags and decode common HTML entities.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
