import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diagnostics.dart';
import '../observability/session_trace/session_trace.dart';
import 'auth_interceptor.dart';
import 'auth_token_store.dart';
import 'rate_limit_interceptor.dart';
import 'redacting_log_interceptor.dart';

/// Real gateway [Dio] factory. Talks the raw gateway `/v1/*` contract directly
/// to the configured base URL (no service-prefix rewrite — that is the local
/// Express-mock concern, see `MockGatewayClient`).
///
/// Wires, in order:
///   1. [BearerAuthInterceptor]   — attaches the persisted access token.
///   2. [TokenRefreshInterceptor] — single-shot refresh-on-401 + retry.
///   3. [LogInterceptor]          — DEBUG-ONLY (kDebugMode); request/response
///      bodies are PII (phones, tokens, addresses) and are never logged in
///      release/profile builds.
///
/// Security note: this factory installs NO `badCertificateCallback` /
/// `onBadCertificate` override, so the platform default — reject invalid TLS
/// certificates — stays in force. Do not add one.
class DioClient {
  DioClient._();

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 15);

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Dio createDio(
    String baseUrl, {
    AuthTokenStore? tokenStore,
    Future<void> Function()? onUnauthenticated,
  }) {
    final store = tokenStore ?? AuthTokenStore();

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        headers: Map<String, String>.from(_defaultHeaders),
      ),
    );

    // Bare client for the refresh round-trip: NO interceptors, so a 401 on
    // `/v1/auth/refresh` can never re-enter the refresh logic (loop guard).
    final refreshClient = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        headers: Map<String, String>.from(_defaultHeaders),
      ),
    );

    // 429 back-off gate FIRST (F3): while a `Retry-After` window is open it
    // short-circuits scheduled reads locally, before they ever reach the auth
    // interceptors or the network — so the customer home poll never retries on
    // schedule into a rate-limited gateway and turns one 429 into a storm.
    dio.interceptors.add(RateLimitInterceptor());

    dio.interceptors.add(BearerAuthInterceptor(store));
    dio.interceptors.add(
      TokenRefreshInterceptor(
        retryClient: dio,
        refreshClient: refreshClient,
        tokenStore: store,
        onUnauthenticated: onUnauthenticated,
      ),
    );

    // Diagnostic event stream (debug/dev-only, self-gated on `Diag.enabled`):
    // emits `[jeeb-diag] {"t":"api",...}` — path + status + duration ONLY, never
    // headers or bodies. Safe by construction; the redaction lives in the
    // interceptor, not here.
    dio.interceptors.add(const DiagDioInterceptor());

    // Session-trace observability tool (devtool-only, Module 2): captures the
    // full redacted HTTP exchange into the richer `ObsApiEvent` stream. Runs
    // ALONGSIDE DiagDioInterceptor, never replacing it. Compile-time gated on
    // `kObsCompiledIn` (a production build tree-shakes `ObsDioInterceptor` out
    // entirely); at runtime it never short-circuits a request and builds the
    // full (redacted) event only when `Observability.instance.recording` and
    // the `api` signal are both on.
    if (kObsCompiledIn) {
      dio.interceptors.add(const ObsDioInterceptor());
    }

    // PII GATE: request/response bodies carry phones, JWTs and addresses.
    // Only ever logged in debug builds (kDebugMode is a const false in
    // release/profile → the whole block is tree-shaken out).
    //
    // SECURITY (dev-logging token leak, closed here): the previous
    // `LogInterceptor(requestBody/responseBody: true)` — with Dio's default
    // `requestHeader: true` — printed the full `Authorization: Bearer` JWT
    // header, the FCM token in the `PUT /api/PushNotification/register` body,
    // and the `accessToken`/`refreshToken` in `/v1/auth/login|refresh` response
    // bodies to logcat in cleartext. [RedactingLogInterceptor] preserves the
    // debug ergonomics (method/path/status + headers + bodies) but replaces
    // every secret with a non-reversible correlation handle (`tok:<fnv8>~<last4>`)
    // — see [DiagRedaction].
    if (kDebugMode) {
      dio.interceptors.add(const RedactingLogInterceptor());
    }

    return dio;
  }
}
