import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../diagnostics/diag_dio_interceptor.dart';
import '../observability/session_trace/capture/obs_dio_interceptor.dart';
import 'auth_token_store.dart';
import 'rate_limit_interceptor.dart';
import 'redacting_log_interceptor.dart';
import 'unversioned_path_fallback_interceptor.dart';

class MockGatewayClient {
  MockGatewayClient._();

  static String get mockBaseUrl {
    final developmentBuild = kDebugMode || AppConfig.isDevelopmentFlavor;
    final fallback = developmentBuild
        ? _devGatewayBaseUrl
        : AppConfig.gatewayBaseUrl;
    final configured = _baseUrlDefine.isNotEmpty ? _baseUrlDefine : fallback;
    final uri = Uri.tryParse(configured);
    if (!_isAllowedGatewayUri(uri, allowCleartext: developmentBuild)) {
      throw StateError('Gateway URL violates the build transport policy.');
    }
    return configured;
  }

  static const String _baseUrlDefine = String.fromEnvironment(
    'JEEB_MOCK_BASE_URL',
  );

  static const String _devGatewayBaseUrl = String.fromEnvironment(
    'JEEB_DEV_GATEWAY_BASE_URL',
    defaultValue: 'https://gateway.dev.invalid',
  );

  static bool _isAllowedGatewayUri(Uri? uri, {required bool allowCleartext}) {
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.scheme == 'https') return true;
    return allowCleartext && uri.scheme == 'http';
  }

  static const bool useMockPrefixes = bool.fromEnvironment(
    'JEEB_USE_MOCK_PREFIXES',
    defaultValue: false,
  );

  static const Map<String, String> _pathToServicePrefix = {
    '/v1/auth/otp': '/auth-service/auth/otp',
    '/v1/auth/login': '/auth-service/auth/login',
    '/v1/auth/signup': '/auth-service/auth/signup',
    '/v1/auth/social': '/auth-service/auth/social',
    '/v1/auth/recovery': '/auth-service/auth/recovery',
    '/v1/auth/set-password': '/auth-service/auth/set-password',
    '/v1/auth/refresh': '/auth-service/auth/refresh',
    '/v1/auth/logout': '/auth-service/auth/logout',
    '/api/auth/social': '/auth-service/auth/social',
    '/auth/otp': '/auth-service/auth/otp',
    '/auth/social': '/auth-service/auth/social',
    '/auth/refresh': '/auth-service/auth/refresh',
    '/v1/users': '/user-management/users',
    '/users': '/user-management/users',
    '/v1/kyc': '/user-management/v1/kyc',
    '/v1/chat/jeeb': '/chat-service/v1/chat/jeeb',
    '/v1/conversations': '/chat-service/v1/conversations',
    '/v1/realtime': '/realtime-comunication-service/v1/realtime',
    '/v1/offers': '/offer-service/v1/offers',
    '/v1/delivery': '/delivery-service/v1/delivery',
    '/v1/tiers': '/delivery-service/v1/tiers',
    '/v1/requests': '/delivery-service/v1/requests',
    '/api/requests': '/delivery-service/api/requests',
    '/v1/matching': '/matching/v1/matching',
    '/v1/availability': '/geolocation-service/v1/availability',
    '/v1/notifications/send': '/notification-service/v1/notifications/send',
    '/v1/notifications': '/notification-service/v1/notifications',
    '/v1/ratings/jeeb': '/score-taking-service/v1/ratings/jeeb',
    '/v1/feedback/jeeb': '/feedback-service/v1/feedback/jeeb',
    '/v1/templates': '/form-builder-service/v1/templates',
    '/v1/contracts': '/contract-signing-service/v1/templates',
    '/v1/moderation/jeeb': '/ban-service/v1/moderation/jeeb',
    '/v1/disputes': '/compliment-service/v1/disputes',
    '/v1/support': '/support-service/v1/support',
    '/v1/jeeb/wallet': '/wallet-service/v1/jeeb/wallet',
    '/v1/jeeb/earnings': '/wallet-service/v1/jeeb/earnings',
    '/api/deliveries': '/delivery-service/api/deliveries',
    '/v1/deliveries': '/delivery-service/v1/deliveries',
    '/v1/transcribe': '/voice-transcription-service/v1/transcribe',
    '/v1/devices': '/push-notification/v1/devices',
    '/channels/jeeb-chat': '/realtime-comunication-service/channels/jeeb-chat',
  };

  static String rewritePath(String path) {
    if (!useMockPrefixes) return path;
    return mapToServicePrefix(path);
  }

  static String mapToServicePrefix(String path) {
    for (final entry in _pathToServicePrefix.entries) {
      if (path.startsWith(entry.key)) {
        return path.replaceFirst(entry.key, entry.value);
      }
    }
    return path;
  }

  static String savedLocationsPath({required String userId}) => useMockPrefixes
      ? '/users/$userId/saved-locations'
      : '/api/users/me/saved-locations';

  static Dio createDio({
    String? baseUrl,
    void Function()? onRateLimitWindowClosed,
  }) {
    final effectiveBaseUrl = baseUrl ?? mockBaseUrl;

    final dio = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      RateLimitInterceptor(onBackoffWindowClosed: onRateLimitWindowClosed),
    );

    if (useMockPrefixes) {
      dio.interceptors.add(_PathRewriteInterceptor());
    }

    dio.interceptors.add(_AuthInterceptor());

    dio.interceptors.add(const DiagDioInterceptor());

    // Observe the original wire result before compatibility recovery handles
    // it. The replay then traverses this interceptor again and gets its own
    // capture, so `/v1/...` 404 + unversioned 200 remain distinct attempts.
    ObsDioInterceptor.attachTo(dio);

    // W6-02 compat window: a 404/405 on `/v1/...` is retried unversioned.
    dio.interceptors.add(UnversionedPathFallbackInterceptor(dio));

    if (kDebugMode) {
      dio.interceptors.add(const RedactingLogInterceptor());
    }

    return dio;
  }

  static const String realtimeBaseUrl = String.fromEnvironment(
    'JEEB_REALTIME_BASE_URL',
    defaultValue: '',
  );

  static const int realtimePort = 5804;

  static Uri get realtimeHttpBase =>
      resolveRealtimeHttpBase(mockMode: useMockPrefixes);

  static Uri resolveRealtimeHttpBase({required bool mockMode}) {
    if (realtimeBaseUrl.isNotEmpty) return Uri.parse(realtimeBaseUrl);
    final base = Uri.parse(mockBaseUrl);
    if (mockMode) return base;
    return base.replace(port: realtimePort);
  }

  static String get webSocketPath =>
      resolveWebSocketPath(mockMode: useMockPrefixes);

  static String resolveWebSocketPath({required bool mockMode}) => mockMode
      ? '/realtime-comunication-service/socket/websocket'
      : '/socket/websocket';

  static String get webSocketUrl =>
      resolveWebSocketUrl(mockMode: useMockPrefixes);

  static String resolveWebSocketUrl({required bool mockMode}) {
    final base = resolveRealtimeHttpBase(mockMode: mockMode);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${base.host}:${base.port}'
        '${resolveWebSocketPath(mockMode: mockMode)}';
  }
}

class _PathRewriteInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.path = MockGatewayClient.rewritePath(options.path);
    handler.next(options);
  }
}

class _AuthInterceptor extends Interceptor {
  String? _token;

  void setToken(String token) => _token = token;

  final AuthTokenStore _tokenStore = AuthTokenStore();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.headers.containsKey('Authorization')) {
      final token = _token ?? await _readStoreToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<String?> _readStoreToken() async {
    try {
      return await _tokenStore.accessToken;
    } catch (_) {
      return null;
    }
  }
}
