import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_token_store.dart';

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
  ///
  /// The run/build ALWAYS passes `--dart-define=JEEB_MOCK_BASE_URL=...` so this
  /// default is only the fallback when no define is given. It points at the
  /// host machine's LAN IP so iOS simulators and physical devices reach the
  /// mock directly out of the box (#37):
  ///   iOS sim / device / Android emulator: the LAN-IP default below works for all.
  ///   Android emulator alt: --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010
  ///                         (host loopback alias → host :4010)
  ///
  /// B0 (W-1): the default MUST point at the Express mock on **:4010** to stay
  /// internally consistent with `useMockPrefixes = true` below. It previously
  /// defaulted to the Mockoon port (:3055), which — combined with the
  /// service-prefix rewrite — sent rewritten `:4010`-shaped paths to a mock
  /// that speaks a different contract. The default stays on :4010 so the pair
  /// (mockBaseUrl, useMockPrefixes) is coherent even without a dart-define; #37
  /// only swaps the Android-emulator-only `10.0.2.2` loopback for the LAN IP so
  /// iOS sims and physical devices are reachable too.
  static const String mockBaseUrl = String.fromEnvironment(
    'JEEB_MOCK_BASE_URL',
    defaultValue: 'http://192.168.2.33:4010',
  );

  /// When `true` (current) every gateway path is rewritten to the Express
  /// mock's service-prefixed routes (`/auth-service/...`, `/offer-service/v1/...`)
  /// and sent to [mockBaseUrl] = the Express mock on :4010.
  ///
  /// When `false` every path passes through unchanged to a gateway-shaped mock
  /// (e.g. Mockoon) that speaks the raw gateway contract (`/v1/auth/otp/request`).
  /// If you flip this to `false`, also override [mockBaseUrl] to that mock's port.
  static const bool useMockPrefixes = true;

  static const Map<String, String> _pathToServicePrefix = {
    // B1 (W-1) — gateway `/v1/auth/*` → Express mock `/auth-service/auth/*`.
    // The app's data layer posts the gateway contract (`/v1/auth/otp/request`,
    // `/v1/auth/login`, …); the Express mock mounts the auth router at
    // `/auth-service/auth/...`. These `/v1/auth/*` keys are the bridge and MUST
    // precede the broader `/v1/*` siblings below (specific-before-general,
    // first-match-wins). None of the `/v1/*` keys below is a prefix of these.
    '/v1/auth/otp': '/auth-service/auth/otp',
    '/v1/auth/login': '/auth-service/auth/login',
    '/v1/auth/signup': '/auth-service/auth/signup',
    '/v1/auth/social': '/auth-service/auth/social',
    '/v1/auth/recovery': '/auth-service/auth/recovery',
    '/v1/auth/set-password': '/auth-service/auth/set-password',
    '/v1/auth/refresh': '/auth-service/auth/refresh',
    '/v1/auth/logout': '/auth-service/auth/logout',
    // B2 (W-1) — social_auth_service.dart posts the legacy `/api/auth/social`
    // path (T-mobile-003). Route it to the same mock social handler so both the
    // gateway `/v1/auth/social` and the app's `/api/auth/social` reach :4010.
    '/api/auth/social': '/auth-service/auth/social',
    // Legacy non-`/v1` auth keys — kept for backward compat with any caller
    // still posting the un-versioned gateway shape.
    '/auth/otp': '/auth-service/auth/otp',
    '/auth/social': '/auth-service/auth/social',
    '/auth/refresh': '/auth-service/auth/refresh',
    // The live gateway serves the getMe/profile read at `/v1/users/me`; the
    // Express mock mounts user-management at `/user-management/users/me`. This
    // bridge strips the `/v1` segment so `/v1/users/me` reaches the mock route.
    // MUST precede the un-versioned `/users` sibling (first-match-wins); neither
    // is a prefix of the other, so order between them is otherwise free.
    '/v1/users': '/user-management/users',
    '/users': '/user-management/users',
    // W2 KYC (66_W2_QA_RESULTS C2): the Flutter KYC gateway
    // (`dio_kyc_gateway.dart`) speaks the gateway `/v1/kyc/*` contract
    // (form-schema / contract-template / submit / status); the Express mock
    // mounts that router under `/user-management` (`user-management.ts`
    // `/v1/kyc/*`). Without this bridge the app hit `:4010/v1/kyc/status`
    // verbatim → 404, so the KYC wizard's `loadStatus()` never resolved and the
    // status view (`kyc_status_root`) stayed on its loading spinner — exactly the
    // C2 "kyc_status_root unreachable" symptom (jm-041/042). Must precede the
    // broader `/v1/*` siblings (first-match-wins); none of them is a prefix of
    // `/v1/kyc`.
    '/v1/kyc': '/user-management/v1/kyc',
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
    // JM-063 (S1 LIVE): the support-ticket routes are now mounted (gateway PR
    // #200). ONE key covers create (`POST /v1/support/tickets`), get-by-id,
    // list and categories — all share the `/v1/support` prefix. It is a SIBLING
    // of every other `/v1/*` key (none is a prefix of the other), so declaration
    // order is safe (first-match-wins, 42_GUARDRAILS_MOCK §1.2).
    '/v1/support': '/support-service/v1/support',
    '/v1/payments/cod_jeeb': '/unified-payment-gateway/v1/payments/cod_jeeb',
    // W3-INT (JM-053/055/056): the wallet read model lives on the wallet-service
    // alongside earnings. ONE key covers the W1m balance (`/v1/jeeb/wallet`), the
    // W2m ledger (`/v1/jeeb/wallet/ledger`) and the W3m txn-by-id
    // (`/v1/jeeb/wallet/ledger/:id`) — all share the `/v1/jeeb/wallet` prefix.
    // It is a SIBLING of `/v1/jeeb/earnings` (neither is a prefix of the other
    // once `/wallet` vs `/earnings` diverge), so declaration order is safe
    // (first-match-wins, 42_GUARDRAILS_MOCK §1.2). W2m is LIVE; W1m/W3m bind to
    // INTEGRATOR-STUB repos until they land (CTO-D2).
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

  /// Explicit override (the real login flow can push a token here). When unset,
  /// the interceptor falls back to the persisted [AuthTokenStore] token (the
  /// single source of truth the dev-seam `_logIn` writes). Without this fallback
  /// the bearer was NEVER attached (`setToken` is unused), so the mock's
  /// `authStub` resolved every authenticated call to its default `user-client-001`
  /// — which broke the jeeber money path (the seeded `user-jeeber-002` wallet was
  /// never read → O1 402 never fired for jm-045 AC5 / jm-046). 68_W34 closeout.
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
      // A token-store read failure must never break a request — degrade to no
      // bearer (the mock's authStub then defaults the identity, as before).
      return null;
    }
  }
}
