// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:test/test.dart';

import 'package:droidclaw/core/net/url_guard.dart';

/// Fake resolver returning a fixed list, ignoring the host.
HostResolver fixed(List<String> ips) =>
    (host) async => ips.map((ip) => InternetAddress(ip)).toList();

void main() {
  group('scheme allowlist', () {
    test('rejects non-http(s) schemes', () {
      for (final url in [
        'file:///etc/passwd',
        'javascript:alert(1)',
        'ftp://example.com/x',
        'data:text/html,hi',
      ]) {
        expect(UrlGuard.validate(url), throwsA(isA<UrlGuardException>()),
            reason: url);
      }
    });

    test('rejects URLs with no host', () {
      expect(UrlGuard.validate('http://'), throwsA(isA<UrlGuardException>()));
    });
  });

  group('literal private/local IPs are blocked', () {
    final blocked = [
      'http://127.0.0.1/',
      'http://10.0.0.1/',
      'http://192.168.1.1/',
      'http://172.16.5.5/',
      'http://172.31.0.1/',
      'http://169.254.169.254/latest/meta-data',
      'http://100.64.0.1/',
      'http://0.0.0.0/',
    ];
    for (final url in blocked) {
      test('blocks $url', () {
        expect(UrlGuard.validate(url), throwsA(isA<UrlGuardException>()));
      });
    }
  });

  group('public addresses are allowed', () {
    test('literal public IPv4', () async {
      // 93.184.216.34 (example.com) — no resolver needed for a literal.
      await UrlGuard.validate('https://93.184.216.34/');
    });

    test('hostname resolving to a public IP', () async {
      await UrlGuard.validate('https://example.com/page',
          resolver: fixed(['93.184.216.34']));
    });
  });

  group('hostname resolution', () {
    test('rejects a hostname that resolves to a private IP', () {
      expect(
        UrlGuard.validate('https://internal.evil.test/',
            resolver: fixed(['10.0.0.5'])),
        throwsA(isA<UrlGuardException>()),
      );
    });

    test('rejects when any resolved address is private', () {
      expect(
        UrlGuard.validate('https://mixed.test/',
            resolver: fixed(['93.184.216.34', '192.168.0.10'])),
        throwsA(isA<UrlGuardException>()),
      );
    });

    test('DNS rebinding: re-validation catches a flipped resolution', () async {
      var call = 0;
      Future<List<InternetAddress>> flipping(String host) async {
        call++;
        return [InternetAddress(call == 1 ? '93.184.216.34' : '10.0.0.9')];
      }
      // First resolution is public — passes.
      await UrlGuard.validate('https://rebind.test/', resolver: flipping);
      // A later hop re-resolves to a private IP — blocked.
      expect(UrlGuard.validate('https://rebind.test/', resolver: flipping),
          throwsA(isA<UrlGuardException>()));
    });
  });

  group('isBlockedAddress IPv6', () {
    test('blocks unique-local and link-local, allows public', () {
      expect(UrlGuard.isBlockedAddress(InternetAddress('fc00::1')), isTrue);
      expect(UrlGuard.isBlockedAddress(InternetAddress('fe80::1')), isTrue);
      expect(UrlGuard.isBlockedAddress(InternetAddress('::1')), isTrue);
      expect(UrlGuard.isBlockedAddress(InternetAddress('2606:2800:220:1::')),
          isFalse);
    });
  });
}
