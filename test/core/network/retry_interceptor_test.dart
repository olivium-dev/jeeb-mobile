// NET-06: a bounded transient retry that can never duplicate a side effect.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/network/rate_limit_interceptor.dart';
import 'package:jeeb_mobile/core/network/retry_interceptor.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options, int hit) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(int status) => ResponseBody.fromString('{}', status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });

void main() {
  late List<Duration> waited;

  /// One client whose retries replay through a bare twin sharing the adapter,
  /// exactly as `MockGatewayClient.createDio` wires it.
  Dio buildDio(
    _ScriptedAdapter adapter, {
    RateLimitInterceptor? rateLimiter,
    int maxAttempts = 2,
  }) {
    final retryClient = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = adapter;
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = adapter;
    if (rateLimiter != null) dio.interceptors.add(rateLimiter);
    dio.interceptors.add(
      RetryInterceptor(
        retryClient: retryClient,
        rateLimiter: rateLimiter,
        maxAttempts: maxAttempts,
        maxJitter: Duration.zero,
        delay: (d) async => waited.add(d),
      ),
    );
    return dio;
  }

  setUp(() => waited = <Duration>[]);

  test('a GET that fails twice and then succeeds is replayed to success',
      () async {
    final adapter = _ScriptedAdapter(
      (_, hit) => hit < 3 ? _body(503) : _body(200),
    );
    final response = await buildDio(adapter).get<dynamic>('/v1/offers');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 3, reason: 'original plus two replays');
  });

  test('the attempt budget is hard: a permanently down route gives up', () async {
    final adapter = _ScriptedAdapter((_, _) => _body(503));

    await expectLater(
      buildDio(adapter).get<dynamic>('/v1/offers'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 3);
  });

  test('back-off grows exponentially between attempts', () async {
    final adapter = _ScriptedAdapter((_, _) => _body(503));
    await expectLater(
      buildDio(adapter).get<dynamic>('/v1/offers'),
      throwsA(isA<DioException>()),
    );

    expect(waited, <Duration>[
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 600),
    ]);
  });

  test('a 500 is NOT retried — only the unavailable trio is transient',
      () async {
    final adapter = _ScriptedAdapter((_, _) => _body(500));
    await expectLater(
      buildDio(adapter).get<dynamic>('/v1/offers'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('a 409 is never retried', () async {
    final adapter = _ScriptedAdapter((_, _) => _body(409));
    await expectLater(
      buildDio(adapter).get<dynamic>('/v1/offers'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('a bare POST is never replayed: it may have created something',
      () async {
    final adapter = _ScriptedAdapter((_, _) => _body(503));
    await expectLater(
      buildDio(adapter).post<dynamic>('/v1/requests', data: <String, int>{}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('a POST carrying an Idempotency-Key IS replayed', () async {
    final adapter = _ScriptedAdapter(
      (_, hit) => hit < 2 ? _body(503) : _body(200),
    );
    final response = await buildDio(adapter).post<dynamic>(
      '/v1/requests',
      data: <String, int>{},
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': 'op-1'},
      ),
    );

    expect(response.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test('FormData is one-shot even with an idempotency key', () async {
    final adapter = _ScriptedAdapter((_, _) => _body(503));
    await expectLater(
      buildDio(adapter).post<dynamic>(
        '/v1/kyc/documents',
        data: FormData.fromMap(<String, dynamic>{'k': 'v'}),
        options: Options(
          headers: <String, dynamic>{'Idempotency-Key': 'op-1'},
        ),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('an open back-off window on the same prefix suppresses the retry',
      () async {
    final now = DateTime.utc(2026, 7, 13, 12);
    final limiter = RateLimitInterceptor(
      clock: () => now,
      maxJitter: Duration.zero,
    );
    // The 429 opens the window; the follow-up 503 must not be replayed into it.
    final adapter = _ScriptedAdapter(
      (_, hit) => hit == 1
          ? ResponseBody.fromString('{}', 429, headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              'retry-after': <String>['30'],
            })
          : _body(503),
    );
    final dio = buildDio(adapter, rateLimiter: limiter);

    await expectLater(
      dio.post<dynamic>(
        '/v1/offers',
        data: <String, int>{},
        options: Options(headers: <String, dynamic>{'Idempotency-Key': 'k'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    await expectLater(
      dio.post<dynamic>(
        '/v1/offers',
        data: <String, int>{},
        options: Options(headers: <String, dynamic>{'Idempotency-Key': 'k'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 2, reason: 'the 503 reached the wire once, and '
        'was not replayed while the window was open');
    expect(waited, isEmpty);
  });

  test('a cancelled request is never retried', () {
    expect(
      RetryInterceptor.isTransient(
        DioException(
          requestOptions: RequestOptions(path: '/v1/offers'),
          type: DioExceptionType.cancel,
        ),
      ),
      isFalse,
    );
  });

  test('read and send timeouts are not transient: the request arrived', () {
    for (final DioExceptionType type in <DioExceptionType>[
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.transformTimeout,
    ]) {
      expect(
        RetryInterceptor.isTransient(
          DioException(
            requestOptions: RequestOptions(path: '/v1/offers'),
            type: type,
          ),
        ),
        isFalse,
        reason: '$type would triple a 15s wait the caller already paid',
      );
    }
  });

  test('a connection error is transient only while reachability says online',
      () async {
    await NetworkReachabilitySignals.debugReset();
    addTearDown(NetworkReachabilitySignals.debugReset);
    final DioException err = DioException(
      requestOptions: RequestOptions(path: '/v1/offers'),
      type: DioExceptionType.connectionError,
    );

    NetworkReachabilitySignals.instance.debugObserve(online: true);
    expect(RetryInterceptor.isTransient(err), isTrue);

    NetworkReachabilitySignals.instance.debugObserve(online: false);
    expect(RetryInterceptor.isTransient(err), isFalse);
  });
}
