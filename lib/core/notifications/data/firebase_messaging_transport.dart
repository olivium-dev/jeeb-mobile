import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diagnostics/diag.dart';
import '../../observability/session_trace/session_trace.dart';
import '../domain/active_chat_thread.dart';
import '../domain/foreground_push_display.dart';
import '../domain/local_push_inbox.dart';
import '../domain/notification_message.dart';
import 'shared_prefs_local_push_inbox.dart';
import 'push_transport.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Diag.event('push_received', <String, Object?>{
    'mode': 'background',
    'id': message.messageId,
    'type': message.data['type'],
    'category': message.data['category'],
  });
  await persistNewRequestPush(message);
  if (kDebugMode) {
    debugPrint('[push] background message: ${message.messageId}');
  }
}

/// error must never crash the background isolate (it would drop the OS ack).
Future<void> persistNewRequestPush(RemoteMessage message) async {
  try {
    final data = message.data.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    hoistNestedRoutingFields(data);
    if (NotificationCategory.fromData(data) != NotificationCategory.newRequest) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final inbox = SharedPrefsLocalPushInbox(prefs: prefs);
    await inbox.append(LocalPushRecord(
      id: message.messageId ??
          'fcm-${DateTime.now().microsecondsSinceEpoch}',
      type: kNewRequestPushType,
      title: message.notification?.title ?? data['title'] ?? '',
      body: message.notification?.body ?? data['body'] ?? '',
      ts: (message.sentTime ?? DateTime.now()).toUtc().toIso8601String(),
      ref: data['requestId'] ?? data['request_id'],
    ));
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[push] persistNewRequestPush failed: $error');
    }
  }
}

const AndroidNotificationChannel jeebDefaultChannel = AndroidNotificationChannel(
  'jeeb_default',
  'Jeeb Notifications',
  description: 'Delivery updates, chat, KYC, ratings, and account alerts.',
  importance: Importance.high,
);

class FirebaseMessagingTransport implements PushTransport {
  FirebaseMessagingTransport({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    Set<String> Function()? openChatThreadIds,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _openChatThreadIds =
            openChatThreadIds ?? (() => ActiveChatThread.instance.openIds);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final Set<String> Function() _openChatThreadIds;

  final _foreground = StreamController<NotificationMessage>.broadcast();
  final _opened = StreamController<NotificationMessage>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  bool _initialized = false;

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

  final Map<String, NotificationMessage> _foregroundShown = {};

  void _onLocalNotificationTap(NotificationResponse response) {
    final id = response.payload;
    if (id == null) return;
    final message = _foregroundShown.remove(id);
    if (message != null) _opened.add(message);
  }

  @visibleForTesting
  void debugHandleForeground(RemoteMessage message) =>
      _handleForeground(message);

  @visibleForTesting
  Set<String> get debugForegroundShownIds => _foregroundShown.keys.toSet();

  void _handleForeground(RemoteMessage message) {
    final domain = _toDomain(message);
    _foreground.add(domain);
    if (!_shouldShow(domain)) return;
    _foregroundShown[domain.id] = domain;
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
      // Session-trace observability tool (devtool-only, Module 3): richer,
      if (kObsCompiledIn) {
        ObsNotificationRecorder.recordShown(domain);
      }
    }
  }

  ///   renders the tray entry before Dart runs — same constraint recorded in
  bool _shouldShow(NotificationMessage domain) {
    final show = shouldShowForegroundPush(
      category: domain.category,
      data: domain.data,
      openChatThreadIds: _openChatThreadIds(),
    );
    if (!show) {
      Diag.event('push_headsup_suppressed', <String, Object?>{
        'id': domain.id,
        'category': domain.category.name,
        'reason': isSilentPush(domain.data) ? 'silent' : 'chat_thread_open',
      });
    }
    return show;
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
    hoistNestedRoutingFields(data);
    if (kDebugMode) {
      debugPrint('[push] rx keys=${data.keys.toList()} '
          'hasNotif=${message.notification != null} '
          'cat=${NotificationCategory.fromData(data).name}');
    }
    return NotificationMessage(
      id: message.messageId ??
          'fcm-${DateTime.now().microsecondsSinceEpoch}',
      category: NotificationCategory.fromData(data),
      title: message.notification?.title ?? data['title'] ?? '',
      body: message.notification?.body ?? data['body'] ?? '',
      receivedAt: message.sentTime ?? DateTime.now(),
      data: data,
    );
  }
}

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
