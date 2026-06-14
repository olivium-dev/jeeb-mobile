import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Maps gateway-style paths to the mock backend's per-service prefix paths.
///
/// The Jeeb mobile app speaks only to `jeeb-gateway` (BFF). For local
/// development against the mock backend at `http://localhost:4010`, this
/// client rewrites every outbound request path from the gateway contract
/// (`/v1/chat/jeeb/...`, `/v1/offers/...`) to the mock's service-prefixed
/// routes (`/chat-service/v1/...`, `/offer-service/v1/...`).
///
/// To switch back to a real gateway, set [useMockPrefixes] to `false` —
/// every path then passes through unchanged.
class MockGatewayClient {
  MockGatewayClient._();

  /// Single source of truth for mock backend URL.
  /// Android emulator: 10.0.2.2 (host loopback alias).
  /// iOS simulator / physical device: override with your machine's LAN IP via
  /// `--dart-define=JEEB_MOCK_BASE_URL=http://<host-ip>:3055`.
  /// Port 3055 = Mockoon gateway-shaped mock (useMockPrefixes=false).
  static const String mockBaseUrl = String.fromEnvironment(
    'JEEB_MOCK_BASE_URL',
    defaultValue: 'http://10.0.2.2:3055',
  );

  /// When false every path passes through unchanged to the Mockoon mock at
  /// :3055, which speaks the real gateway contract (/v1/auth/otp/request, etc.).
  /// Set to true only when targeting the old :4010 service-prefixed mock.
  static const bool useMockPrefixes = false;

  static const Map<String, String> _pathToServicePrefix = {
    '/auth/otp': '/auth-service/auth/otp',
    '/auth/social': '/auth-service/auth/social',
    '/auth/refresh': '/auth-service/auth/refresh',
    '/users': '/user-management/users',
    '/v1/chat/jeeb': '/chat-service/v1/chat/jeeb',
    '/v1/offers': '/offer-service/v1/offers',
    '/v1/delivery': '/delivery-service/v1/delivery',
    '/v1/tiers': '/delivery-service/v1/tiers',
    // /v1/requests + /api/requests are both mounted under delivery-service in
    // the mock — keep them adjacent so the rewrite is exhaustive.
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
    '/v1/payments/cod_jeeb': '/unified-payment-gateway/v1/payments/cod_jeeb',
    '/v1/jeeb/earnings': '/wallet-service/v1/jeeb/earnings',
    '/api/deliveries': '/delivery-service/api/deliveries',
    '/v1/deliveries': '/delivery-service/v1/deliveries',
    '/v1/transcribe': '/voice-transcription-service/v1/transcribe',
    '/v1/devices': '/push-notification/v1/devices',
    '/channels/jeeb-chat': '/realtime-comunication-service/channels/jeeb-chat',
  };

  static String rewritePath(String path) {
    if (!useMockPrefixes) return path;

    for (final entry in _pathToServicePrefix.entries) {
      if (path.startsWith(entry.key)) {
        return path.replaceFirst(entry.key, entry.value);
      }
    }
    return path;
  }

  static Dio createDio({String? baseUrl}) {
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

    if (useMockPrefixes) {
      dio.interceptors.add(_PathRewriteInterceptor());
    }

    dio.interceptors.add(_AuthInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }

    return dio;
  }

  /// WebSocket URL for the realtime shim at port 3056.
  /// The companion shim handles Phoenix/SSE channels alongside the REST mock.
  static String get webSocketUrl {
    final base = Uri.parse(mockBaseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${base.host}:3056/socket/websocket';
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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _token;
    if (token != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
