import 'package:html2md/html2md.dart' as html2md;

/// Converts HTML content to structured Markdown, stripping noise elements.
/// Shared by both WebScrapeTool and WebScrapeJsTool.
String htmlToMarkdown(String html, {int? maxChars}) {
  var markdown = html2md.convert(
    html,
    ignore: ['script', 'style', 'nav', 'footer', 'header', 'aside', 'noscript'],
    styleOptions: {
      'headingStyle': 'atx',
      'codeBlockStyle': 'fenced',
      'bulletListMarker': '-',
    },
  );

  // Collapse excessive blank lines
  markdown = markdown.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  if (maxChars != null && markdown.length > maxChars) {
    markdown =
        '${markdown.substring(0, maxChars)}\n\n[Truncated at $maxChars characters]';
  }

  return markdown.trim();
}
