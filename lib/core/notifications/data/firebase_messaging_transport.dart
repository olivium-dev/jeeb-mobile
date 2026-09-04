import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diagnostics/diag.dart';
import '../../observability/session_trace/session_trace.dart';
import '../../role/role_availability_cubit.dart';
import '../../role/role_cubit.dart';
import '../domain/active_chat_thread.dart';
import '../domain/foreground_push_display.dart';
import '../domain/local_push_inbox.dart';
import '../domain/notification_message.dart';
import '../domain/push_audience.dart';
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
    if (NotificationCategory.fromData(data) !=
        NotificationCategory.newRequest) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    // Same resolver as the foreground gate: an absent/empty snapshot is UNKNOWN
    // and fails OPEN (persist); the active role only ever widens a resolved one.
    final roles = sessionPushRoles(
      availableRoles:
          prefs.getStringList(RoleAvailabilityCubit.availableRolesPrefKey) ??
              const <String>[],
      activeRole: prefs.getString(RoleCubit.rolePrefKey) ?? '',
    );
    if (!isPushAudienceMatch(data, roles)) {
      Diag.event('push_inbox_suppressed', <String, Object?>{
        'id': message.messageId,
        'audience_role': data['audience_role'],
        'reason': 'audience_mismatch',
      });
      return;
    }
    final inbox = SharedPrefsLocalPushInbox(prefs: prefs);
    await inbox.append(
      LocalPushRecord(
        id: message.messageId ?? 'fcm-${DateTime.now().microsecondsSinceEpoch}',
        type: kNewRequestPushType,
        title: message.notification?.title ?? data['title'] ?? '',
        body: message.notification?.body ?? data['body'] ?? '',
        ts: (message.sentTime ?? DateTime.now()).toUtc().toIso8601String(),
        ref: data['requestId'] ?? data['request_id'],
      ),
    );
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[push] persistNewRequestPush failed: $error');
    }
  }
}

const AndroidNotificationChannel jeebDefaultChannel =
    AndroidNotificationChannel(
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
    Set<String> Function()? localRoles,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _openChatThreadIds =
           openChatThreadIds ?? (() => ActiveChatThread.instance.openIds),
       _localRoles = localRoles;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final Set<String> Function() _openChatThreadIds;

  /// null = no resolver: the heads-up audience gate is skipped (fail open).
  final Set<String> Function()? _localRoles;

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

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(jeebDefaultChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _opened.add(_toDomain(msg).withOpenSource(kPushOpenSourceFcm));
    });
  }

  final Map<String, NotificationMessage> _foregroundShown = {};

  @visibleForTesting
  void debugHandleLocalTap(NotificationResponse response) =>
      _onLocalNotificationTap(response);

  void _onLocalNotificationTap(NotificationResponse response) {
    final message = _fromLocalPayload(response.payload);
    if (message == null) return;
    _foregroundShown.remove(message.id);
    _opened.add(message.withOpenSource(kPushOpenSourceLocal));
  }

  /// notification survives process death, unlike the in-memory map (which is
  /// still read so payloads written by an older build keep routing).
  NotificationMessage? _fromLocalPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (!payload.startsWith('{')) return _foregroundShown[payload];
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final rawData = decoded['data'];
      final data = <String, String>{
        if (rawData is Map)
          for (final e in rawData.entries)
            e.key.toString(): e.value?.toString() ?? '',
      };
      final id = decoded['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      return NotificationMessage(
        id: id,
        category: NotificationCategory.fromData(data),
        title: decoded['title']?.toString() ?? '',
        body: decoded['body']?.toString() ?? '',
        receivedAt:
            DateTime.tryParse(decoded['ts']?.toString() ?? '') ??
            DateTime.now(),
        data: data,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[push] bad local payload: $error');
      return null;
    }
  }

  @visibleForTesting
  static String debugLocalPayload(NotificationMessage message) =>
      _toLocalPayload(message);

  static String _toLocalPayload(NotificationMessage message) =>
      jsonEncode(<String, Object?>{
        'id': message.id,
        'title': message.title,
        'body': message.body,
        'ts': message.receivedAt.toUtc().toIso8601String(),
        'data': message.data,
      });

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
        payload: _toLocalPayload(domain),
      );
      // Session-trace observability tool (devtool-only, Module 3): richer,
      if (kObsCompiledIn) {
        ObsNotificationRecorder.recordShown(domain);
      }
    }
  }

  ///   renders the tray entry before Dart runs — same constraint recorded in
  bool _shouldShow(NotificationMessage domain) {
    final roles = _localRoles?.call();
    final show = shouldShowForegroundPush(
      category: domain.category,
      data: domain.data,
      openChatThreadIds: _openChatThreadIds(),
      localRoles: roles,
    );
    if (!show) {
      Diag.event('push_headsup_suppressed', <String, Object?>{
        'id': domain.id,
        'category': domain.category.name,
        'reason': isSilentPush(domain.data)
            ? 'silent'
            : (roles != null && !isPushAudienceMatch(domain.data, roles))
            ? 'audience_mismatch'
            : 'chat_thread_open',
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
    if (msg != null) {
      return _toDomain(msg).withOpenSource(kPushOpenSourceLaunch);
    }
    // A cold start from an app-POSTED notification never reaches FCM's
    // getInitialMessage; flutter_local_notifications holds that launch intent.
    try {
      final details = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final local = _fromLocalPayload(
          details?.notificationResponse?.payload,
        );
        if (local != null) {
          return local.withOpenSource(kPushOpenSourceLaunch);
        }
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[push] launch details failed: $error');
    }
    return null;
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
      debugPrint(
        '[push] rx keys=${data.keys.toList()} '
        'hasNotif=${message.notification != null} '
        'cat=${NotificationCategory.fromData(data).name}',
      );
    }
    return NotificationMessage(
      id: message.messageId ?? 'fcm-${DateTime.now().microsecondsSinceEpoch}',
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
  'caseId',
  'case_id',
  'disputeId',
  'dispute_id',
  'ticketId',
  'ticket_id',
  'support_ticket_id',
  'offerId',
  'offer_id',
];

void hoistNestedRoutingFields(Map<String, String> data) {
  // `payload` is the notification-service lane's blob; `data` the gateway one.
  for (final blobKey in const <String>['data', 'payload']) {
    final blob = data[blobKey];
    if (blob == null || blob.isEmpty || !blob.contains(':')) continue;
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
}
