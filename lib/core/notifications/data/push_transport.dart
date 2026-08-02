import 'dart:async';

import '../domain/notification_message.dart';

enum PushPermissionStatus { granted, denied, notDetermined }

abstract class PushTransport {
  Stream<NotificationMessage> get onForegroundMessage;

  Stream<NotificationMessage> get onMessageOpenedApp;

  Future<NotificationMessage?> initialMessage();

  Future<PushPermissionStatus> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<void> dispose();
}

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
