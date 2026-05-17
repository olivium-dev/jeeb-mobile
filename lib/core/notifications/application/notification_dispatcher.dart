import 'dart:async';

import 'package:go_router/go_router.dart';

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
  })  : _handler = handler,
        _router = router {
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
  StreamSubscription<NotificationMessage>? _sub;
  Future<void>? _initialFuture;

  /// Exposed so test setups can await the cold-start route hop before
  /// asserting on the router's current location.
  Future<void> get whenColdRouted async {
    if (_initialFuture == null) return;
    await _initialFuture;
  }

  void _route(NotificationMessage message) {
    final path = deepLinkForMessage(message);
    if (path == null) return;
    _router.go(path);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
