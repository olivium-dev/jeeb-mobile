import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../diagnostics/diag.dart';
import '../../observability/session_trace/session_trace.dart';
import '../../role/user_role.dart';
import '../data/push_transport.dart';
import '../domain/notification_deep_link.dart';
import '../domain/notification_message.dart';
import 'push_notification_handler.dart';

/// Bridges [PushNotificationHandler.opens] (and the transport's cold
/// [PushTransport.initialMessage]) to the app's [GoRouter].
///
/// Kept separate from the cubit so the cubit stays UI-agnostic and
/// pure-Dart-testable — the dispatcher is the only place that knows
/// `go_router` exists.
class NotificationDispatcher {
  NotificationDispatcher({
    required PushNotificationHandler handler,
    required GoRouter router,
    Future<NotificationMessage?>? initialMessage,
    UserRole Function()? roleResolver,
  })  : _handler = handler,
        _router = router,
        _roleResolver = roleResolver {
    _sub = handler.opens.listen(_route);
    // Cold-start: if the user tapped a notification while the app was
    // terminated, the transport buffers it as the initial message.
    final initial = initialMessage;
    if (initial != null) {
      _initialFuture = initial.then((msg) {
        if (msg != null) _route(msg);
      });
    }
    unawaited(_handler.bootstrap());
  }

  final PushNotificationHandler _handler;
  final GoRouter _router;

  /// F5: resolves the RECIPIENT's LIVE role at tap time. A **function**, not a
  /// value: the role can flip at runtime (`RoleCubit.toggle()`) while the
  /// dispatcher is constructed once at boot. `null` (unit callers, tests with
  /// no role context) keeps the legacy role-blind resolution.
  final UserRole Function()? _roleResolver;
  StreamSubscription<NotificationMessage>? _sub;
  Future<void>? _initialFuture;

  /// Exposed so test setups can await the cold-start route hop before
  /// asserting on the router's current location.
  Future<void> get whenColdRouted async {
    if (_initialFuture == null) return;
    await _initialFuture;
  }

  void _route(NotificationMessage message) {
    final role = _roleResolver?.call();
    final path = deepLinkForMessage(message, role: role);
    Diag.event('push_tapped', <String, Object?>{
      'id': message.id,
      'category': message.category.name,
      'deepLink': path,
      'resolved': path != null,
      // F5: proves on-device which role the guard actually saw.
      'role': role?.name,
    });
    // Session-trace observability tool (devtool-only, Module 3): richer,
    // redacted OPENED event alongside the `[jeeb-diag]` line above. Emitted
    // even when `path` is null (the tap itself is still an observed signal;
    // it just records no destination). Hard no-op (tree-shaken out) in a
    // production build.
    if (kObsCompiledIn) {
      ObsNotificationRecorder.recordOpened(message, deepLink: path);
    }
    if (path == null) return;
    _router.go(path);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
