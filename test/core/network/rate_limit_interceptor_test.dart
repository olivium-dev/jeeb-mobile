import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/app_failure_mapper.dart';
import 'package:jeeb_mobile/core/network/rate_limit_interceptor.dart';

/// Lowest-level Dio adapter that returns a scripted [ResponseBody] per request
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

ResponseBody _body(int status, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    });

void main() {
  late DateTime now;
  DateTime clock() => now;

  Dio buildDio(_ScriptedAdapter adapter) {
    now = DateTime.utc(2026, 7, 13, 12);
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'));
    dio.interceptors.add(
      RateLimitInterceptor(
        clock: clock,
        maxJitter: Duration.zero, // deterministic window in tests
      ),
    );
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('a 429 with Retry-After suppresses subsequent GET polls until it clears',
      () async {
    var wireHits = 0;
    final adapter = _ScriptedAdapter((opts) {
      wireHits++;
      return wireHits == 1
          ? _body(429, headers: {'retry-after': ['30']})
          : _body(200);
    });
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      dio.get<dynamic>('/deliveries/d-1'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1, reason: 'suppressed reads must not hit the wire');

    now = now.add(const Duration(seconds: 31));
    final ok = await dio.get<dynamic>('/deliveries');
    expect(ok.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test(
      'a concurrent 2xx does NOT wipe an open Retry-After window '
      '(BUG-C fan-out storm regression)', () async {
    final adapter = _ScriptedAdapter((opts) {
      if (opts.path == '/v1/feed/429') {
        return _body(429, headers: {'retry-after': ['30']});
      }
      return _body(200); // the concurrent success and the later poll
    });
    final dio = buildDio(adapter);

    final f429 = dio.get<dynamic>('/v1/feed/429');
    final f200 = dio.get<dynamic>('/v1/feed/ok');
    await expectLater(f429, throwsA(isA<DioException>()));
    final ok = await f200;
    expect(ok.statusCode, 200);
    expect(adapter.callCount, 2, reason: 'both concurrent reads hit the wire');

    await expectLater(
      dio.get<dynamic>('/v1/feed/poll'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 2,
        reason: 'window still open after a concurrent success — poll suppressed');

    now = now.add(const Duration(seconds: 31));
    final resumed = await dio.get<dynamic>('/v1/feed/poll');
    expect(resumed.statusCode, 200);
    expect(adapter.callCount, 3);
  });

  test('writes (POST) are NEVER suppressed by the back-off window', () async {
    final adapter = _ScriptedAdapter(
      (opts) => opts.method == 'GET' && opts.path == '/requests'
          ? _body(429, headers: {'retry-after': ['60']})
          : _body(200),
    );
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/requests'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    final res = await dio.post<dynamic>('/v1/offers/accept', data: {'id': 'o-1'});
    expect(res.statusCode, 200);
    expect(adapter.callCount, 2, reason: 'the POST must reach the wire');
  });

  test('an absent Retry-After header still opens a default back-off window',
      () async {
    final adapter = _ScriptedAdapter(
      (opts) => opts.path == '/requests' ? _body(429) : _body(200),
    );
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/requests'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      dio.get<dynamic>('/requests'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('Retry-After as an HTTP-date is honored', () async {
    final retryDate = httpDateOf(now.add(const Duration(seconds: 20)));
    var wireHits = 0;
    final adapter = _ScriptedAdapter((opts) {
      wireHits++;
      return wireHits == 1
          ? _body(429, headers: {'retry-after': [retryDate]})
          : _body(200);
    });
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    now = now.add(const Duration(seconds: 10));
    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    now = now.add(const Duration(seconds: 15));
    final ok = await dio.get<dynamic>('/deliveries');
    expect(ok.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  group('NET-04: the window is scoped and the rejection is typed', () {
    test('a throttled prefix cannot blank an unrelated one', () async {
      final adapter = _ScriptedAdapter(
        (opts) => opts.path.startsWith('/v1/offers')
            ? _body(429, headers: {'retry-after': ['30']})
            : _body(200),
      );
      final dio = buildDio(adapter);

      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(isA<DioException>()),
      );
      // Same prefix: suppressed.
      await expectLater(
        dio.get<dynamic>('/v1/offers', queryParameters: {'requestId': 'r-1'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 1);

      // Different prefix: the wallet must still load during an offers storm.
      final wallet = await dio.get<dynamic>('/v1/wallet/balance');
      expect(wallet.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('a suppressed read carries RateLimitSuppression, never prose',
        () async {
      final adapter = _ScriptedAdapter(
        (_) => _body(429, headers: {'retry-after': ['30']}),
      );
      final dio = buildDio(adapter);

      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(isA<DioException>()),
      );

      Object? captured;
      try {
        await dio.get<dynamic>('/v1/offers');
      } on DioException catch (e) {
        captured = e.error;
      }
      expect(captured, isA<RateLimitSuppression>());
      final sentinel = captured! as RateLimitSuppression;
      expect(sentinel.scope, '/offers');
      expect(sentinel.retryAfter, isNotNull);
      // No English sentence anywhere in the transport payload.
      expect(sentinel.toString(), isNot(contains('Retry-After honored')));
    });

    test('the sentinel maps to a locally-suppressed rate limit', () async {
      final adapter = _ScriptedAdapter(
        (_) => _body(429, headers: {'retry-after': ['30']}),
      );
      final dio = buildDio(adapter);

      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(isA<DioException>()),
      );
      DioException? suppressed;
      try {
        await dio.get<dynamic>('/v1/offers');
      } on DioException catch (e) {
        suppressed = e;
      }
      final failure = mapDioException(suppressed!);
      expect(failure, isA<RateLimitedFailure>());
      expect((failure as RateLimitedFailure).localSuppression, isTrue);
      expect(failure.retryAfter, isNotNull);
    });

    test('scopeOf keeps the resource, dropping version, host and query', () {
      expect(RateLimitInterceptor.scopeOf('/v1/offers/o-1?x=1'), '/offers');
      expect(RateLimitInterceptor.scopeOf('/api/users/me'), '/users');
      expect(RateLimitInterceptor.scopeOf('/deliveries/d-1'), '/deliveries');
      expect(RateLimitInterceptor.scopeOf('/deliveries'), '/deliveries');
      expect(RateLimitInterceptor.scopeOf('/'), '/');
      // A versioned route and its unversioned twin are one resource.
      expect(RateLimitInterceptor.scopeOf('/offers'), '/offers');
      expect(
        RateLimitInterceptor.scopeOf('https://gw.example/v1/offers/o-1'),
        '/offers',
      );
    });

    test('a path rewritten after this interceptor still matches its window',
        () async {
      final adapter = _ScriptedAdapter(
        (_) => _body(429, headers: {'retry-after': ['30']}),
      );
      final dio = buildDio(adapter)
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              options.path = '/offer-service${options.path}';
              handler.next(options);
            },
          ),
        );

      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(isA<DioException>()),
      );
      // The window was keyed by the send-time scope, not the rewritten path.
      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(
          isA<DioException>().having(
            (DioException e) => e.error,
            'error',
            isA<RateLimitSuppression>(),
          ),
        ),
      );
      expect(adapter.callCount, 1);
    });

    test('a local rejection still reaches the AppFailure interceptor',
        () async {
      final adapter = _ScriptedAdapter(
        (_) => _body(429, headers: {'retry-after': ['30']}),
      );
      final dio = buildDio(adapter)
        ..interceptors.add(const AppFailureInterceptor());

      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(isA<DioException>()),
      );
      Object? classified;
      try {
        await dio.get<dynamic>('/v1/offers');
      } on DioException catch (e) {
        classified = e.error;
      }
      expect(classified, isA<RateLimitedFailure>());
      expect((classified! as RateLimitedFailure).localSuppression, isTrue);
    });

    test('NET-20: an elapsed window clears its scope on the next read',
        () async {
      var hits = 0;
      final adapter = _ScriptedAdapter((_) {
        hits++;
        return hits == 1
            ? _body(429, headers: {'retry-after': ['30']})
            : _body(200);
      });
      final dio = buildDio(adapter);

      await expectLater(
        dio.get<dynamic>('/v1/offers'),
        throwsA(isA<DioException>()),
      );
      expect(dio.interceptors.whereType<RateLimitInterceptor>().single
          .isPathSuppressed('/v1/offers'), isTrue);

      now = now.add(const Duration(seconds: 31));
      final ok = await dio.get<dynamic>('/v1/offers');
      expect(ok.statusCode, 200);
      expect(dio.interceptors.whereType<RateLimitInterceptor>().single
          .isPathSuppressed('/v1/offers'), isFalse);
    });
  });
}

/// Format a UTC [DateTime] as an IMF-fixdate (RFC 7231) HTTP header value.
String httpDateOf(DateTime dt) {
  const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${wk[u.weekday - 1]}, ${two(u.day)} ${mo[u.month - 1]} ${u.year} '
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)} GMT';
}
