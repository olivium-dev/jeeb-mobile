import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../diagnostics/diag.dart';
import '../../observability/session_trace/session_trace.dart';
import '../../role/user_role.dart';
import '../domain/notification_deep_link.dart';
import '../domain/notification_message.dart';
import 'push_notification_handler.dart';

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

  final UserRole Function()? _roleResolver;
  StreamSubscription<NotificationMessage>? _sub;
  Future<void>? _initialFuture;

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
      'role': role?.name,
    });
    // Session-trace observability tool (devtool-only, Module 3): richer,
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
