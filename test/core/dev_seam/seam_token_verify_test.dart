import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/session_seam_bootstrap.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted adapter that records calls; a null script means "must not be hit".
class _ProbeAdapter implements HttpClientAdapter {
  _ProbeAdapter([this._respond]);

  final ResponseBody Function(RequestOptions options)? _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final respond = _respond;
    if (respond == null) {
      fail('the seam guard probed the network when it must not');
    }
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStore implements AuthTokenStore {
  String? storedAccess;
  String? storedRefresh;
  String? storedUserId;
  int saves = 0;

  @override
  Future<String?> get accessToken async => storedAccess;
  @override
  Future<String?> get refreshToken async => storedRefresh;
  @override
  Future<String?> get userId async => storedUserId;
  @override
  Future<bool> get hasToken async => storedAccess != null;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    saves++;
    storedAccess = accessToken;
    storedRefresh = refreshToken;
    storedUserId = userId;
  }

  @override
  Future<void> clear() async {
    storedAccess = null;
    storedRefresh = null;
    storedUserId = null;
  }
}

String _jwtWithExp(DateTime exp) {
  String seg(Map<String, Object?> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.'
      '${seg({'exp': exp.toUtc().millisecondsSinceEpoch ~/ 1000})}.sig';
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Dio _probeDio(_ProbeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://localhost:4010'))
      ..httpClientAdapter = adapter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clock = DateTime.utc(2026, 9, 3, 12);
  Uri? base() => Uri.parse('http://localhost:4010');

  group('SessionSeamBootstrap.verifySeamToken', () {
    test('a locally expired JWT is rejected with NO network call', () async {
      final adapter = _ProbeAdapter();
      final verdict = await SessionSeamBootstrap.verifySeamToken(
        _jwtWithExp(clock.subtract(const Duration(days: 1))),
        resolveBase: base,
        client: _probeDio(adapter),
        clock: () => clock,
      );

      expect(verdict, SeamTokenVerdict.rejected);
      expect(adapter.requests, isEmpty);
    });

    test('a 2xx probe verifies the token', () async {
      final adapter = _ProbeAdapter((_) => _json({'id': 'u-1'}, 200));
      final verdict = await SessionSeamBootstrap.verifySeamToken(
        'live-looking-token',
        resolveBase: base,
        client: _probeDio(adapter),
        clock: () => clock,
      );

      expect(verdict, SeamTokenVerdict.verified);
      final probe = adapter.requests.single;
      expect(probe.path, '/v1/users/me');
      expect(probe.headers['Authorization'], 'Bearer live-looking-token');
    });

    test('a 401 probe rejects — the exact stale-seam incident', () async {
      final adapter = _ProbeAdapter((_) => _json({'error': 'expired'}, 401));
      final verdict = await SessionSeamBootstrap.verifySeamToken(
        // A revoked token can still carry a future exp; only the probe knows.
        _jwtWithExp(clock.add(const Duration(days: 30))),
        resolveBase: base,
        client: _probeDio(adapter),
        clock: () => clock,
      );

      expect(verdict, SeamTokenVerdict.rejected);
    });

    test('a 403 probe rejects', () async {
      final adapter = _ProbeAdapter((_) => _json({'error': 'forbidden'}, 403));
      final verdict = await SessionSeamBootstrap.verifySeamToken(
        'some-token',
        resolveBase: base,
        client: _probeDio(adapter),
        clock: () => clock,
      );

      expect(verdict, SeamTokenVerdict.rejected);
    });

    test('a network failure fails OPEN (offline dev keeps working)', () async {
      final adapter = _ProbeAdapter(
        (options) =>
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
      );
      final verdict = await SessionSeamBootstrap.verifySeamToken(
        'some-token',
        resolveBase: base,
        client: _probeDio(adapter),
        clock: () => clock,
      );

      expect(verdict, SeamTokenVerdict.unverified);
    });

    test('an unroutable .invalid base fails open with NO probe', () async {
      final adapter = _ProbeAdapter();
      final verdict = await SessionSeamBootstrap.verifySeamToken(
        'some-token',
        resolveBase: () => Uri.parse('https://gateway.dev.invalid'),
        client: _probeDio(adapter),
        clock: () => clock,
      );

      expect(verdict, SeamTokenVerdict.unverified);
      expect(adapter.requests, isEmpty);
    });
  });

  group('seed() super_login_plus with the guard', () {
    tearDown(DevSeam.debugReset);

    Future<SharedPreferences> freshPrefs() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return SharedPreferences.getInstance();
    }

    test('an expired seam JWT is dropped: nothing saved, /login lands',
        () async {
      if (!kDebugMode) return; // the seam is release-inert anyway
      DevSeam.debugOverride(
        DevSeamConfig(
          sessionSeed: SessionSeed.superLoginPlus,
          superLoginToken: _jwtWithExp(
            DateTime.now().toUtc().subtract(const Duration(days: 12)),
          ),
          superLoginUserId: 'user-stale-1',
        ),
      );
      final tokens = _MemoryTokenStore();

      await SessionSeamBootstrap.seed(
        prefs: await freshPrefs(),
        tokenStore: tokens,
      );

      expect(tokens.saves, 0, reason: 'a dead token must never be trusted');
      expect(await tokens.accessToken, isNull);
    });

    test('an unverifiable token still seeds, with an EMPTY refresh token',
        () async {
      if (!kDebugMode) return;
      // No base-url override + the .invalid dev default → probe is skipped.
      DevSeam.debugOverride(
        const DevSeamConfig(
          sessionSeed: SessionSeed.superLoginPlus,
          superLoginToken: 'opaque-seed-token',
          superLoginUserId: 'user-seed-1',
        ),
      );
      final tokens = _MemoryTokenStore();

      await SessionSeamBootstrap.seed(
        prefs: await freshPrefs(),
        tokenStore: tokens,
      );

      expect(await tokens.accessToken, 'opaque-seed-token');
      expect(
        await tokens.refreshToken,
        isEmpty,
        reason: 'the access token must never masquerade as a refresh token',
      );
      expect(await tokens.userId, 'user-seed-1');
    });
  });
}
