import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diag_dio_interceptor.dart';
import 'auth_token_store.dart';
import 'redacting_log_interceptor.dart';

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
  static String get mockBaseUrl {
    if (_baseUrlDefine.isNotEmpty) return _baseUrlDefine;
    // RELIABILITY (super-login hardening): when NO --dart-define is passed, a
    // debug build defaults to the live DEV GATEWAY (which serves the raw `/v1/*`
    // and `/api/*` contract incl. super-login) instead of the :4010 Express
    // mock, so a plain `flutter run`/`--debug` build is coherent and the dev
    // super-login flow works out of the box. Release keeps the historical
    // fallback (release builds always pass the define anyway).
    if (kDebugMode) return _devGatewayBaseUrl;
    return _releaseFallbackBaseUrl;
  }

  /// Build-time override (`--dart-define=JEEB_MOCK_BASE_URL=...`). Empty when
  /// not passed.
  static const String _baseUrlDefine =
      String.fromEnvironment('JEEB_MOCK_BASE_URL');

  /// Debug no-define default: the live dev gateway (BFF) on the LAN. Serves the
  /// raw gateway contract, so `useMockPrefixes` stays `false`.
  static const String _devGatewayBaseUrl = 'http://192.168.2.39:10090';

  /// Release no-define fallback (historical value; release builds pass the
  /// define explicitly so this is rarely hit).
  static const String _releaseFallbackBaseUrl = 'http://192.168.2.33:4010';

  /// When `true` every gateway path is rewritten to the Express mock's
  /// service-prefixed routes (`/auth-service/...`, `/offer-service/v1/...`)
  /// and sent to [mockBaseUrl] = the Express mock on :4010.
  ///
  /// When `false` (the production/device default) every path passes through
  /// unchanged — the app speaks the raw gateway contract (`/v1/auth/otp/request`,
  /// `/v1/jeeb/wallet`, …) directly to [mockBaseUrl], which must be a real
  /// gateway (or Mockoon :3055) that serves those /v1/* paths.
  ///
  /// Controlled via dart-define at build time:
  ///   --dart-define=JEEB_USE_MOCK_PREFIXES=true   → Express mock on :4010
  ///   --dart-define=JEEB_USE_MOCK_PREFIXES=false  → real gateway (device builds)
  /// Default is `false` so physical-device and CI builds default to live-gateway
  /// mode; only explicit local-mock builds need to pass `true`.
  static const bool useMockPrefixes =
      bool.fromEnvironment('JEEB_USE_MOCK_PREFIXES', defaultValue: false);

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

  /// Canonical saved-locations collection base path for the ACTIVE backend.
  ///
  /// VERIFIED against the live dev gateway (`:10090`) on 2026-06-30 with a real
  /// super-login JWT:
  ///   GET    /api/users/me/saved-locations      -> 200 {userId, items, defaultId}
  ///   POST   /api/users/me/saved-locations      -> 201 (top-level latitude/longitude)
  ///   DELETE /api/users/me/saved-locations/:id  -> 204
  /// The live BFF keys the collection on the AUTHENTICATED user (`me`) under the
  /// `/api` prefix — NOT on a path `:userId`, and NOT under `/v1`. The previous
  /// `/users/:userId/saved-locations` shape returned a *no-route* 404 on the live
  /// gateway (empty body, no content-type — a routing miss, not an app 404). That
  /// 404 was earlier misread as "the gateway 404s a customer with no saved
  /// addresses"; in fact the real route returns `200 {items:[]}` for an empty
  /// customer, so saved locations never loaded and could never be selected.
  ///
  /// The `:4010` Express mock instead keys the collection by `:userId` and is
  /// reached only via the `/users` -> `/user-management/users` rewrite, which
  /// runs solely when [useMockPrefixes] is `true`. So in mock mode we keep
  /// emitting the rewriteable `/users/:userId/...` shape; against the live
  /// gateway we emit the real `/api/users/me/...` contract. One helper keeps
  /// BOTH targets green.
  static String savedLocationsPath({required String userId}) => useMockPrefixes
      ? '/users/$userId/saved-locations'
      : '/api/users/me/saved-locations';

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

    // Diagnostic event stream (self-gated on `Diag.enabled`, i.e. debug/dev
    // only): emits `[jeeb-diag] {"t":"api",...}` — method + query-stripped
    // path + status + duration ONLY; never headers or bodies. This is the
    // app-wide Dio that DI registers (see injection_container.dart), so the
    // diag api stream MUST be wired here — dio_client.dart alone does not
    // cover live traffic.
    dio.interceptors.add(const DiagDioInterceptor());

    if (kDebugMode) {
      // SECURITY (run-22): the raw `LogInterceptor(requestBody/responseBody:
      // true)` printed the full `Authorization: Bearer <JWT>` header and token
      // bodies to logcat (1017 raw Bearer/JWT matches counted in one run).
      // RedactingLogInterceptor keeps the same request/response visibility but
      // replaces every sensitive header/body value with a non-reversible
      // `tok:<fnv8>~<last4>` correlation handle (see diag_redaction.dart).
      dio.interceptors.add(const RedactingLogInterceptor());
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
