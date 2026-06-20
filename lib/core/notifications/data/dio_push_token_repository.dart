import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../network/auth_token_store.dart';
import '../domain/push_token_repository.dart';

/// Dio-backed [PushTokenRepository] (notif-push-token-registration).
///
/// Speaks the gateway contract; `MockGatewayClient` rewrites `/v1/devices` →
/// `/push-notification/v1/devices`. The `userId` is resolved best-effort from
/// the session [AuthTokenStore] so the gateway can associate the device with
/// the signed-in user; the gateway may also derive it from the bearer.
class DioPushTokenRepository implements PushTokenRepository {
  DioPushTokenRepository(this._dio, {AuthTokenStore? tokenStore})
      : _tokenStore = tokenStore ?? AuthTokenStore();

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  @override
  Future<void> register(String token) async {
    if (token.isEmpty) return;
    String? userId;
    try {
      userId = await _tokenStore.userId;
    } catch (_) {
      userId = null;
    }
    await _dio.post<void>(
      '/v1/devices',
      data: <String, dynamic>{
        'token': token,
        'platform': _platform,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );
  }

  /// Platform tag for the device row. Guarded so a non-mobile target (the
  /// `flutter test` VM, web) doesn't throw reading `Platform`.
  String get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {
      // Platform unavailable (test VM) — fall through.
    }
    return 'unknown';
  }
}
