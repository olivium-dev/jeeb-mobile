import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../diagnostics/diag.dart';
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
  Diag.event('push_received', <String, Object?>{
    'mode': 'background',
    'id': message.messageId,
    'type': message.data['type'],
    'category': message.data['category'],
  });
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
      // Foreground messages are shown via a LOCAL notification (FCM does not
      // auto-display them on Android). Route a tap on that local notification
      // through the same opened-app path so foreground-arrived chat pushes
      // navigate to the conversation just like background ones.
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
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

  /// Maps the local-notification id (`domain.id`) back to the domain message
  /// so a foreground-notification tap can be re-routed via [_opened].
  final Map<String, NotificationMessage> _foregroundShown = {};

  void _onLocalNotificationTap(NotificationResponse response) {
    final id = response.payload;
    if (id == null) return;
    final message = _foregroundShown.remove(id);
    if (message != null) _opened.add(message);
  }

  void _handleForeground(RemoteMessage message) {
    final domain = _toDomain(message);
    _foreground.add(domain);
    _foregroundShown[domain.id] = domain;
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
    // The live jeeb-gateway chat push nests routing fields inside a single
    // stringified `data` blob (single-quote pseudo-JSON). Hoist them to the top
    // level BEFORE category resolution so `category`/`type`/`conversationId`/
    // `requestId` are visible to [NotificationCategory.fromKey] and
    // [deepLinkForMessage]; without this a chat push buckets as `other` and
    // routes nowhere. No-op for a correct flat payload (no nested blob).
    hoistNestedRoutingFields(data);
    if (kDebugMode) {
      // Diagnostic: keys + flags only (no values) so we can see the live
      // payload shape (e.g. conversationId/type) without leaking content.
      debugPrint('[push] rx keys=${data.keys.toList()} '
          'hasNotif=${message.notification != null} '
          'cat=${NotificationCategory.fromData(data).name}');
    }
    return NotificationMessage(
      id: message.messageId ??
          'fcm-${DateTime.now().microsecondsSinceEpoch}',
      // jeeb-gateway's event notifiers use `type` as the real discriminator
      // (e.g. `type:"chat"`, `type:"new_request"`); NewRequestPushNotifier also
      // stamps a legacy `category:"delivery"` for pre-sprint-009 APKs. Resolve
      // via [NotificationCategory.fromData] so a KNOWN `type` wins over that
      // legacy `category` — otherwise a new_request tap mis-routes to the order
      // surface (run-19 push-D gap).
      category: NotificationCategory.fromData(data),
      title: message.notification?.title ?? data['title'] ?? '',
      body: message.notification?.body ?? data['body'] ?? '',
      receivedAt: message.sentTime ?? DateTime.now(),
      data: data,
    );
  }
}

/// Routing keys the gateway may bury inside the stringified `data` blob.
const List<String> kNestedRoutingKeys = <String>[
  'category',
  'type',
  'conversationId',
  'conversation_id',
  'chat_id',
  'requestId',
  'request_id',
  'delivery_id',
  'order_id',
];

/// Extracts [kNestedRoutingKeys] from a nested `data` field (single- OR
/// double-quote pseudo-JSON) and hoists them to the top level of [data].
///
/// The live jeeb-gateway chat push nests routing fields inside a single
/// stringified `data` entry — e.g.
/// `data: "{'conversationId':'…','requestId':'…','type':'chat'}"` — serialized
/// as a single-quote (Python-style) pseudo-JSON that is NOT valid JSON. Without
/// hoisting, `category`/`type`/`conversationId` are invisible to category
/// resolution and [deepLinkForMessage], so a chat push routes nowhere.
///
/// Existing flat keys win (this only fills gaps); no-op when there is no nested
/// blob, so a correct flat payload is unaffected. Tolerant regex extraction
/// avoids the single-vs-double-quote JSON pitfall.
void hoistNestedRoutingFields(Map<String, String> data) {
  final blob = data['data'];
  if (blob == null || blob.isEmpty || !blob.contains(':')) return;
  for (final key in kNestedRoutingKeys) {
    if ((data[key] ?? '').isNotEmpty) continue; // a real flat field wins
    final m = RegExp(
      '''["']?$key["']?\\s*:\\s*["']?([^,"'}\\s]+)["']?''',
    ).firstMatch(blob);
    final value = m?.group(1);
    if (value != null && value.isNotEmpty && value != 'null') {
      data[key] = value;
    }
  }
}
