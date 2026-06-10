import 'dart:convert';

/// Shared parser for JSON returned by LLMs (U17).
///
/// Replaces the fence-strip + `jsonDecode` blocks that were re-implemented
/// in `kb_maintenance_service.dart` (4 sites) and `entity_extractor.dart`.
///
/// Two decode flavors preserve the behaviors found at the original sites:
/// - [decodeObject] throws on malformed input — for callers that handle (or
///   deliberately propagate) parse failures themselves, like
///   `parseCleanupResponse` which lets a malformed cleanup proposal bubble up.
/// - [tryDecodeObject] / [tryDecodeList] return null on malformed input
///   without throwing — for callers that fall back to a safe default.
class LlmJsonParser {
  LlmJsonParser._();

  static final _leadingFenceRe = RegExp(r'^```\w*\n?');
  static final _trailingFenceRe = RegExp(r'\n?```$');

  /// Trim [content] and strip a surrounding markdown code fence
  /// (```` ```json ... ``` ````) if present.
  static String stripFences(String content) {
    var json = content.trim();
    if (json.startsWith('```')) {
      json = json.replaceFirst(_leadingFenceRe, '');
      json = json.replaceFirst(_trailingFenceRe, '');
    }
    return json;
  }

  /// Strip fences and decode a JSON object.
  ///
  /// Throws ([FormatException] / [TypeError]) when the content is not a
  /// valid JSON object — matching the original `parseCleanupResponse`
  /// behavior which propagates parse failures to the caller.
  static Map<String, dynamic> decodeObject(String content) {
    return jsonDecode(stripFences(content)) as Map<String, dynamic>;
  }

  /// Strip fences and decode a JSON object; null when malformed or not an
  /// object. Never throws.
  static Map<String, dynamic>? tryDecodeObject(String content) {
    try {
      final decoded = jsonDecode(stripFences(content));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Strip fences and decode a JSON list; null when malformed or not a
  /// list. Never throws.
  static List<dynamic>? tryDecodeList(String content) {
    try {
      final decoded = jsonDecode(stripFences(content));
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
