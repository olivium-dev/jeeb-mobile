import 'package:flutter/widgets.dart';

import 'deep_link_resolver.dart';

/// Wraps go_router's [RouteInformationParser] so inbound PLATFORM deep links
/// (Android App-Link / iOS Universal-Link / custom-scheme intents) are
/// normalised by [DeepLinkResolver] BEFORE go_router matches them.
///
/// Why a parser wrapper (and not a redirect): go_router matches on `uri.path`,
/// and for a custom-scheme link the route's first segment is stranded in the
/// URI authority (`jeeb://orders/d-1` → host `orders`, path `/d-1`). By the
/// time the redirect runs the host is already lost, so the fold must happen at
/// the parse boundary — exactly where Flutter hands the raw platform URI to the
/// Router. In-app `context.go(...)` navigations already use rooted `/...` paths
/// (scheme-less) and pass straight through untouched.
///
/// Generic over [T] so it transparently wraps go_router's
/// `RouteInformationParser<RouteMatchList>` without naming the internal type.
class DeepLinkRouteInformationParser<T> extends RouteInformationParser<T> {
  DeepLinkRouteInformationParser({
    required this.inner,
    this.resolver = const DeepLinkResolver(),
  });

  /// go_router's own parser; all matching/serialization is delegated to it.
  final RouteInformationParser<T> inner;

  /// The pure host→path folding + id-validation plumbing.
  final DeepLinkResolver resolver;

  @override
  Future<T> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    return inner.parseRouteInformationWithDependencies(
      rewrite(routeInformation),
      context,
    );
  }

  @override
  Future<T> parseRouteInformation(RouteInformation routeInformation) {
    return inner.parseRouteInformation(rewrite(routeInformation));
  }

  @override
  RouteInformation? restoreRouteInformation(T configuration) =>
      inner.restoreRouteInformation(configuration);

  /// Rewrites a custom-scheme platform link to its go_router location. Anything
  /// that is not a `jeeb://` link, or that the resolver rejects (malformed id /
  /// traversal / unknown shape), is passed through unchanged so go_router's own
  /// error/redirect handling applies.
  @visibleForTesting
  RouteInformation rewrite(RouteInformation routeInformation) {
    final uri = routeInformation.uri;
    if (uri.scheme != DeepLinkResolver.scheme) return routeInformation;
    final location = resolver.resolveLocation(uri);
    if (location == null) return routeInformation;
    return RouteInformation(
      uri: Uri.parse(location),
      state: routeInformation.state,
    );
  }
}
