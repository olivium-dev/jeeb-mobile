import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diagnostics.dart';
import '../observability/session_trace/session_trace.dart';
import 'auth_interceptor.dart';
import 'auth_token_store.dart';
import 'rate_limit_interceptor.dart';
import 'redacting_log_interceptor.dart';

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

    final refreshClient = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        headers: Map<String, String>.from(_defaultHeaders),
      ),
    );

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

    dio.interceptors.add(const DiagDioInterceptor());

    if (kObsCompiledIn) {
      dio.interceptors.add(const ObsDioInterceptor());
    }

    if (kDebugMode) {
      dio.interceptors.add(const RedactingLogInterceptor());
    }

    return dio;
  }
}
