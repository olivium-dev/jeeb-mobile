// Unit tests for the pure deep-link resolution plumbing (Sprint 3 — stream

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/deep_link/deep_link_resolver.dart';

void main() {
  const resolver = DeepLinkResolver();

  Uri u(String s) => Uri.parse(s);

  group('DeepLinkResolver — custom scheme host→path fold', () {
    test('jeeb://orders/d-1 resolves to /orders/d-1', () {
      expect(resolver.resolveLocation(u('jeeb://orders/d-1')), '/orders/d-1');
    });

    test('host-only link jeeb://wallet resolves to /wallet', () {
      expect(resolver.resolveLocation(u('jeeb://wallet')), '/wallet');
    });

    test('nested path jeeb://orders/d-1/tracking resolves fully', () {
      expect(
        resolver.resolveLocation(u('jeeb://orders/d-1/tracking')),
        '/orders/d-1/tracking',
      );
    });

    test('jeeb://wallet/transactions/tx-9 resolves to the ledger row', () {
      expect(
        resolver.resolveLocation(u('jeeb://wallet/transactions/tx-9')),
        '/wallet/transactions/tx-9',
      );
    });

    test('chat link resolves to /chat/<id>', () {
      expect(resolver.resolveLocation(u('jeeb://chat/c-7')), '/chat/c-7');
    });

    test('query string is preserved (e.g. ?mode=jeeber)', () {
      expect(
        resolver.resolveLocation(u('jeeb://orders/d-1/otp?mode=jeeber')),
        '/orders/d-1/otp?mode=jeeber',
      );
    });
  });

  group('DeepLinkResolver — https universal links', () {
    test('https domain is dropped, path kept', () {
      expect(
        resolver.resolveLocation(u('https://jeeb.app/orders/d-1')),
        '/orders/d-1',
      );
    });

    test('https with query preserves query', () {
      expect(
        resolver.resolveLocation(u('https://jeeb.app/disputes/dp-2?x=1')),
        '/disputes/dp-2?x=1',
      );
    });
  });

  group('DeepLinkResolver — auth/ownership classification', () {
    test('user-data routes require auth', () {
      for (final link in [
        'jeeb://orders/d-1',
        'jeeb://chat/c-1',
        'jeeb://wallet',
        'jeeb://disputes/dp-1',
        'jeeb://profile/customer',
      ]) {
        expect(resolver.resolve(u(link))!.requiresAuth, isTrue,
            reason: '$link should require auth');
      }
    });

    test('non-user-data route does not require auth', () {
      // `/support` is reachable as an unblocked exit; not in the auth set.
      final res = resolver.resolve(u('jeeb://support'));
      expect(res, isNotNull);
      expect(res!.requiresAuth, isFalse);
    });
  });

  group('DeepLinkResolver — hostile / malformed ids rejected', () {
    test('path traversal is neutralised, never escapes (no .. in output)', () {
      // Dart `Uri.parse` RFC-normalises dot-segments before we see them, so a
      final a = resolver.resolveLocation(u('jeeb://orders/..'));
      expect(a, '/orders');
      expect(a, isNot(contains('..')));
      final b = resolver.resolveLocation(u('jeeb://orders/../admin'));
      expect(b, '/orders/admin');
      expect(b, isNot(contains('..')));
    });

    test('dot segment is neutralised', () {
      expect(resolver.resolveLocation(u('jeeb://orders/.')), '/orders');
    });

    test('id with a disallowed char is rejected', () {
      // A space (percent-decoded) is not in the unreserved id charset.
      expect(resolver.resolveLocation(u('jeeb://orders/d%201')), isNull);
    });

    test('empty / scheme-only link returns null', () {
      expect(resolver.resolveLocation(u('jeeb://')), isNull);
    });

    test('unsupported scheme returns null', () {
      expect(resolver.resolveLocation(u('mailto:x@y.com')), isNull);
      expect(resolver.resolveLocation(u('ftp://orders/d-1')), isNull);
    });

    test('well-formed ids with unreserved chars are accepted', () {
      expect(resolver.resolveLocation(u('jeeb://orders/d_1.2-3~x')),
          '/orders/d_1.2-3~x');
    });
  });
}
