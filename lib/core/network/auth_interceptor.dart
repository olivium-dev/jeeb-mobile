import 'package:dio/dio.dart';

import '../session/auth_loss_signals.dart';
import 'auth_token_store.dart';
import 'jwt_expiry.dart';

class BearerAuthInterceptor extends Interceptor {
  BearerAuthInterceptor(this._tokenStore);

  final AuthTokenStore _tokenStore;

  /// NET-02: the keystore read failed, so this request carries no bearer. The
  /// 401 is classified, never logged out on — the store may read again later.
  static const String storeUnavailableFlag = 'jeeb.auth.store_unavailable';

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
          // Only bearers WE attached are session tokens; callers that pin
          // their own (act-as/admin devtool flows) must never be rotated.
          options.extra[TokenRefreshInterceptor.sessionBearerFlag] = true;
        }
      } catch (_) {
        options.extra[storeUnavailableFlag] = true;
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
    // FLAG-DAY: removing this route logs out every installed app on token
    // expiry. Preconditions in docs/adr/0002-v1-unversioned-compat-window.md.
    this.refreshPath = '/v1/auth/refresh',
    this.proactiveWindow = const Duration(seconds: 60),
    this.transientCooldown = const Duration(seconds: 20),
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

  /// After a transient refresh failure, no new attempt starts inside this
  /// window — queued lanes are serial, so retries would stack 15s stalls.
  final Duration transientCooldown;

  final DateTime Function() _clock;
  final Future<void> Function()? _onUnauthenticated;

  /// Shared by the request and error lanes, whose queues run in parallel:
  /// concurrent callers await one physical refresh instead of racing rotation.
  Future<String?>? _inFlight;

  DateTime? _cooldownUntil;

  static const String _retriedFlag = 'jeeb.auth.retried';

  /// Set by [BearerAuthInterceptor] when it attaches the stored session
  /// token. Requests without it carry a caller-owned bearer (or none) and
  /// must pass through both lanes untouched.
  static const String sessionBearerFlag = 'jeeb.auth.session_bearer';

  /// NET-17: this 401 was raised inside the post-failure cooldown, so the
  /// session is recovering rather than rejected — retry copy, not sign-in.
  static const String recoveringFlag = 'jeeb.auth.recovering';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final sent = _bearerOf(options);
    if (sent == null ||
        options.extra[sessionBearerFlag] != true ||
        options.path.contains('auth/refresh')) {
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
    // On failure the stale bearer goes out anyway; only the reactive 401
    // lane may declare the session dead — never a pre-send optimization.
    final fresh = await _refreshSession(allowTerminal: false);
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

    // NET-02: no bearer went out because the store was unreadable — a local,
    // often transient fault (locked keychain), never a gateway verdict.
    if (status == 401 &&
        options.extra[BearerAuthInterceptor.storeUnavailableFlag] == true) {
      handler.next(err);
      return;
    }

    if (status != 401 ||
        options.extra[sessionBearerFlag] != true ||
        options.path.contains('auth/refresh') ||
        options.extra[_retriedFlag] == true) {
      handler.next(err);
      return;
    }

    // A consumed one-shot body cannot be replayed; refresh still runs so the
    // session heals for later requests, but the caller keeps the 401.
    final replayable = options.data is! FormData && options.data is! Stream;

    // Generation check: when storage already holds a different token, an
    // earlier queued 401 refreshed for us — retry, do not refresh again.
    final sent = _bearerOf(options);
    final stored = await _safeRead(() => _tokenStore.accessToken);
    if (stored != null && stored.isNotEmpty && stored != sent) {
      if (!replayable) {
        handler.next(err);
        return;
      }
      await _retryWith(stored, options, handler);
      return;
    }

    final refreshToken = await _safeRead(() => _tokenStore.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _logout();
      handler.next(err);
      return;
    }

    final fresh = await _refreshSession(allowTerminal: true);
    if (fresh == null || !replayable) {
      // Terminal failures already logged out inside; transient ones keep the
      // tokens. Either way the caller sees the original 401.
      if (fresh == null && _inCooldown) options.extra[recoveringFlag] = true;
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

  bool get _inCooldown {
    final until = _cooldownUntil;
    return until != null && _clock().toUtc().isBefore(until);
  }

  Future<String?> _refreshSession({required bool allowTerminal}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final until = _cooldownUntil;
    if (until != null && _clock().toUtc().isBefore(until)) {
      return Future<String?>.value(null);
    }
    final started = _doRefresh(
      allowTerminal: allowTerminal,
    ).whenComplete(() => _inFlight = null);
    _inFlight = started;
    return started;
  }

  Future<String?> _doRefresh({required bool allowTerminal}) async {
    final refreshToken = await _safeRead(() => _tokenStore.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      if (allowTerminal) await _logout();
      return null;
    }

    final Response<dynamic> refreshResponse;
    try {
      refreshResponse = await _refreshClient.post<dynamic>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (refreshErr) {
      // Only the gateway's own auth verdict is terminal. 429/408/404, edge
      // 403-less noise, 5xx and network failures must never destroy tokens.
      final refreshStatus = refreshErr.response?.statusCode;
      if (allowTerminal && (refreshStatus == 401 || refreshStatus == 403)) {
        await _logout();
      } else {
        _cooldownUntil = _clock().toUtc().add(transientCooldown);
      }
      return null;
    }

    // Parse + persist may throw (malformed body, keystore write failure).
    // An escaped async error would wedge dio's serialized lane — never throw.
    try {
      final body = refreshResponse.data;
      final newAccess = body is Map<String, dynamic>
          ? body['accessToken'] as String?
          : null;
      final newRefresh = body is Map<String, dynamic>
          ? body['refreshToken'] as String?
          : null;
      if (newAccess == null || newAccess.isEmpty) {
        if (allowTerminal) {
          await _logout();
        } else {
          _cooldownUntil = _clock().toUtc().add(transientCooldown);
        }
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
      _cooldownUntil = null;
      return newAccess;
    } catch (_) {
      _cooldownUntil = _clock().toUtc().add(transientCooldown);
      return null;
    }
  }

  String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    final token = header.substring('Bearer '.length);
    return token.isEmpty ? null : token;
  }

  Future<void> _logout({
    AuthLossReason reason = AuthLossReason.sessionExpired,
  }) async {
    try {
      await _tokenStore.clear();
    } catch (_) {}
    final cb = _onUnauthenticated;
    if (cb != null) {
      try {
        await cb();
      } catch (_) {}
    }
    AuthLossSignals.instance.signal(reason: reason);
  }

  Future<String?> _safeRead(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }
}
