/// Pure, Flutter-free deep-link resolution plumbing (Sprint 3 — stream
/// "deeplink").
///
/// PROBLEM this solves: go_router (v13) matches incoming links on `uri.path`
/// ONLY. For a CUSTOM-SCHEME link such as `jeeb://orders/d-1`, `Uri.parse`
/// yields `scheme=jeeb`, `host=orders`, `path=/d-1` — so go_router would try to
/// match `/d-1` and fail (the `orders` segment is stranded in the authority).
/// This resolver folds the authority/host back into the path so the link
/// resolves to the intended `GoRoute` (`/orders/:id`). HTTPS universal links
/// (`https://jeeb.app/orders/d-1`) already carry the full path, so only their
/// path+query is taken (the domain is dropped).
///
/// SECURITY (Sprint 3 guardrail — "deep-link routes enforce auth + ownership"):
///   * AUTH GATE — resolution alone never bypasses auth. Resolved links are fed
///     to `GoRouter`, whose top-level `_firstRunRedirect` (FR-P0-3) bounces an
///     unauthenticated user to the auth entry BEFORE any user-data screen
///     renders. [DeepLinkResolution.requiresAuth] flags the user-scoped routes
///     so callers/tests can assert this is in force.
///   * OWNERSHIP — a deep link carries an attacker-controllable resource id, so
///     we (a) validate every path segment against [_idPattern] and reject
///     traversal / blank / malformed segments here (a crafted
///     `jeeb://orders/..%2f..` can never resolve), and (b) rely on the gateway
///     to authorize the id against the bearer token server-side (it 403s a
///     delivery/order the caller does not own). The CLIENT never trusts the id
///     for cross-user access — it only routes a well-formed id into a screen
///     that fetches it under the user's JWT. Domain-verification file hosting
///     (assetlinks.json / AASA) is DEFERRED to infra.
///
/// Returns `null` for any unresolvable / malformed link — mirroring
/// `deepLinkForMessage`, the caller treats `null` as "ignore" rather than
/// crashing on a hostile or garbage payload.
library;

/// The outcome of resolving an inbound deep link to an in-app destination.
class DeepLinkResolution {
  const DeepLinkResolution({
    required this.location,
    required this.requiresAuth,
  });

  /// The go_router location (path + preserved query), e.g.
  /// `/orders/d-1` or `/orders/d-1/otp?mode=jeeber`.
  final String location;

  /// True when the destination shows user-scoped data and therefore MUST pass
  /// the router's auth gate. Informational — the gate is enforced by
  /// `AppRouter`'s redirect, not here.
  final bool requiresAuth;

  @override
  String toString() =>
      'DeepLinkResolution(location: $location, requiresAuth: $requiresAuth)';
}

/// Resolves inbound platform URIs (custom-scheme + universal links) to
/// go_router locations. Stateless and `const`-constructible.
class DeepLinkResolver {
  const DeepLinkResolver();

  /// The app's custom URI scheme (matches the Android `<data android:scheme>`
  /// intent-filter and the iOS associated-domains placeholder).
  static const String scheme = 'jeeb';

  /// Allowed charset for a SINGLE path segment: unreserved URI chars only. No
  /// slashes, no `.`/`..` traversal, no whitespace, no encoded separators.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._~-]+$');

  /// First path segment of routes that render USER-SCOPED data. A deep link
  /// into any of these must pass the auth gate (and we validate its id).
  /// `settings` is included because it carries the user's preferences.
  static const Set<String> _authPrefixes = <String>{
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
  };

  /// Convenience: returns just the go_router location, or `null`.
  String? resolveLocation(Uri uri) => resolve(uri)?.location;

  /// Resolves [uri] to an in-app destination, or `null` when it is not a
  /// recognised / well-formed Jeeb deep link.
  DeepLinkResolution? resolve(Uri uri) {
    final segments = _foldedSegments(uri);
    if (segments == null || segments.isEmpty) return null;

    // Reject traversal / blank / malformed segments BEFORE building a location
    // so a hostile id can never reach a screen.
    for (final segment in segments) {
      if (segment == '.' ||
          segment == '..' ||
          !_idPattern.hasMatch(segment)) {
        return null;
      }
    }

    final path = '/${segments.join('/')}';
    final query = uri.query;
    final location = query.isEmpty ? path : '$path?$query';
    return DeepLinkResolution(
      location: location,
      requiresAuth: _authPrefixes.contains(segments.first),
    );
  }

  /// Produces the path segments of the in-app location, folding a custom-scheme
  /// authority (host) into the path. Returns `null` for an unsupported scheme.
  ///
  ///   * `jeeb://orders/d-1`        → ['orders', 'd-1']   (host folded in)
  ///   * `jeeb://wallet`            → ['wallet']
  ///   * `https://jeeb.app/orders/d-1` → ['orders', 'd-1'] (domain dropped)
  List<String>? _foldedSegments(Uri uri) {
    final pathSegments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList(growable: true);
    if (uri.scheme == scheme) {
      // Custom scheme: the first route segment is parsed as the authority.
      final host = uri.host;
      return <String>[if (host.isNotEmpty) host, ...pathSegments];
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      // Universal/App link: the host is the domain, not a route segment.
      return pathSegments;
    }
    return null;
  }
}
