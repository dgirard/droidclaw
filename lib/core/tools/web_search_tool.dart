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
    final uri = Uri.parse('https://api.duckduckgo.com/').replace(
      queryParameters: {'q': query, 'format': 'json', 'no_html': '1'},
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return ToolResult.error(
          'DuckDuckGo search error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final buffer = StringBuffer();

    final abstract_ = data['Abstract'] as String?;
    if (abstract_ != null && abstract_.isNotEmpty) {
      buffer.writeln('Summary: $abstract_');
      buffer.writeln('Source: ${data['AbstractURL']}');
      buffer.writeln();
    }

    final relatedTopics = data['RelatedTopics'] as List? ?? [];
    for (final topic in relatedTopics.take(maxResults)) {
      if (topic is Map && topic.containsKey('Text')) {
        buffer.writeln('- ${topic['Text']}');
        if (topic['FirstURL'] != null) {
          buffer.writeln('  URL: ${topic['FirstURL']}');
        }
      }
    }

    final content = buffer.toString().trimRight();
    if (content.isEmpty) {
      return ToolResult.simple('No results found for: $query');
    }
    return ToolResult.simple(content);
  }
}
