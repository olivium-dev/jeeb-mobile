import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../dev_seam/dev_seam.dart';

/// Maps gateway-style paths to the mock backend's per-service prefix paths.
///
/// The Jeeb mobile app speaks only to `jeeb-gateway` (BFF). For local
/// development against the old service-prefixed mock backend, this client can
/// rewrite every outbound request path from the gateway contract
/// (`/v1/chat/jeeb/...`, `/v1/offers/...`) to service-prefixed routes
/// (`/chat-service/v1/...`, `/offer-service/v1/...`).
///
/// To switch back to a real gateway, set [useMockPrefixes] to `false` —
/// every path then passes through unchanged.
class MockGatewayClient {
  MockGatewayClient._();

  static const int _mockRestPort = 3055;
  static const int _mockSocketPort = 3056;

  /// Android-emulator-safe default. Physical devices must provide a runtime
  /// override; a developer LAN IP is not a portable default.
  static const String defaultMockBaseUrl = 'http://10.0.2.2:3055';

  static const String _dartDefinedMockBaseUrl = String.fromEnvironment(
    'JEEB_MOCK_BASE_URL',
    defaultValue: defaultMockBaseUrl,
  );

  /// Single source of truth for mock backend URL.
  ///
  /// Priority:
  /// 1. runtime dev seam (`jeeb.mock_base_url`) for physical-device APK reuse;
  /// 2. `--dart-define=JEEB_MOCK_BASE_URL=...` for build-time CI/dev flows;
  /// 3. Android emulator loopback (`10.0.2.2:3055`) for zero-config tests.
  static String get mockBaseUrl {
    return normalizeBaseUrl(DevSeam.current.mockBaseUrl) ??
        normalizeBaseUrl(_dartDefinedMockBaseUrl) ??
        defaultMockBaseUrl;
  }

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

  @visibleForTesting
  static String? normalizeBaseUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !_isHttpEndpoint(uri)) return null;
    return _stripTrailingSlashes(trimmed);
  }

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
    final effectiveBaseUrl = normalizeBaseUrl(baseUrl) ?? mockBaseUrl;

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
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }

    return dio;
  }

  /// WebSocket URL for the realtime shim at port 3056.
  /// The companion shim handles Phoenix/SSE channels alongside the REST mock.
  static String get webSocketUrl => webSocketUrlFor(mockBaseUrl);

  @visibleForTesting
  static String webSocketUrlFor(String baseUrl) {
    final base = Uri.parse(normalizeBaseUrl(baseUrl) ?? defaultMockBaseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final wsPort = base.hasPort
        ? (base.port == _mockRestPort ? _mockSocketPort : base.port)
        : null;
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: wsPort,
      path: '/socket/websocket',
    ).toString();
  }

  static bool _isHttpEndpoint(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  static String _stripTrailingSlashes(String value) {
    var normalized = value;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
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
