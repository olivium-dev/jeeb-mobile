import 'package:dio/dio.dart';

import 'auth_token_store.dart';

class BearerAuthInterceptor extends Interceptor {
  BearerAuthInterceptor(this._tokenStore);

  final AuthTokenStore _tokenStore;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.headers.containsKey('Authorization')) {
      try {
        final token = await _tokenStore.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
      }
    }
    handler.next(options);
  }
}

class TokenRefreshInterceptor extends QueuedInterceptor {
  TokenRefreshInterceptor({
    required Dio retryClient,
    required Dio refreshClient,
    required AuthTokenStore tokenStore,
    this.refreshPath = '/v1/auth/refresh',
    Future<void> Function()? onUnauthenticated,
  })  : _retryClient = retryClient,
        _refreshClient = refreshClient,
        _tokenStore = tokenStore,
        _onUnauthenticated = onUnauthenticated;

  final Dio _retryClient;
  final Dio _refreshClient;
  final AuthTokenStore _tokenStore;
  final String refreshPath;
  final Future<void> Function()? _onUnauthenticated;

  static const String _retriedFlag = 'jeeb.auth.retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final options = err.requestOptions;

    if (status != 401 ||
        options.path.contains('auth/refresh') ||
        options.extra[_retriedFlag] == true) {
      handler.next(err);
      return;
    }

    final refreshToken = await _safeRead(() => _tokenStore.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _logout();
      handler.next(err);
      return;
    }

    final Response<dynamic> refreshResponse;
    try {
      refreshResponse = await _refreshClient.post<dynamic>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      await _logout();
      handler.next(err);
      return;
    }

    final body = refreshResponse.data;
    final newAccess =
        body is Map<String, dynamic> ? body['accessToken'] as String? : null;
    final newRefresh =
        body is Map<String, dynamic> ? body['refreshToken'] as String? : null;
    if (newAccess == null || newAccess.isEmpty) {
      await _logout();
      handler.next(err);
      return;
    }

    final existingUserId = await _safeRead(() => _tokenStore.userId);
    await _tokenStore.save(
      accessToken: newAccess,
      refreshToken: (newRefresh != null && newRefresh.isNotEmpty)
          ? newRefresh
          : refreshToken,
      userId: existingUserId,
    );

    options.extra[_retriedFlag] = true;
    options.headers['Authorization'] = 'Bearer $newAccess';
    try {
      final retried = await _retryClient.fetch<dynamic>(options);
      handler.resolve(retried);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  Future<void> _logout() async {
    try {
      await _tokenStore.clear();
    } catch (_) {
    }
    final cb = _onUnauthenticated;
    if (cb != null) {
      try {
        await cb();
      } catch (_) {
      }
    }
  }

  Future<String?> _safeRead(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }
}
