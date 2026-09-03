import 'package:dio/dio.dart';

import '../session/auth_loss_signals.dart';
import 'auth_token_store.dart';
import 'jwt_expiry.dart';

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
      } catch (_) {}
    }
    handler.next(options);
  }
}

class TokenRefreshInterceptor extends QueuedInterceptor {
  TokenRefreshInterceptor({
    required Dio retryClient,
    required Dio refreshClient,
    required AuthTokenStore tokenStore,
    // FLAG-DAY: removing this route logs out every installed app on token
    // expiry. Preconditions in docs/adr/0002-v1-unversioned-compat-window.md.
    this.refreshPath = '/v1/auth/refresh',
    this.proactiveWindow = const Duration(seconds: 60),
    DateTime Function()? clock,
    Future<void> Function()? onUnauthenticated,
  }) : _retryClient = retryClient,
       _refreshClient = refreshClient,
       _tokenStore = tokenStore,
       _clock = clock ?? DateTime.now,
       _onUnauthenticated = onUnauthenticated;

  final Dio _retryClient;
  final Dio _refreshClient;
  final AuthTokenStore _tokenStore;
  final String refreshPath;

  /// A bearer whose `exp` falls inside this window is rotated before send.
  final Duration proactiveWindow;

  final DateTime Function() _clock;
  final Future<void> Function()? _onUnauthenticated;

  /// Shared by the request and error lanes, whose queues run in parallel:
  /// concurrent callers await one physical refresh instead of racing rotation.
  Future<String?>? _inFlight;

  static const String _retriedFlag = 'jeeb.auth.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final sent = _bearerOf(options);
    if (sent == null || options.path.contains('auth/refresh')) {
      handler.next(options);
      return;
    }
    final exp = jwtExpiry(sent);
    if (exp == null || exp.isAfter(_clock().toUtc().add(proactiveWindow))) {
      handler.next(options);
      return;
    }
    // A queued predecessor may have rotated the pair while this call waited.
    final stored = await _safeRead(() => _tokenStore.accessToken);
    if (stored != null && stored.isNotEmpty && stored != sent) {
      options.headers['Authorization'] = 'Bearer $stored';
      handler.next(options);
      return;
    }
    // On failure the stale bearer goes out anyway; the reactive 401 path stays
    // authoritative and owns the terminal-versus-transient decision.
    final fresh = await _refreshSession();
    if (fresh != null) {
      options.headers['Authorization'] = 'Bearer $fresh';
    }
    handler.next(options);
  }

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

    // Generation check: when storage already holds a different token, an
    // earlier queued 401 refreshed for us — retry, do not refresh again.
    final sent = _bearerOf(options);
    final stored = await _safeRead(() => _tokenStore.accessToken);
    if (stored != null && stored.isNotEmpty && stored != sent) {
      await _retryWith(stored, options, handler);
      return;
    }

    final refreshToken = await _safeRead(() => _tokenStore.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _logout();
      handler.next(err);
      return;
    }

    final fresh = await _refreshSession();
    if (fresh == null) {
      // Terminal failures already logged out inside; transient ones keep the
      // tokens. Either way the caller sees the original 401.
      handler.next(err);
      return;
    }
    await _retryWith(fresh, options, handler);
  }

  Future<void> _retryWith(
    String token,
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    options.extra[_retriedFlag] = true;
    options.headers['Authorization'] = 'Bearer $token';
    try {
      final retried = await _retryClient.fetch<dynamic>(options);
      handler.resolve(retried);
    } on DioException catch (retryErr) {
      if (retryErr.response?.statusCode == 401) await _logout();
      handler.next(retryErr);
    }
  }

  Future<String?> _refreshSession() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final started = _doRefresh().whenComplete(() => _inFlight = null);
    _inFlight = started;
    return started;
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _safeRead(() => _tokenStore.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _logout();
      return null;
    }

    final Response<dynamic> refreshResponse;
    try {
      refreshResponse = await _refreshClient.post<dynamic>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (refreshErr) {
      // Only a definitive 4xx verdict (e.g. auth/invalid_refresh) is terminal;
      // network failures and 5xx must never log out an offline user.
      final refreshStatus = refreshErr.response?.statusCode;
      if (refreshStatus != null && refreshStatus >= 400 && refreshStatus < 500) {
        await _logout();
      }
      return null;
    }

    final body = refreshResponse.data;
    final newAccess = body is Map<String, dynamic>
        ? body['accessToken'] as String?
        : null;
    final newRefresh = body is Map<String, dynamic>
        ? body['refreshToken'] as String?
        : null;
    if (newAccess == null || newAccess.isEmpty) {
      await _logout();
      return null;
    }

    final existingUserId = await _safeRead(() => _tokenStore.userId);
    await _tokenStore.save(
      accessToken: newAccess,
      refreshToken: (newRefresh != null && newRefresh.isNotEmpty)
          ? newRefresh
          : refreshToken,
      userId: existingUserId,
    );
    return newAccess;
  }

  String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    final token = header.substring('Bearer '.length);
    return token.isEmpty ? null : token;
  }

  Future<void> _logout() async {
    try {
      await _tokenStore.clear();
    } catch (_) {}
    final cb = _onUnauthenticated;
    if (cb != null) {
      try {
        await cb();
      } catch (_) {}
    }
    AuthLossSignals.instance.signal();
  }

  Future<String?> _safeRead(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }
}
