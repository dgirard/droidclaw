---
title: "feat: Replace web_fetch with dual web scrapers"
type: feat
date: 2026-02-16
---

# Replace web_fetch with Dual Web Scrapers

## Overview

Replace the current basic `web_fetch` tool (regex HTML stripping, plain text output) with two specialized scrapers:

1. **`web_scrape`** — Lightweight HTTP scraper: `http` + `html` parser + `html2md` for structured Markdown output
2. **`web_scrape_js`** — Heavy WebView scraper: headless `flutter_inappwebview` for JS-rendered pages (SPAs, dynamic sites)

The LLM chooses which to use based on context. It should prefer `web_scrape` (fast, low resources) and fall back to `web_scrape_js` when content is empty or insufficient (indicating a JS-rendered page).

## Problem

The current `web_fetch_tool.dart` has three weaknesses:
- **Regex-based HTML stripping** — fragile, misses complex HTML, only decodes 6 entities
- **Plain text output** — loses structure (headings, links, lists) that helps the LLM understand page content
- **No JavaScript support** — returns empty content for SPAs, React/Vue/Angular apps, dynamic sites

## Implementation

### 1. Add dependencies

**`pubspec.yaml`**:

```yaml
html: ^0.15.6                    # HTML parsing with CSS selectors (Dart team)
html2md: ^1.3.2                  # HTML to Markdown conversion
flutter_inappwebview: ^6.1.5     # Headless WebView for JS-rendered pages
```

Keep `http: ^1.6.0` (already present, sufficient for simple GET requests).

### 2. Create `WebScrapeTool` (lightweight)

**`lib/core/tools/web_scrape_tool.dart`** — NEW

```dart
class WebScrapeTool extends Tool {
  final int maxChars;
  final int maxRedirects;

  WebScrapeTool({
    this.maxChars = AppConstants.webFetchMaxChars,
    this.maxRedirects = AppConstants.webFetchMaxRedirects,
  });

  @override String get name => 'web_scrape';

  @override String get description =>
      'Fetch a web page and extract its content as structured Markdown. '
      'Works on static sites, blogs, news, documentation. '
      'If the result is empty, the page likely requires JavaScript — use web_scrape_js instead.';

  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'url': {'type': 'string', 'description': 'The URL to scrape'},
    },
    'required': ['url'],
  };
}
```

**Pipeline:**
1. HTTP GET with manual redirect following (reuse existing pattern from `web_fetch_tool.dart`)
2. Parse HTML with `package:html` → DOM tree
3. Remove `<script>`, `<style>`, `<nav>`, `<footer>`, `<header>`, `<aside>` elements from DOM
4. Convert cleaned HTML to Markdown with `html2md.convert()` using options:
   - `ignore: ['script', 'style', 'nav', 'footer', 'header', 'aside']`
   - `styleOptions: {'headingStyle': 'atx', 'codeBlockStyle': 'fenced', 'bulletListMarker': '-'}`
5. Truncate to `maxChars`
6. Return `ToolResult.dual(forLLM: markdown, forUser: 'Scraped N chars from url')`

### 3. Create `WebScrapeJsTool` (WebView)

**`lib/core/tools/web_scrape_js_tool.dart`** — NEW

```dart
class WebScrapeJsTool extends Tool {
  final int maxChars;
  final int timeoutSeconds;

  WebScrapeJsTool({
    this.maxChars = AppConstants.webFetchMaxChars,
    this.timeoutSeconds = AppConstants.webScrapeJsTimeoutSeconds,
  });

  @override String get name => 'web_scrape_js';

  @override String get description =>
      'Fetch a web page using a full browser engine that executes JavaScript. '
      'Use when web_scrape returns empty or insufficient results, which indicates '
      'a JavaScript-rendered page (SPA, React, Vue, dynamic content).';

  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'url': {'type': 'string', 'description': 'The URL to scrape'},
    },
    'required': ['url'],
  };
}
```

**Pipeline:**
1. Create `HeadlessInAppWebView` with performance settings:
   - `javaScriptEnabled: true`
   - `blockNetworkImage: true`
   - `loadsImagesAutomatically: false`
   - `cacheEnabled: false`
   - `javaScriptCanOpenWindowsAutomatically: false`
2. Load URL, wait for `onLoadStop` callback
3. Wait 2 seconds extra for post-load JS rendering (SPAs often render after `onload`)
4. Extract HTML with `controller.getHtml()`
5. **Dispose the WebView immediately** (critical — prevents memory leaks)
6. Convert HTML to Markdown with `html2md.convert()` (same options as lightweight tool)
7. Truncate to `maxChars`
8. Return `ToolResult.dual(forLLM: markdown, forUser: 'Scraped N chars (JS) from url')`

**Timeout handling:** Use `Completer` with `.timeout()`. If timeout expires, dispose WebView and return error.

### 4. Add constant

**`lib/shared/constants.dart`**:

```dart
static const int webScrapeJsTimeoutSeconds = 30;
```

### 5. Update tool registration

**`lib/providers/app_providers.dart`**:

Replace:
```dart
if (!disabled.contains('web_fetch')) {
  registry.register(WebFetchTool());
}
```

With:
```dart
if (!disabled.contains('web_scrape')) {
  registry.register(WebScrapeTool());
}
if (!disabled.contains('web_scrape_js')) {
  registry.register(WebScrapeJsTool());
}
```

Update imports accordingly.

### 6. Update tool settings UI

**`lib/features/settings/tools_config_screen.dart`**:

Replace the `web_fetch` entry with:
```dart
_ToolInfo(
  name: 'web_scrape',
  label: 'Web Scrape',
  description: 'Lightweight page scraping (HTTP + Markdown)',
  icon: Icons.language,
),
_ToolInfo(
  name: 'web_scrape_js',
  label: 'Web Scrape (JS)',
  description: 'Heavy JS-rendered page scraping (WebView)',
  icon: Icons.web,
),
```

### 7. Delete old tool

Delete `lib/core/tools/web_fetch_tool.dart` — fully replaced by `web_scrape_tool.dart`.

### 8. Shared HTML→Markdown utility

Both tools use the same html2md conversion. Extract to a shared helper to avoid duplication:

**`lib/core/tools/html_to_markdown.dart`** — NEW

```dart
import 'package:html2md/html2md.dart' as html2md;

String htmlToMarkdown(String html, {int? maxChars}) {
  var markdown = html2md.convert(
    html,
    ignore: ['script', 'style', 'nav', 'footer', 'header', 'aside'],
    styleOptions: {
      'headingStyle': 'atx',
      'codeBlockStyle': 'fenced',
      'bulletListMarker': '-',
    },
  );

  // Collapse excessive blank lines
  markdown = markdown.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  if (maxChars != null && markdown.length > maxChars) {
    markdown = '${markdown.substring(0, maxChars)}\n\n[Truncated at $maxChars characters]';
  }

  return markdown.trim();
}
```

## Acceptance Criteria

- [ ] `html`, `html2md`, `flutter_inappwebview` added to `pubspec.yaml`
- [ ] `WebScrapeTool` created — HTTP GET + HTML parse + Markdown output
- [ ] `WebScrapeJsTool` created — HeadlessInAppWebView + JS render + Markdown output
- [ ] Shared `htmlToMarkdown()` utility created
- [ ] `web_fetch_tool.dart` deleted
- [ ] Tool registration updated in `app_providers.dart`
- [ ] Tool settings UI updated with two new entries
- [ ] `webScrapeJsTimeoutSeconds` constant added
- [ ] WebView always disposed after use (no memory leaks)
- [ ] WebView blocks images and disables cache for performance
- [ ] LLM tool descriptions guide it to prefer `web_scrape` and fall back to `web_scrape_js`
- [ ] `flutter analyze` passes
- [ ] APK builds and installs
- [ ] Test: scrape a static page (blog/docs) → returns Markdown with headings/links
- [ ] Test: scrape a JS-rendered SPA → `web_scrape` returns empty, `web_scrape_js` returns content

## Files Changed

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `html`, `html2md`, `flutter_inappwebview` |
| `lib/core/tools/html_to_markdown.dart` | **NEW** — shared HTML→Markdown conversion |
| `lib/core/tools/web_scrape_tool.dart` | **NEW** — lightweight HTTP scraper |
| `lib/core/tools/web_scrape_js_tool.dart` | **NEW** — WebView JS scraper |
| `lib/core/tools/web_fetch_tool.dart` | **DELETE** |
| `lib/shared/constants.dart` | Add `webScrapeJsTimeoutSeconds` |
| `lib/providers/app_providers.dart` | Replace web_fetch registration with two new tools |
| `lib/features/settings/tools_config_screen.dart` | Replace web_fetch entry with two new entries |

## References

- `lib/core/tools/tool.dart` — Tool, ToolResult, ToolRegistry
- `lib/core/tools/web_fetch_tool.dart` — current implementation to replace
- `lib/providers/app_providers.dart:81-99` — tool registration with disabledTools
- [html ^0.15.6](https://pub.dev/packages/html) — Dart HTML parser (CSS selectors, DOM)
- [html2md ^1.3.2](https://pub.dev/packages/html2md) — HTML to Markdown
- [flutter_inappwebview ^6.1.5](https://pub.dev/packages/flutter_inappwebview) — HeadlessInAppWebView
