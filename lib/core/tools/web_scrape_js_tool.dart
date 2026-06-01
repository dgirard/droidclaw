import 'dart:async';
import 'dart:ui';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../shared/constants.dart';
import '../net/url_guard.dart';
import 'html_to_markdown.dart';
import 'tool.dart';

/// WebView-based web scraper: loads pages in a headless browser that
/// executes JavaScript. For SPAs, dynamic sites, and JS-rendered content.
class WebScrapeJsTool extends Tool {
  final int maxChars;
  final int timeoutSeconds;

  WebScrapeJsTool({
    this.maxChars = AppConstants.webScrapeMaxChars,
    this.timeoutSeconds = AppConstants.webScrapeJsTimeoutSeconds,
  });

  @override
  String get name => 'web_scrape_js';

  @override
  String get description =>
      'Fetch a web page using a full browser engine that executes JavaScript. '
      'Use when web_scrape returns empty or insufficient results, which '
      'indicates a JavaScript-rendered page (SPA, React, Vue, dynamic content). '
      'Slower and heavier than web_scrape.';

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

    // SSRF guard before loading. Note: the WebView can still issue
    // sub-requests (XHR/iframe) that bypass this pre-load check — tracked as a
    // residual for the deferred WebView sandbox review.
    try {
      await UrlGuard.validate(url);
    } on UrlGuardException catch (e) {
      return ToolResult.error('Blocked URL: ${e.message}');
    }

    HeadlessInAppWebView? headless;
    try {
      final completer = Completer<String?>();

      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSize: const Size(1080, 1920),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          blockNetworkImage: true,
          loadsImagesAutomatically: false,
          cacheEnabled: false,
          javaScriptCanOpenWindowsAutomatically: false,
        ),
        onLoadStop: (controller, loadedUrl) async {
          if (completer.isCompleted) return;

          // Wait for post-load JS rendering (SPAs often render after onload)
          await Future.delayed(const Duration(seconds: 2));

          // Extract the full rendered HTML
          final html = await controller.getHtml();
          if (!completer.isCompleted) {
            completer.complete(html);
          }
        },
        onReceivedError: (controller, request, error) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      await headless.run();

      // Wait with timeout
      final html = await completer.future.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => null,
      );

      // Dispose immediately to free memory
      await headless.dispose();
      headless = null;

      if (html == null || html.isEmpty) {
        return ToolResult.error(
            'Failed to scrape $url: page load timed out or returned no content');
      }

      // Convert HTML to structured Markdown
      final markdown = htmlToMarkdown(html, maxChars: maxChars);

      if (markdown.isEmpty) {
        return ToolResult.simple(
            'Page loaded with JavaScript but no text content found.');
      }

      return ToolResult.dual(
        forLLM: markdown,
        forUser: 'Scraped ${markdown.length} chars (JS) from $url',
      );
    } catch (e) {
      return ToolResult.error('Failed to scrape $url: $e');
    } finally {
      // Safety net: ensure WebView is always disposed
      await headless?.dispose();
    }
  }
}
