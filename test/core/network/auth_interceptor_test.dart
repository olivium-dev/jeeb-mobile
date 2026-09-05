import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/app_failure_mapper.dart';
import 'package:jeeb_mobile/core/network/auth_interceptor.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/network/unversioned_path_fallback_interceptor.dart';
import 'package:jeeb_mobile/core/session/auth_loss_signals.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_dio_interceptor.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';

/// Lowest-level Dio adapter that returns scripted [ResponseBody]s per request,
/// so the token-refresh flow can be exercised end-to-end without a real socket.
/// Records every [RequestOptions] it sees for post-hoc assertions.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  /// Path snapshotted at call time: a replay MUTATES the RequestOptions it
  /// reuses, so reading `requests.last.path` afterwards reads the final value.
  final List<String> paths = <String>[];

  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    paths.add(options.path);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MockTokenStore extends Mock implements AuthTokenStore {}

final class _ObsSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> close() async {}

  @override
  Future<void> flush() async {}

  @override
  String? get sessionFilePath => '/tmp/auth-interceptor-obs.jsonl';
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Unsigned JWT whose payload carries only `exp`, for proactive-window tests.
String _jwtWithExp(DateTime exp) {
  String seg(Map<String, Object?> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.'
      '${seg({'exp': exp.toUtc().millisecondsSinceEpoch ~/ 1000})}.sig';
}

/// Simulates what BearerAuthInterceptor stamps on session-owned requests;
/// caller-pinned foreign bearers never carry the flag.
Options _asSession(String token, {Map<String, Object?>? extra}) => Options(
  headers: {'Authorization': 'Bearer $token'},
  extra: {TokenRefreshInterceptor.sessionBearerFlag: true, ...?extra},
);

void main() {
  late _MockTokenStore store;

  // Defaults used by the happy-refresh path; individual tests override.
  setUp(() {
    store = _MockTokenStore();
    when(() => store.accessToken).thenAnswer((_) async => null);
    when(() => store.refreshToken).thenAnswer((_) async => 'old-refresh');
    when(() => store.userId).thenAnswer((_) async => 'user-1');
    when(
      () => store.save(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  /// Builds the three-Dio harness the interceptor is designed around:
  ///   - [mainDio] carries the [TokenRefreshInterceptor] and serves the
  ({
    Dio mainDio,
    _ScriptedAdapter mainAdapter,
    _ScriptedAdapter retryAdapter,
    _ScriptedAdapter refreshAdapter,
    List<String> logoutCalls,
  })
  buildHarness({
    required ResponseBody Function(RequestOptions) mainResponder,
    required ResponseBody Function(RequestOptions) retryResponder,
    required ResponseBody Function(RequestOptions) refreshResponder,
    bool refreshFallback = false,
    bool observeWireAttempts = false,
    DateTime Function()? clock,
  }) {
    final mainAdapter = _ScriptedAdapter(mainResponder);
    final retryAdapter = _ScriptedAdapter(retryResponder);
    final refreshAdapter = _ScriptedAdapter(refreshResponder);
    final logoutCalls = <String>[];

    final retryClient = Dio()..httpClientAdapter = retryAdapter;
    final refreshClient = Dio()..httpClientAdapter = refreshAdapter;
    if (observeWireAttempts) {
      ObsDioInterceptor.attachTo(retryClient);
      ObsDioInterceptor.attachTo(refreshClient);
    }
    if (refreshFallback) {
      refreshClient.interceptors.add(
        UnversionedPathFallbackInterceptor(
          refreshClient,
          scopedToSubtrees: const <String>['/v1/auth'],
        ),
      );
    }

    final mainDio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'))
      ..httpClientAdapter = mainAdapter;
    if (observeWireAttempts) ObsDioInterceptor.attachTo(mainDio);
    mainDio.interceptors.add(
      TokenRefreshInterceptor(
        retryClient: retryClient,
        refreshClient: refreshClient,
        tokenStore: store,
        clock: clock,
        onUnauthenticated: () async => logoutCalls.add('logout'),
      ),
    );

    return (
      mainDio: mainDio,
      mainAdapter: mainAdapter,
      retryAdapter: retryAdapter,
      refreshAdapter: refreshAdapter,
      logoutCalls: logoutCalls,
    );
  }

  test('returns response on success — 200 passes through unchanged', () async {
    final h = buildHarness(
      mainResponder: (_) => _json({'ok': true}, 200),
      retryResponder: (_) => _json({'unexpected': true}, 200),
      refreshResponder: (_) => _json({'unexpected': true}, 200),
    );

    final res = await h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access'));

    expect(res.statusCode, 200);
    expect(res.data, {'ok': true});
    // The error pipeline never engaged.
    expect(h.refreshAdapter.callCount, 0);
    expect(h.retryAdapter.callCount, 0);
    verifyNever(() => store.clear());
    verifyNever(
      () => store.save(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
        userId: any(named: 'userId'),
      ),
    );
  });

  test(
    'refreshes token on 401 and retries the original request once',
    () async {
      final h = buildHarness(
        // Original request is rejected with 401 exactly once.
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        // The retry (with the new bearer) succeeds.
        retryResponder: (_) => _json({'data': 'fresh'}, 200),
        // The refresh endpoint rotates the token pair.
        refreshResponder: (_) => _json({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }, 200),
      );

      final res = await h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access'));

      // Resolved with the retried success, not the initial 401.
      expect(res.statusCode, 200);
      expect(res.data, {'data': 'fresh'});

      // Refresh ran exactly once, against the refresh path.
      expect(h.refreshAdapter.callCount, 1);
      expect(h.refreshAdapter.requests.single.path, '/v1/auth/refresh');

      // The original request was retried exactly once, carrying the NEW bearer.
      expect(h.retryAdapter.callCount, 1);
      final retried = h.retryAdapter.requests.single;
      expect(retried.path, '/v1/jeeb/wallet');
      expect(retried.headers['Authorization'], 'Bearer new-access');

      // The rotated pair was persisted, preserving userId.
      verify(
        () => store.save(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          userId: 'user-1',
        ),
      ).called(1);

      // No logout on a successful refresh.
      expect(h.logoutCalls, isEmpty);
      verifyNever(() => store.clear());
    },
  );

  test('terminal 401 after a successful refresh logs out once', () async {
    final h = buildHarness(
      mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
      retryResponder: (_) => _json({'error': 'still unauthorized'}, 401),
      refreshResponder: (_) => _json({
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      }, 200),
    );

    await expectLater(
      h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
      throwsA(isA<DioException>()),
    );

    verify(() => store.clear()).called(1);
    expect(h.logoutCalls, ['logout']);
  });

  test(
    'logs out on failed refresh and does not retry (no infinite loop)',
    () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        // The refresh itself returns 401 → Dio throws → interceptor logs out.
        refreshResponder: (_) => _json({'error': 'expired'}, 401),
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Refresh was attempted once and failed; the original request was NEVER
      expect(h.refreshAdapter.callCount, 1);
      expect(h.retryAdapter.callCount, 0);

      // Session was cleared and the logout callback fired exactly once.
      verify(() => store.clear()).called(1);
      expect(h.logoutCalls, ['logout']);

      // Nothing was persisted on a failed refresh.
      verifyNever(
        () => store.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        ),
      );
    },
  );

  test('does not refresh on a 401 from the refresh endpoint itself', () async {
    final h = buildHarness(
      // A 401 returned directly on the refresh path must pass straight through.
      mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
      retryResponder: (_) => _json({'should': 'never-run'}, 200),
      refreshResponder: (_) => _json({'should': 'never-run'}, 200),
    );

    await expectLater(
      h.mainDio.post<dynamic>(
          '/v1/auth/refresh',
          data: {'refreshToken': 'x'},
          options: _asSession('any-token'),
        ),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    // Guard 1/2: a 401 on the refresh path never re-enters refresh logic.
    expect(h.refreshAdapter.callCount, 0);
    expect(h.retryAdapter.callCount, 0);
    // It also must not trigger a logout — that is the caller's concern.
    verifyNever(() => store.clear());
    expect(h.logoutCalls, isEmpty);
  });

  test(
    'already-retried 401 is passed through without a second refresh',
    () async {
      // Guard 3: a request already tagged with the retried flag must not refresh
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      await expectLater(
        h.mainDio.get<dynamic>(
          '/v1/jeeb/wallet',
          options: _asSession('stale-access', extra: {'jeeb.auth.retried': true}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(h.refreshAdapter.callCount, 0);
      expect(h.retryAdapter.callCount, 0);
      verifyNever(() => store.clear());
    },
  );

  // R2-9: the /v1 flag-day guard on the refresh path. `/auth/refresh` is the
  // legacy AuthController over the same ITokenService, so the twin is real.
  group('refresh-path unversioned fallback (DioClient wiring)', () {
    test(
      'records the initial 401, both refresh paths, and successful replay',
      () async {
        final sink = _ObsSink();
        Observability.instance
          ..sink = sink
          ..setSessionForTest('auth-wire-session');
        ObservabilityConfig.instance.enabled = true;
        final h = buildHarness(
          mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
          retryResponder: (_) => _json({'data': 'fresh'}, 200),
          refreshResponder: (options) => options.path == '/v1/auth/refresh'
              ? _json({'error': 'not found'}, 404)
              : _json({
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                }, 200),
          refreshFallback: true,
          observeWireAttempts: true,
        );

        final response = await h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access'));

        expect(response.statusCode, 200);
        final apiEvents = sink.events.whereType<ObsApiEvent>().toList();
        expect(apiEvents.map((event) => event.path), <String>[
          '/v1/jeeb/wallet',
          '/v1/auth/refresh',
          '/auth/refresh',
          '/v1/jeeb/wallet',
        ]);
        expect(apiEvents.map((event) => event.statusCode), <int>[
          401,
          404,
          200,
          200,
        ]);
        for (final event in apiEvents.where(
          (item) => item.path.contains('auth/refresh'),
        )) {
          expect(event.requestHeaders, isEmpty);
          expect(event.responseHeaders, isEmpty);
          expect(event.requestBody, isNull);
          expect(event.responseBody, isNull);
        }
      },
      skip: kObsCompiledIn
          ? false
          : 'requires JEEB_DEVTOOL_ENABLED and JEEB_OBS_OVERLAY',
    );

    test(
      'a 404 on /v1/auth/refresh rotates via the unversioned twin',
      () async {
        final h = buildHarness(
          mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
          retryResponder: (_) => _json({'data': 'fresh'}, 200),
          refreshResponder: (options) => options.path == '/v1/auth/refresh'
              ? _json({'error': 'not found'}, 404)
              : _json({
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                }, 200),
          refreshFallback: true,
        );

        final res = await h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access'));

        expect(res.statusCode, 200);
        expect(res.data, {'data': 'fresh'});

        // Versioned first, then the twin — exactly two refresh calls, no more.
        expect(h.refreshAdapter.paths, ['/v1/auth/refresh', '/auth/refresh']);

        expect(h.retryAdapter.callCount, 1);
        expect(
          h.retryAdapter.requests.single.headers['Authorization'],
          'Bearer new-access',
        );
        verify(
          () => store.save(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
            userId: 'user-1',
          ),
        ).called(1);
        expect(h.logoutCalls, isEmpty);
        verifyNever(() => store.clear());
      },
    );

    test('when neither refresh path exists, tokens survive (skew)', () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'error': 'not found'}, 404),
        refreshFallback: true,
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // A 404 is deployment skew, not an auth verdict: both twins were tried,
      // the original 401 surfaces, and the session is NOT destroyed.
      expect(h.refreshAdapter.paths, ['/v1/auth/refresh', '/auth/refresh']);
      expect(h.retryAdapter.callCount, 0);
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
    });

    test('a 401 from refresh is never replayed unversioned', () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'error': 'expired'}, 401),
        refreshFallback: true,
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(isA<DioException>()),
      );

      // Inert on every status the live gateway actually returns today.
      expect(h.refreshAdapter.paths, ['/v1/auth/refresh']);
      expect(h.retryAdapter.callCount, 0);
      verify(() => store.clear()).called(1);
      expect(h.logoutCalls, ['logout']);
    });
  });

  group('terminal vs transient refresh failure', () {
    test('a network failure during refresh keeps tokens: NO logout', () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // An offline device must never lose its session over a blip.
      expect(h.refreshAdapter.callCount, 1);
      expect(h.retryAdapter.callCount, 0);
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
    });

    test('a 503 from refresh keeps tokens: NO logout', () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'error': 'unavailable'}, 503),
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(isA<DioException>()),
      );

      // A gateway outage is not a verdict on the session.
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
    });
  });

  group('single-flight and generation check', () {
    test('a rotated store token skips refresh and retries directly', () async {
      when(() => store.accessToken).thenAnswer((_) async => 'rotated-access');
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'data': 'fresh'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      final res = await h.mainDio.get<dynamic>(
        '/v1/jeeb/wallet',
        options: _asSession('stale-access'),
      );

      expect(res.statusCode, 200);
      expect(h.refreshAdapter.callCount, 0);
      expect(h.retryAdapter.callCount, 1);
      expect(
        h.retryAdapter.requests.single.headers['Authorization'],
        'Bearer rotated-access',
      );
      verifyNever(() => store.clear());
    });

    test('ten concurrent 401s trigger exactly ONE refresh', () async {
      var access = 'stale-access';
      var refresh = 'old-refresh';
      when(() => store.accessToken).thenAnswer((_) async => access);
      when(() => store.refreshToken).thenAnswer((_) async => refresh);
      when(
        () => store.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((invocation) async {
        access = invocation.namedArguments[#accessToken] as String;
        refresh = invocation.namedArguments[#refreshToken] as String;
      });

      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'ok': true}, 200),
        refreshResponder: (_) => _json({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }, 200),
      );

      final results = await Future.wait(
        List.generate(
          10,
          (i) => h.mainDio.get<dynamic>(
            '/v1/jeeb/wallet/$i',
            options: _asSession('stale-access'),
          ),
        ),
      );

      expect(results.map((r) => r.statusCode), everyElement(200));
      // The leader refreshes; the nine followers see the rotated generation
      // in storage and go straight to retry.
      expect(h.refreshAdapter.callCount, 1);
      expect(h.retryAdapter.callCount, 10);
      for (final retried in h.retryAdapter.requests) {
        expect(retried.headers['Authorization'], 'Bearer new-access');
      }
      expect(h.logoutCalls, isEmpty);
    });
  });

  group('proactive refresh before expiry', () {
    test('a bearer expiring inside the window is rotated pre-send', () async {
      final nearExpiry = _jwtWithExp(
        DateTime.now().add(const Duration(seconds: 30)),
      );
      when(() => store.accessToken).thenAnswer((_) async => nearExpiry);
      final h = buildHarness(
        mainResponder: (_) => _json({'ok': true}, 200),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }, 200),
      );

      final res = await h.mainDio.get<dynamic>(
        '/v1/jeeb/wallet',
        options: _asSession(nearExpiry),
      );

      expect(res.statusCode, 200);
      expect(h.refreshAdapter.callCount, 1);
      // The wire never saw the dying token.
      expect(
        h.mainAdapter.requests.single.headers['Authorization'],
        'Bearer new-access',
      );
      expect(h.retryAdapter.callCount, 0);
    });

    test('a far-expiry bearer goes out unchanged, no refresh', () async {
      final healthy = _jwtWithExp(DateTime.now().add(const Duration(hours: 1)));
      final h = buildHarness(
        mainResponder: (_) => _json({'ok': true}, 200),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      final res = await h.mainDio.get<dynamic>(
        '/v1/jeeb/wallet',
        options: _asSession(healthy),
      );

      expect(res.statusCode, 200);
      expect(h.refreshAdapter.callCount, 0);
      expect(
        h.mainAdapter.requests.single.headers['Authorization'],
        'Bearer $healthy',
      );
    });

    test('an opaque (non-JWT) bearer is never proactively refreshed', () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'ok': true}, 200),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      final res = await h.mainDio.get<dynamic>(
        '/v1/jeeb/wallet',
        options: _asSession('mock-jwt-access-user-client-001'),
      );

      expect(res.statusCode, 200);
      expect(h.refreshAdapter.callCount, 0);
    });

    test('an empty refresh token on the proactive lane never logs out',
        () async {
      // Super-login/seam sessions store refreshToken '' — while the access
      // token is still valid, a pre-send optimization must not kill them.
      final nearExpiry = _jwtWithExp(
        DateTime.now().add(const Duration(seconds: 30)),
      );
      when(() => store.accessToken).thenAnswer((_) async => nearExpiry);
      when(() => store.refreshToken).thenAnswer((_) async => '');
      final h = buildHarness(
        mainResponder: (_) => _json({'ok': true}, 200),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      final res = await h.mainDio.get<dynamic>(
        '/v1/jeeb/wallet',
        options: _asSession(nearExpiry),
      );

      expect(res.statusCode, 200);
      expect(h.refreshAdapter.callCount, 0);
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
      // The still-valid bearer went out unchanged.
      expect(
        h.mainAdapter.requests.single.headers['Authorization'],
        'Bearer $nearExpiry',
      );
    });
  });

  group('review-gate regressions', () {
    test('a caller-pinned foreign bearer passes through both lanes untouched',
        () async {
      when(() => store.accessToken).thenAnswer((_) async => 'session-access');
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      // Act-as/devtool style: explicit Authorization, NO session flag.
      await expectLater(
        h.mainDio.get<dynamic>(
          '/v1/deliveries/d-1/otp/verify',
          options: Options(headers: {'Authorization': 'Bearer act-as-token'}),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Never retried as the session user, never refreshed, session intact.
      expect(h.refreshAdapter.callCount, 0);
      expect(h.retryAdapter.callCount, 0);
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
      expect(
        h.mainAdapter.requests.single.headers['Authorization'],
        'Bearer act-as-token',
      );
    });

    test('a FormData 401 refreshes the session but never replays the body',
        () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }, 200),
      );

      await expectLater(
        h.mainDio.post<dynamic>(
          '/v1/transcribe',
          data: FormData.fromMap({'note': 'x'}),
          options: _asSession('stale-access'),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // The session healed for future requests; the consumed multipart body
      // was not re-sent (it would throw 'FormData has already been finalized').
      expect(h.refreshAdapter.callCount, 1);
      expect(h.retryAdapter.callCount, 0);
      verify(
        () => store.save(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          userId: 'user-1',
        ),
      ).called(1);
      expect(h.logoutCalls, isEmpty);
    });

    test('a 429 from refresh is transient: tokens survive', () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'error': 'slow down'}, 429),
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(isA<DioException>()),
      );

      // Rate limiting is not an auth verdict.
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
    });

    test('reactive lane with no refresh token logs out cleanly, no refresh',
        () async {
      when(() => store.refreshToken).thenAnswer((_) async => '');
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      await expectLater(
        h.mainDio.get<dynamic>('/v1/jeeb/wallet', options: _asSession('stale-access')),
        throwsA(isA<DioException>()),
      );

      expect(h.refreshAdapter.callCount, 0);
      verify(() => store.clear()).called(1);
      expect(h.logoutCalls, ['logout']);
    });

    test('transient failures arm a cooldown: one attempt per window',
        () async {
      var now = DateTime.utc(2026, 9, 3, 12);
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        clock: () => now,
      );

      Future<void> fire() => expectLater(
            h.mainDio.get<dynamic>(
              '/v1/jeeb/wallet',
              options: _asSession('stale-access'),
            ),
            throwsA(isA<DioException>()),
          );

      await fire();
      expect(h.refreshAdapter.callCount, 1);

      // Second request inside the cooldown: NO second 15s stall.
      await fire();
      expect(h.refreshAdapter.callCount, 1);

      // After the window a fresh attempt is allowed again.
      now = now.add(const Duration(seconds: 21));
      await fire();
      expect(h.refreshAdapter.callCount, 2);
      // Never a logout on transient failures.
      verifyNever(() => store.clear());
      expect(h.logoutCalls, isEmpty);
    });
  });

  group('NET-02: an unreadable token store is classified, not terminal', () {
    test('BearerAuthInterceptor marks the request instead of swallowing',
        () async {
      when(() => store.accessToken).thenThrow(Exception('keystore locked'));
      final adapter = _ScriptedAdapter((_) => _json({'ok': true}, 200));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'))
        ..httpClientAdapter = adapter
        ..interceptors.add(BearerAuthInterceptor(store));

      await dio.get<dynamic>('/v1/jeeb/wallet');

      final sent = adapter.requests.single;
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.extra[BearerAuthInterceptor.storeUnavailableFlag], isTrue);
      expect(sent.extra[TokenRefreshInterceptor.sessionBearerFlag], isNull);
    });

    test('a 401 on a store-unavailable request keeps the session intact',
        () async {
      final reasons = <AuthLossReason>[];
      final sub = AuthLossSignals.instance.stream.listen(reasons.add);
      addTearDown(sub.cancel);

      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );

      await expectLater(
        h.mainDio.get<dynamic>(
          '/v1/jeeb/wallet',
          options: Options(
            extra: <String, dynamic>{
              BearerAuthInterceptor.storeUnavailableFlag: true,
            },
          ),
        ),
        throwsA(isA<DioException>()),
      );

      expect(h.refreshAdapter.callCount, 0, reason: 'refresh cannot help');
      expect(h.retryAdapter.callCount, 0);
      // A locked keychain must never destroy a session the gateway still honours.
      expect(h.logoutCalls, isEmpty);
      verifyNever(() => store.clear());
      expect(reasons, isEmpty);
    });

    test('the classified failure names the store, not an expired session',
        () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'should': 'never-run'}, 200),
      );
      h.mainDio.interceptors.add(const AppFailureInterceptor());

      Object? classified;
      try {
        await h.mainDio.get<dynamic>(
          '/v1/jeeb/wallet',
          options: Options(
            extra: <String, dynamic>{
              BearerAuthInterceptor.storeUnavailableFlag: true,
            },
          ),
        );
      } on DioException catch (e) {
        classified = e.error;
      }
      expect(classified, isA<UnauthorizedFailure>());
      expect((classified! as UnauthorizedFailure).storeUnavailable, isTrue);
      expect((classified as UnauthorizedFailure).recovering, isFalse);
    });
  });

  group('NET-17: a 401 inside the cooldown is marked as recovering', () {
    test('the second 401 carries the flag and classifies as recovering',
        () async {
      var now = DateTime.utc(2026, 9, 3, 12);
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        clock: () => now,
      );
      h.mainDio.interceptors.add(const AppFailureInterceptor());

      Future<UnauthorizedFailure> fire() async {
        try {
          await h.mainDio.get<dynamic>(
            '/v1/jeeb/wallet',
            options: _asSession('stale-access'),
          );
        } on DioException catch (e) {
          return e.error! as UnauthorizedFailure;
        }
        fail('the 401 must reach the caller');
      }

      // The refresh could not be completed, so the session is unverified —
      // not rejected. Every 401 in that state says "recovering".
      final first = await fire();
      expect(first.recovering, isTrue);

      final second = await fire();
      expect(second.recovering, isTrue);
      expect(h.refreshAdapter.callCount, 1, reason: 'no second stall');

      now = now.add(const Duration(seconds: 21));
      await fire();
      expect(h.refreshAdapter.callCount, 2, reason: 'the window reopened');
      expect(h.logoutCalls, isEmpty, reason: 'transient never destroys tokens');
    });

    test('a gateway-rejected refresh is terminal, never "recovering"',
        () async {
      final h = buildHarness(
        mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
        retryResponder: (_) => _json({'should': 'never-run'}, 200),
        refreshResponder: (_) => _json({'error': 'invalid_grant'}, 401),
      );
      h.mainDio.interceptors.add(const AppFailureInterceptor());

      Object? classified;
      try {
        await h.mainDio.get<dynamic>(
          '/v1/jeeb/wallet',
          options: _asSession('stale-access'),
        );
      } on DioException catch (e) {
        classified = e.error;
      }
      expect((classified! as UnauthorizedFailure).recovering, isFalse);
      expect(h.logoutCalls, ['logout']);
    });
  });
}
