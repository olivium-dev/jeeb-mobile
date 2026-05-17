import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_message.dart';
import 'push_transport.dart';

/// Background isolate entry-point.
///
/// Annotated `@pragma('vm:entry-point')` so the AOT tree-shaker keeps it
/// when the engine looks it up by name in the background isolate. Must
/// be a top-level function — the FCM plugin reflects on it directly and
/// will throw if it's an instance method or anonymous closure.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate is short-lived and has no UI; the only
  // meaningful work is letting the OS know we handled the wakeup. The
  // actual display path is owned by Android's NotificationManager via
  // the FCM SDK when `notification` is present in the payload.
  if (kDebugMode) {
    debugPrint('[push] background message: ${message.messageId}');
  }
}

/// Android notification channel used for every Jeeb push. Single channel
/// today; if/when we add categories that users should mute independently
/// (e.g. marketing vs operational), split here and update the wire
/// `android_channel_id` on the gateway side in lockstep.
const AndroidNotificationChannel jeebDefaultChannel = AndroidNotificationChannel(
  'jeeb_default',
  'Jeeb Notifications',
  description: 'Delivery updates, chat, KYC, ratings, and account alerts.',
  importance: Importance.high,
);

/// Production [PushTransport] backed by `firebase_messaging` and
/// `flutter_local_notifications`.
///
/// Why both plugins:
/// - On Android, FCM does not render foreground notifications by
///   default — the system tray banner only shows when the app is
///   backgrounded. We use `flutter_local_notifications` to display a
///   heads-up notification for foreground messages so the user gets the
///   same UX regardless of foreground state.
/// - On iOS, we ask APNs to surface the alert in foreground via
///   [FirebaseMessaging.setForegroundNotificationPresentationOptions]
///   so the OS handles display; no local-notifications hop needed.
class FirebaseMessagingTransport implements PushTransport {
  FirebaseMessagingTransport({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final _foreground = StreamController<NotificationMessage>.broadcast();
  final _opened = StreamController<NotificationMessage>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  bool _initialized = false;

  /// One-shot init: registers the background handler, creates the
  /// Android channel, hooks the foreground listener. Idempotent — calling
  /// twice is a no-op so [Bootstrap.deferred] can call this without
  /// guarding against a race with hot reload.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final androidImpl = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(jeebDefaultChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _opened.add(_toDomain(msg));
    });
  }

  void _handleForeground(RemoteMessage message) {
    final domain = _toDomain(message);
    _foreground.add(domain);
    // On Android the OS won't render foreground messages — surface a
    // local notification ourselves so the user still sees a heads-up.
    // On iOS the OS handles display via setForegroundNotificationPresentationOptions.
    if (Platform.isAndroid) {
      _localNotifications.show(
        domain.id.hashCode,
        domain.title,
        domain.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            jeebDefaultChannel.id,
            jeebDefaultChannel.name,
            channelDescription: jeebDefaultChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: domain.id,
      );
    }
  }

  @override
  Stream<NotificationMessage> get onForegroundMessage => _foreground.stream;

  @override
  Stream<NotificationMessage> get onMessageOpenedApp => _opened.stream;

  @override
  Future<NotificationMessage?> initialMessage() async {
    final msg = await _messaging.getInitialMessage();
    return msg == null ? null : _toDomain(msg);
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return PushPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermissionStatus.notDetermined;
    }
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _foreground.close();
    await _opened.close();
  }

  NotificationMessage _toDomain(RemoteMessage message) {
    final data = message.data.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    return NotificationMessage(
      id: message.messageId ??
          'fcm-${DateTime.now().microsecondsSinceEpoch}',
      category: NotificationCategory.fromKey(data['category']),
      title: message.notification?.title ?? data['title'] ?? '',
      body: message.notification?.body ?? data['body'] ?? '',
      receivedAt: message.sentTime ?? DateTime.now(),
      data: data,
    );
  }
}
