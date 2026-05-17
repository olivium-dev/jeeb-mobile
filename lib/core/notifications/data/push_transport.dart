import 'dart:async';

import '../domain/notification_message.dart';

/// Outcome of [PushTransport.requestPermission]. Mirrors the three
/// reasonable states across iOS authorisationStatus and Android 13+
/// POST_NOTIFICATIONS so the cubit doesn't need to know which platform
/// it's on.
enum PushPermissionStatus { granted, denied, notDetermined }

/// Abstraction over the platform push channel.
///
/// Production binds [FirebaseMessagingTransport]; tests inject
/// [FakePushTransport] so they can drive the cubit deterministically
/// without depending on the FCM platform channel. Keeping this interface
/// here is what lets every unit test in `test/push_*.dart` run on the
/// pure-Dart VM.
abstract class PushTransport {
  /// Foreground messages — fires while the app is in the foreground.
  /// The transport is responsible for parsing the platform payload
  /// before emitting on this stream.
  Stream<NotificationMessage> get onForegroundMessage;

  /// User tapped a system notification while the app was backgrounded
  /// (or terminated and re-launched via the tap). The dispatcher
  /// subscribes to both this and [initialMessage].
  Stream<NotificationMessage> get onMessageOpenedApp;

  /// Message that woke the app from a fully-terminated state. Resolves
  /// with `null` on a cold start that wasn't triggered by a tap. Must
  /// be consumed exactly once — the dispatcher calls this during init.
  Future<NotificationMessage?> initialMessage();

  /// Request user permission to display notifications. Idempotent — on
  /// iOS this surfaces the system prompt the first time and returns the
  /// cached status afterwards; on Android <13 it always returns
  /// [PushPermissionStatus.granted].
  Future<PushPermissionStatus> requestPermission();

  /// Current registration token (FCM token / APNs forwarder). May be
  /// `null` before APNs has finished registering on iOS. The handler
  /// uses this to register the device with jeeb-gateway so server-side
  /// notifications can target this install.
  Future<String?> getToken();

  /// Token refresh stream. Tokens rotate on app reinstall, restore from
  /// backup, etc.; we re-register with jeeb-gateway each time.
  Stream<String> get onTokenRefresh;

  /// Best-effort cleanup of any platform-channel subscriptions. Safe to
  /// call multiple times.
  Future<void> dispose();
}

/// In-memory transport used by widget + unit tests, and as the production
/// fallback before the native bridge lands. Pushes onto the foreground
/// stream via [emitForeground]; opened-app taps via [emitOpenedApp].
class FakePushTransport implements PushTransport {
  FakePushTransport({
    NotificationMessage? cold,
    String? token,
    PushPermissionStatus permission = PushPermissionStatus.granted,
  })  : _cold = cold,
        _token = token,
        _permission = permission;

  final _foreground = StreamController<NotificationMessage>.broadcast();
  final _opened = StreamController<NotificationMessage>.broadcast();
  final _tokenRefresh = StreamController<String>.broadcast();
  NotificationMessage? _cold;
  String? _token;
  PushPermissionStatus _permission;
  bool _disposed = false;

  @override
  Stream<NotificationMessage> get onForegroundMessage => _foreground.stream;

  @override
  Stream<NotificationMessage> get onMessageOpenedApp => _opened.stream;

  @override
  Future<NotificationMessage?> initialMessage() async {
    final cold = _cold;
    _cold = null;
    return cold;
  }

  @override
  Future<PushPermissionStatus> requestPermission() async => _permission;

  @override
  Future<String?> getToken() async => _token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  void emitForeground(NotificationMessage message) {
    if (_disposed) return;
    _foreground.add(message);
  }

  void emitOpenedApp(NotificationMessage message) {
    if (_disposed) return;
    _opened.add(message);
  }

  void emitTokenRefresh(String token) {
    if (_disposed) return;
    _token = token;
    _tokenRefresh.add(token);
  }

  void setPermission(PushPermissionStatus status) => _permission = status;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _foreground.close();
    await _opened.close();
    await _tokenRefresh.close();
  }
}
