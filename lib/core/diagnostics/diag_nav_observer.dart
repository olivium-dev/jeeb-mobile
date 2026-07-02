import 'package:flutter/widgets.dart';

import 'diag.dart';
import 'diag_redaction.dart';

/// [NavigatorObserver] that emits one `[jeeb-diag] {"t":"nav",...}` line per
/// navigation transition. Registered on the app [GoRouter] via its `observers:`
/// list (see `AppRouter.create`), so it sees every push/pop/replace including
/// deep-link driven and redirect-driven transitions.
///
/// It records the ROUTE PATH PATTERN (`/orders/:id`, not `/orders/d-42`) when
/// go_router exposes it, the route name, and the path params. Query parameters
/// are intentionally dropped — they can carry tokens (`?resetToken=…`) and the
/// diagnostic stream never logs those.
class DiagNavObserver extends NavigatorObserver {
  DiagNavObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _emit('push', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // On a pop the destination the user lands ON is `previousRoute`; that is
    // the more useful "where am I now" signal, falling back to the popped route.
    _emit('pop', previousRoute ?? route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _emit('replace', newRoute);
  }

  void _emit(String evt, Route<dynamic>? route) {
    if (!Diag.enabled || route == null) return;
    final settings = route.settings;
    Diag.nav(
      evt: evt,
      route: _routePattern(settings),
      name: _routeName(settings),
      params: _pathParams(settings),
    );
  }

  /// The route PATH PATTERN. go_router stashes its `RouteMatchList`-derived
  /// info on `settings.name` for named routes; when the name is a raw location
  /// (`/orders/d-42?x=1`) we strip the query so only the path is logged.
  static String? _routePattern(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    return DiagRedaction.scrubPath(name);
  }

  /// The route NAME. For a go_router named route this is the route's `name`
  /// (`delivery-detail`); for an unnamed/raw-location route it is the location.
  /// Either way the query string is stripped — it can carry tokens
  /// (`?resetToken=…`) and the diagnostic stream never logs those.
  static String? _routeName(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    return DiagRedaction.scrubPath(name);
  }

  /// Extracts go_router path params when they were passed via `settings.arguments`
  /// as a `Map`. Non-map arguments (typed `extra` payloads) are omitted rather
  /// than serialized — an arbitrary `extra` object may carry PII.
  static Map<String, Object?> _pathParams(RouteSettings settings) {
    final args = settings.arguments;
    if (args is Map<String, Object?>) {
      return DiagRedaction.scrubMap(args);
    }
    if (args is Map) {
      return DiagRedaction.scrubMap(
        args.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const <String, Object?>{};
  }
}
