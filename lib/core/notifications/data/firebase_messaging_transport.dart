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

/// Background isolate entry-point.
///
/// Annotated `@pragma('vm:entry-point')` so the AOT tree-shaker keeps it
/// when the engine looks it up by name in the background isolate. Must
/// be a top-level function — the FCM plugin reflects on it directly and
/// will throw if it's an instance method or anonymous closure.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate is short-lived and has no UI. Android's
  // NotificationManager still renders/collapses the tray banner via the FCM
  // SDK, but this isolate CANNOT touch the main-isolate BadgeCountCubit or the
  // inbox list — so a `new_request` dismissed here used to leave NO trail
  // (empty inbox, no badge: run-24 CHECK D / G3). Persist it durably so the
  // main isolate can surface it on resume.
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

/// Writes a durable [LocalPushInbox] row for a `new_request` push (G3), from
/// EITHER isolate. No-op for any other push type — chat/offer/etc. are sourced
/// by the server inbox, so persisting them locally would double the row.
///
/// Reuses [hoistNestedRoutingFields] + [NotificationCategory.fromData] so the
/// same category resolution the foreground path uses decides "is this a
/// new_request" — the wire contract lives in one place. Fail-soft: a storage
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
    Set<String> Function()? openChatThreadIds,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _openChatThreadIds =
            openChatThreadIds ?? (() => ActiveChatThread.instance.openIds);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// The chat thread currently ON SCREEN, read at push time (never cached — the
  /// user can walk in and out of a conversation between two pushes). Injectable
  /// so a unit test can drive the suppression without a navigator.
  final Set<String> Function() _openChatThreadIds;

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

  /// Test seam for the `onMessage` listener registered in [initialize].
  ///
  /// [initialize] cannot run on the test VM (it touches three platform
  /// channels), which is exactly how this listener stayed unexamined while it
  /// called `show()` unconditionally. Exposing the handler lets the suppression
  /// be proven on the VM; the Android `show()` branch itself is still
  /// `Platform.isAndroid`-gated and therefore device-only.
  @visibleForTesting
  void debugHandleForeground(RemoteMessage message) =>
      _handleForeground(message);

  /// Test seam: ids of the messages that reached the render path (a suppressed
  /// push never lands here, so an empty set is positive evidence of the early
  /// return — and a non-empty one is the negative control).
  @visibleForTesting
  Set<String> get debugForegroundShownIds => _foregroundShown.keys.toSet();

  void _handleForeground(RemoteMessage message) {
    final domain = _toDomain(message);
    // ALWAYS published, including for a suppressed push: this stream is what
    // drives `PushNotificationHandler._maybeSignalStatusChange`, i.e. the
    // refresh that is the entire point of a silent push. Dropping it here
    // would turn the polling→push cutover into a cutover to nothing.
    _foreground.add(domain);
    if (!_shouldShow(domain)) return;
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
      // Session-trace observability tool (devtool-only, Module 3): richer,
      // redacted SHOWN event for the exact moment the Android heads-up
      // banner is actually rendered (FCM does not auto-display foreground
      // messages). Hard no-op (tree-shaken out) in a production build.
      if (kObsCompiledIn) {
        ObsNotificationRecorder.recordShown(domain);
      }
    }
  }

  /// Whether this foreground push may interrupt the user with a heads-up.
  ///
  /// The decision itself is a pure function ([shouldShowForegroundPush]); this
  /// wrapper only supplies the on-screen-thread set and emits the diagnostic
  /// line, so a device run can distinguish "the push never arrived" from "the
  /// push arrived and was deliberately silenced" — two indistinguishable
  /// symptoms that have burned this batch repeatedly.
  ///
  /// ## PLATFORM SCOPE — the open-thread half is ANDROID-ONLY
  ///
  /// Only the Android branch below renders a foreground heads-up from Dart, and
  /// only what Dart renders can be gated here. On iOS, [initialize] calls
  /// `setForegroundNotificationPresentationOptions(alert: true, …)` (:154),
  /// which hands foreground presentation to the OS: the banner is drawn from
  /// the APNs `notification` block before any Dart runs, so this guard has no
  /// interception point and CANNOT suppress it.
  ///
  /// * SILENT works on iOS anyway, by construction rather than by this code:
  ///   the service omits the `notification` block entirely for a silent push,
  ///   so there is nothing for iOS to present.
  /// * OPEN CHAT THREAD does NOT work on iOS. A chat push for the conversation
  ///   already on screen will still alert there. Making it work means routing
  ///   iOS foreground display through `flutter_local_notifications` too, which
  ///   would put every iOS visible push at risk for a case this fleet has no
  ///   iOS hardware to test. Deliberately not done; recorded so nobody reads
  ///   the unit tests (which run on the VM, where `Platform.isAndroid` is
  ///   false) as cross-platform proof.
  ///
  /// ## Divergence from the `fg ≡ bg` contract, stated explicitly
  ///
  /// `push_render_mapping.dart:7-13` declares foreground ≡ background. That
  /// contract is about WHAT is rendered (title/body/dedup tag/deep link) and is
  /// untouched — `PushRenderFields` is not modified and the two paths still map
  /// identically. What now differs is WHETHER anything renders at all, and only
  /// in the foreground:
  ///
  /// * silent: the service sends `notification=None`, so the background path
  ///   already renders nothing. Suppressing here makes fg MATCH bg rather than
  ///   diverge from it — today's unconditional `show()` is the divergence.
  /// * open chat thread: fg suppresses, bg does not. This cannot be reconciled
  ///   and is not a defect: "the thread is on screen" is only ever true in the
  ///   foreground, and the background isolate could not honour it anyway (FCM
  ///   renders the tray entry before Dart runs — same constraint recorded in
  ///   `push_audience.dart:11-13`).
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
  // DELIBERATELY NOT [kSilentPushKey]. An earlier revision of this branch added
  // it "in case the gateway nests it". Nothing has been observed nesting
  // `silent`: the push microservice emits it flat
  // (`push-notification/app/endpoints/sent_payload.py` ships
  // `data = {k: str(v) for k, v in payload.items()}`), and the gateway does not
  // send it at all yet. Every other key on this list was added against a
  // captured payload that really did bury it. Speculating a wire shape here
  // costs a regex match per push against a blob that may legitimately contain
  // the substring, and the failure it would prevent is the recoverable
  // direction anyway (an unhoisted `silent` reads as "not silent" ⇒ the push
  // SHOWS). Whichever lane makes the gateway stamp `silent` should add the key
  // here with a captured payload as evidence.
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
