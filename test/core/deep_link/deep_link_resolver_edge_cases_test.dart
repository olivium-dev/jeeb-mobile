// Edge-case guard for `DeepLinkResolver` (Sprint-3 deeplink; coverage extended
// Sprint-6 Stream D). Complements `deep_link_resolver_test.dart` with the URI
// shapes a hostile or sloppy platform link can actually carry — scheme casing,
// fragments, empty/duplicate path separators, percent-encoded traversal, and
// the FULL auth-prefix matrix — so the auth-gate classification and the bad-id
// rejection are pinned for every user-scoped route, not just a sampled one.
//
// All expected values were verified against the live `Uri.parse` semantics on
// the project's Flutter toolchain before being asserted (Uri lower-cases the
// scheme and host, strips the fragment from `query`, and drops empty segments).

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
      // resolver must refuse the whole link rather than route a crafted id.
      expect(resolve('jeeb://orders/d%2f..'), isNull);
    });

    test('an encoded-space id is rejected (disallowed charset)', () {
      expect(resolve('jeeb://orders/d%201'), isNull);
    });

    test('an encoded ../admin id smuggled via %2f neutralises the whole link',
        () {
      // %2e%2e%2fadmin decodes to the single segment "../admin" — the embedded
      // slash fails the unreserved-charset id pattern, so the link is refused.
      expect(resolve('jeeb://chat/%2e%2e%2fadmin'), isNull);
    });

    test(
        'a trailing dot-segment can never ESCAPE: Uri normalises it away, so '
        'jeeb://orders/.. lands on the bare parent (/orders), not above it', () {
      // Defence-in-depth note: dot-segments are removed by Uri.pathSegments
      // before the resolver runs, so a "../" can never climb out of the route
      // namespace. The resolved location stays within /orders.
      final res = resolve('jeeb://orders/..');
      expect(res, isNotNull);
      expect(res!.location, '/orders');
    });
  });

  group('auth-gate classification — full user-scoped prefix matrix', () {
    // Every prefix the resolver flags as user-scoped MUST classify as
    // requiresAuth so the router's first-run redirect gates it. A regression
    // that drops one of these would silently expose user data via deep link.
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
