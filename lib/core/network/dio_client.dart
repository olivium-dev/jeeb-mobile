import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diagnostics.dart';
import 'auth_interceptor.dart';
import 'auth_token_store.dart';

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

    // PII GATE: request/response bodies carry phones, JWTs and addresses.
    // Only ever logged in debug builds (kDebugMode is a const false in
    // release/profile → the whole block is tree-shaken out).
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
}
