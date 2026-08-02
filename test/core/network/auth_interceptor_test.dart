import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_interceptor.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';

/// Lowest-level Dio adapter that returns scripted [ResponseBody]s per request,
/// so the token-refresh flow can be exercised end-to-end without a real socket.
/// Records every [RequestOptions] it sees for post-hoc assertions.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MockTokenStore extends Mock implements AuthTokenStore {}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late _MockTokenStore store;

  // Defaults used by the happy-refresh path; individual tests override.
  setUp(() {
    store = _MockTokenStore();
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

  /// Builds the three-Dio harness the interceptor is designed around:
  ///   - [mainDio] carries the [TokenRefreshInterceptor] and serves the
  ({
    Dio mainDio,
    _ScriptedAdapter mainAdapter,
    _ScriptedAdapter retryAdapter,
    _ScriptedAdapter refreshAdapter,
    List<String> logoutCalls,
  }) buildHarness({
    required ResponseBody Function(RequestOptions) mainResponder,
    required ResponseBody Function(RequestOptions) retryResponder,
    required ResponseBody Function(RequestOptions) refreshResponder,
  }) {
    final mainAdapter = _ScriptedAdapter(mainResponder);
    final retryAdapter = _ScriptedAdapter(retryResponder);
    final refreshAdapter = _ScriptedAdapter(refreshResponder);
    final logoutCalls = <String>[];

    final retryClient = Dio()..httpClientAdapter = retryAdapter;
    final refreshClient = Dio()..httpClientAdapter = refreshAdapter;

    final mainDio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'))
      ..httpClientAdapter = mainAdapter
      ..interceptors.add(
        TokenRefreshInterceptor(
          retryClient: retryClient,
          refreshClient: refreshClient,
          tokenStore: store,
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

    final res = await h.mainDio.get<dynamic>('/v1/jeeb/wallet');

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

  test('refreshes token on 401 and retries the original request once',
      () async {
    final h = buildHarness(
      // Original request is rejected with 401 exactly once.
      mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
      // The retry (with the new bearer) succeeds.
      retryResponder: (_) => _json({'data': 'fresh'}, 200),
      // The refresh endpoint rotates the token pair.
      refreshResponder: (_) => _json(
        {'accessToken': 'new-access', 'refreshToken': 'new-refresh'},
        200,
      ),
    );

    final res = await h.mainDio.get<dynamic>('/v1/jeeb/wallet');

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
  });

  test('logs out on failed refresh and does not retry (no infinite loop)',
      () async {
    final h = buildHarness(
      mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
      retryResponder: (_) => _json({'should': 'never-run'}, 200),
      // The refresh itself returns 401 → Dio throws → interceptor logs out.
      refreshResponder: (_) => _json({'error': 'expired'}, 401),
    );

    await expectLater(
      h.mainDio.get<dynamic>('/v1/jeeb/wallet'),
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
  });

  test('does not refresh on a 401 from the refresh endpoint itself', () async {
    final h = buildHarness(
      // A 401 returned directly on the refresh path must pass straight through.
      mainResponder: (_) => _json({'error': 'unauthorized'}, 401),
      retryResponder: (_) => _json({'should': 'never-run'}, 200),
      refreshResponder: (_) => _json({'should': 'never-run'}, 200),
    );

    await expectLater(
      h.mainDio.post<dynamic>('/v1/auth/refresh', data: {'refreshToken': 'x'}),
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

  test('already-retried 401 is passed through without a second refresh',
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
        options: Options(extra: {'jeeb.auth.retried': true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(h.refreshAdapter.callCount, 0);
    expect(h.retryAdapter.callCount, 0);
    verifyNever(() => store.clear());
  });
}
