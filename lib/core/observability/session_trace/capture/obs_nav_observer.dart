import 'package:flutter/widgets.dart';

import '../../../diagnostics/diag_redaction.dart';
import '../observability.dart';
import '../secret_redactor.dart';

final class ObsNavObserver extends NavigatorObserver {
  ObsNavObserver();

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

  void _emit(String action, Route<dynamic>? route, {Route<dynamic>? from}) {
    if (!Observability.instance.recording || route == null) return;
    final settings = route.settings;
    final pattern = _routePattern(settings);
    Observability.instance.currentScreen =
        pattern ?? Observability.instance.currentScreen;
    Observability.instance.recordScreen(
      action: action,
      route: pattern,
      name: _routeName(settings),
      previousRoute: from == null ? null : _routePattern(from.settings),
      params: _redactedPathParams(settings),
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

  static Map<String, Object?> _redactedPathParams(RouteSettings settings) {
    final redacted = SecretRedactor.redactBody(
      _pathParams(settings),
      full: true,
    );
    return redacted is Map<String, Object?>
        ? redacted
        : const <String, Object?>{};
  }

  static Map<String, Object?> _pathParams(RouteSettings settings) {
    final args = settings.arguments;
    if (args is Map<String, Object?>) return args;
    if (args is Map) {
      return args.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, Object?>{};
  }
}
