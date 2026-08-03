import 'package:flutter/widgets.dart';

import 'deep_link_resolver.dart';

class DeepLinkRouteInformationParser<T> extends RouteInformationParser<T> {
  DeepLinkRouteInformationParser({
    required this.inner,
    this.resolver = const DeepLinkResolver(),
  });

  final RouteInformationParser<T> inner;

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
