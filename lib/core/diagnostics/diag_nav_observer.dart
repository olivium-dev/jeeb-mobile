import 'package:flutter/widgets.dart';

import 'diag.dart';
import 'diag_redaction.dart';

class DiagNavObserver extends NavigatorObserver {
  DiagNavObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _emit('push', route, from: previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _emit('pop', previousRoute ?? route, from: route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _emit('replace', newRoute, from: oldRoute);
  }

  void _emit(String evt, Route<dynamic>? route, {Route<dynamic>? from}) {
    if (!Diag.enabled || route == null) return;
    final settings = route.settings;
    final routePattern = _routePattern(settings);
    Diag.currentScreen = routePattern ?? Diag.currentScreen;
    Diag.nav(
      evt: evt,
      route: routePattern,
      name: _routeName(settings),
      params: _pathParams(settings),
      prev: from == null ? null : _routePattern(from.settings),
    );
  }

  static String? _routePattern(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    return DiagRedaction.scrubPath(name);
  }

  static String? _routeName(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    return DiagRedaction.scrubPath(name);
  }

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
