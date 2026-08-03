import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/deep_link/deep_link_resolver.dart';

void main() {
  const resolver = DeepLinkResolver();

  DeepLinkResolution? resolve(String uri) => resolver.resolve(Uri.parse(uri));

  group('scheme handling', () {
    test('scheme match is case-insensitive (JEEB:// resolves)', () {
      // Uri lower-cases the scheme, so an uppercase custom scheme still folds.
      final res = resolve('JEEB://orders/d-1');
      expect(res, isNotNull);
      expect(res!.location, '/orders/d-1');
      expect(res.requiresAuth, isTrue);
    });

    test('an unsupported scheme (mailto) returns null', () {
      expect(resolve('mailto:ops@jeeb.app'), isNull);
    });

    test('a bare custom-scheme link with no host or path returns null', () {
      expect(resolve('jeeb://'), isNull);
    });
  });

  group('fragment + query normalisation', () {
    test('a fragment is dropped from the resolved location', () {
      expect(resolve('jeeb://orders/d-1#section')?.location, '/orders/d-1');
    });

    test('query is preserved while the fragment is dropped', () {
      expect(
        resolve('jeeb://orders/d-1/otp?mode=jeeber#frag')?.location,
        '/orders/d-1/otp?mode=jeeber',
      );
    });

    test('a multi-pair query string is preserved verbatim', () {
      expect(
        resolve('jeeb://wallet/tx-1?from=2024&to=2025')?.location,
        '/wallet/tx-1?from=2024&to=2025',
      );
    });
  });

  group('path-separator hygiene', () {
    test('a trailing slash is collapsed (no empty terminal segment)', () {
      expect(resolve('jeeb://orders/')?.location, '/orders');
    });

    test('duplicate inner slashes collapse to a single separator', () {
      expect(resolve('jeeb://orders//d-1')?.location, '/orders/d-1');
    });

    test('an empty custom-scheme host (jeeb:///d-1) still resolves the path '
        'but is NOT classified as an auth route', () {
      final res = resolve('jeeb:///d-1');
      expect(res, isNotNull);
      expect(res!.location, '/d-1');
      // First segment is 'd-1', not a known user-scoped prefix.
      expect(res.requiresAuth, isFalse);
    });
  });

  group('hostile id rejection', () {
    test('percent-encoded slash + traversal (orders/d%2f..) is rejected', () {
      // %2f decodes to a separator that would smuggle a '..' segment; the
      expect(resolve('jeeb://orders/d%2f..'), isNull);
    });

    test('an encoded-space id is rejected (disallowed charset)', () {
      expect(resolve('jeeb://orders/d%201'), isNull);
    });

    test('an encoded ../admin id smuggled via %2f neutralises the whole link',
        () {
      // %2e%2e%2fadmin decodes to the single segment "../admin" — the embedded
      expect(resolve('jeeb://chat/%2e%2e%2fadmin'), isNull);
    });

    test(
        'a trailing dot-segment can never ESCAPE: Uri normalises it away, so '
        'jeeb://orders/.. lands on the bare parent (/orders), not above it', () {
      // Defence-in-depth note: dot-segments are removed by Uri.pathSegments
      final res = resolve('jeeb://orders/..');
      expect(res, isNotNull);
      expect(res!.location, '/orders');
    });
  });

  group('auth-gate classification — full user-scoped prefix matrix', () {
    // Every prefix the resolver flags as user-scoped MUST classify as
    const authPrefixes = <String>[
      'orders',
      'chat',
      'wallet',
      'disputes',
      'requests',
      'jeeber',
      'earnings',
      'notifications',
      'profile',
      'settings',
    ];

    for (final prefix in authPrefixes) {
      test('jeeb://$prefix/x-1 requires auth', () {
        final res = resolve('jeeb://$prefix/x-1');
        expect(res, isNotNull, reason: '$prefix should resolve');
        expect(res!.requiresAuth, isTrue,
            reason: '$prefix is user-scoped and must pass the auth gate');
      });

      test('host-only jeeb://$prefix requires auth', () {
        expect(resolve('jeeb://$prefix')?.requiresAuth, isTrue);
      });
    }

    test('a public route (jeeb://about) does NOT require auth', () {
      final res = resolve('jeeb://about');
      expect(res, isNotNull);
      expect(res!.requiresAuth, isFalse);
    });

    test('resolveLocation convenience matches resolve().location', () {
      expect(
        resolver.resolveLocation(Uri.parse('jeeb://wallet/tx-9')),
        resolve('jeeb://wallet/tx-9')!.location,
      );
    });

    test('resolveLocation returns null for a rejected link', () {
      expect(
        resolver.resolveLocation(Uri.parse('jeeb://orders/d%2f..')),
        isNull,
      );
    });
  });
}
