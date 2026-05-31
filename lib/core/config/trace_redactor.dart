/// Redacts sensitive content (PII, secrets) from LLM trace data before it is
/// persisted or displayed.
///
/// Applied at the [LlmTraceLogger] write boundary so every trace construction
/// site (chat, summarize, extract) is covered without each call site needing
/// to remember to scrub. Two strategies:
///
/// - **Wholesale**: tool-role messages from tools whose results routinely carry
///   PII (contacts, calendar, location, personal knowledge) have their preview
///   replaced entirely — the content is structured PII that pattern-matching
///   would only partially catch.
/// - **Pattern**: free text (system-prompt previews, responses, other message
///   previews) is scrubbed for emails, phone numbers, bearer/token strings,
///   known API-key prefixes, and the injected `<knowledge_context>` block.
class TraceRedactor {
  /// Tool names whose results routinely carry PII or personal knowledge.
  static const Set<String> sensitiveTools = {
    'contacts',
    'calendar',
    'get_location',
    'get_address',
    'geocode',
    'reverse_geocode',
    'get_directions',
    'get_transit',
    'knowledge_search',
    'knowledge_store',
    'kb_query',
  };

  static final RegExp _knowledgeBlock = RegExp(
    r'<knowledge_context[^>]*>.*?(?:</knowledge_context>|$)',
    dotAll: true,
  );
  static final RegExp _bearer =
      RegExp(r'bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false);
  static final RegExp _tokenParam = RegExp(
    r'(token|api[_-]?key|secret|password)\s*[=:]\s*[^\s&"]+',
    caseSensitive: false,
  );
  static final RegExp _knownKeyPrefix = RegExp(
    r'(sk-[A-Za-z0-9]{8,}|AIza[A-Za-z0-9_\-]{8,}|xox[baprs]-[A-Za-z0-9-]+)',
  );
  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  // A run starting and ending with a digit, 8+ chars of digits/separators.
  static final RegExp _phone = RegExp(r'\+?\d[\d\s().\-]{6,}\d');

  /// Redact free-text content. Idempotent — re-running on redacted text is a
  /// no-op, so applying it on read after a write-time redaction is safe.
  static String redactText(String input) {
    if (input.isEmpty) return input;
    var out = input;
    out = out.replaceAll(
        _knowledgeBlock, '<knowledge_context>[redacted]</knowledge_context>');
    out = out.replaceAll(_bearer, 'Bearer [redacted-token]');
    out = out.replaceAllMapped(
        _tokenParam, (m) => '${m.group(1)}=[redacted]');
    out = out.replaceAll(_knownKeyPrefix, '[redacted-key]');
    out = out.replaceAll(_email, '[redacted-email]');
    out = out.replaceAll(_phone, '[redacted-phone]');
    return out;
  }

  /// Return a redacted copy of a trace's JSON map, ready to persist.
  static Map<String, dynamic> redactTraceJson(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.of(json);

    final sysPreview = result['systemPromptPreview'];
    if (sysPreview is String) {
      result['systemPromptPreview'] = redactText(sysPreview);
    }
    final response = result['responseContent'];
    if (response is String) {
      result['responseContent'] = redactText(response);
    }

    final messages = result['messages'];
    if (messages is List) {
      result['messages'] = messages.map((m) {
        if (m is! Map) return m;
        final msg = Map<String, dynamic>.of(m.cast<String, dynamic>());
        final role = msg['role'];
        final toolName = msg['toolName'];
        final preview = msg['preview'];
        if (preview is String) {
          if (role == 'tool' &&
              toolName is String &&
              sensitiveTools.contains(toolName)) {
            msg['preview'] = '[redacted: $toolName result]';
          } else {
            msg['preview'] = redactText(preview);
          }
        }
        return msg;
      }).toList();
    }

    return result;
  }
}
