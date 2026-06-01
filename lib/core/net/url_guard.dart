import 'dart:io';
import 'dart:typed_data';

/// Thrown when a URL is rejected by [UrlGuard].
class UrlGuardException implements Exception {
  final String message;
  const UrlGuardException(this.message);
  @override
  String toString() => 'UrlGuardException: $message';
}

/// Resolves a hostname to its addresses. Injectable for tests.
typedef HostResolver = Future<List<InternetAddress>> Function(String host);

/// Guards LLM-/content-driven outbound fetches against SSRF.
///
/// Enforces an http/https scheme allowlist and rejects hosts that resolve to
/// private (RFC1918), loopback, link-local, CGNAT, or IPv6 unique-local
/// ranges. Callers must re-validate after each redirect (the lightweight
/// HTTP scraper follows redirects manually, so an external page cannot
/// redirect into the private range without tripping the guard again).
///
/// Residual — DNS rebinding: [validate] resolves the host and checks the
/// addresses, but the HTTP client / WebView resolves again at connect time,
/// so a hostname that flips to a private IP between the two resolutions is
/// not fully closed here. Closing it requires pinning the validated IP into
/// the connection (connect-by-IP with a Host header / SNI), which the current
/// lightweight fetch path does not support. The redirect re-validation closes
/// the far more common redirect-to-internal vector.
class UrlGuard {
  static const Set<String> _allowedSchemes = {'http', 'https'};

  /// Validate [url]. Throws [UrlGuardException] when the scheme is not
  /// http/https or the host resolves to a non-public address.
  static Future<void> validate(String url, {HostResolver? resolver}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      throw const UrlGuardException('only http and https URLs are allowed');
    }
    final host = uri.host;
    if (host.isEmpty) {
      throw const UrlGuardException('URL has no host');
    }

    final literal = InternetAddress.tryParse(host);
    final List<InternetAddress> addresses;
    if (literal != null) {
      addresses = [literal];
    } else {
      try {
        addresses = await (resolver ?? _defaultResolver)(host);
      } catch (_) {
        throw UrlGuardException('could not resolve host "$host"');
      }
    }
    if (addresses.isEmpty) {
      throw UrlGuardException('host "$host" did not resolve');
    }
    for (final addr in addresses) {
      if (isBlockedAddress(addr)) {
        throw UrlGuardException(
            'host "$host" resolves to a private or local address');
      }
    }
  }

  static Future<List<InternetAddress>> _defaultResolver(String host) =>
      InternetAddress.lookup(host);

  /// Whether [addr] falls in a range that must not be reachable from an
  /// LLM-controlled fetch.
  static bool isBlockedAddress(InternetAddress addr) {
    if (addr.isLoopback || addr.isLinkLocal || addr.isMulticast) return true;
    final b = addr.rawAddress;
    if (addr.type == InternetAddressType.IPv4 && b.length == 4) {
      if (b[0] == 0) return true; // 0.0.0.0/8
      if (b[0] == 10) return true; // 10.0.0.0/8
      if (b[0] == 127) return true; // 127.0.0.0/8
      if (b[0] == 169 && b[1] == 254) return true; // 169.254.0.0/16
      if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true; // 172.16/12
      if (b[0] == 192 && b[1] == 168) return true; // 192.168.0.0/16
      if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true; // 100.64/10
      return false;
    }
    if (addr.type == InternetAddressType.IPv6 && b.length == 16) {
      if (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) return true; // fe80::/10
      if ((b[0] & 0xFE) == 0xFC) return true; // fc00::/7 (ULA)
      // IPv4-mapped IPv6 (::ffff:a.b.c.d) — re-check the embedded v4 address.
      if (b[10] == 0xFF && b[11] == 0xFF) {
        return isBlockedAddress(
            InternetAddress.fromRawAddress(Uint8List.fromList(b.sublist(12))));
      }
      return false;
    }
    return false;
  }
}
