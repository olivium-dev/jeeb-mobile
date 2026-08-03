import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_dio_interceptor.dart';

Map<String, dynamic> decodeLine(String line) =>
    jsonDecode(line.substring(Diag.prefix.length + 1)) as Map<String, dynamic>;

/// A fake bearer JWT used purely to prove it never reaches a log line.
const _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

/// Stub adapter: returns a configured status, or throws to simulate a
/// transport failure — so the interceptor runs inside Dio's real pipeline.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.status, this.throwType});

  final int? status;
  final DioExceptionType? throwType;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final t = throwType;
    if (t != null) throw DioException(requestOptions: options, type: t);
    return ResponseBody.fromString('{}', status ?? 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

/// Adapter that signals when the request pipeline reached it and holds the
/// response until released — for proving capture-at-request-time semantics.
class _GatedAdapter implements HttpClientAdapter {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await release.future;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

Dio _dioWith(_StubAdapter adapter) => Dio(BaseOptions(baseUrl: 'https://x'))
  ..httpClientAdapter = adapter
  ..interceptors.add(const DiagDioInterceptor());

Options _authHeaders() => Options(headers: <String, dynamic>{
      'Authorization': 'Bearer $_fakeJwt',
      'x-correlation-id': 'corr-42',
    });

void main() {
  late List<String> lines;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
  });

  tearDown(Diag.resetForTest);

  test('REDACTION: an Authorization/Bearer JWT NEVER appears in the api line',
      () async {
    final dio = _dioWith(_StubAdapter(status: 201));
    await dio.get<dynamic>('/v1/requests?access_token=$_fakeJwt',
        options: _authHeaders());

    expect(lines, hasLength(1));
    final line = lines.single;
    expect(line, isNot(contains(_fakeJwt)));
    expect(line.toLowerCase(), isNot(contains('authorization')));
    expect(line, isNot(contains('Bearer')));
  });

  test('the api line DOES carry path (query-stripped), status, ms and reqId',
      () async {
    final dio = _dioWith(_StubAdapter(status: 201));
    await dio.get<dynamic>('/v1/requests?access_token=$_fakeJwt',
        options: _authHeaders());

    final record = decodeLine(lines.single);
    expect(record['t'], 'api');
    expect(record['m'], 'GET');
    expect(record['path'], '/v1/requests');
    expect(record['status'], 201);
    expect(record['ms'], isA<int>());
    expect(record['reqId'], 'corr-42');
  });

  test('a 4xx surfaces via the error path with the status code, no leak',
      () async {
    final dio = _dioWith(_StubAdapter(status: 409));
    await expectLater(
      dio.get<dynamic>('/v1/requests', options: _authHeaders()),
      throwsA(isA<DioException>()),
    );

    final record = decodeLine(lines.single);
    expect(record['status'], 409);
    expect(record['path'], '/v1/requests');
    expect(lines.single, isNot(contains(_fakeJwt)));
  });

  test('a transport failure (no response) logs a null status, not a crash',
      () async {
    final dio = _dioWith(
      _StubAdapter(throwType: DioExceptionType.connectionTimeout),
    );
    await expectLater(
      dio.get<dynamic>('/v1/ping'),
      throwsA(isA<DioException>()),
    );

    final record = decodeLine(lines.single);
    expect(record['status'], isNull);
    expect(record['path'], '/v1/ping');
  });

  group('call context (diag-persistence lane)', () {
    test('every api line carries a MONOTONIC seq (ordered per session)',
        () async {
      final dio = _dioWith(_StubAdapter(status: 200));
      await dio.get<dynamic>('/v1/a');
      await dio.get<dynamic>('/v1/b');
      await dio.get<dynamic>('/v1/c');

      final seqs = lines.map((l) => decodeLine(l)['seq'] as int).toList();
      expect(seqs, hasLength(3));
      expect(seqs, orderedEquals(<int>[seqs[0], seqs[0] + 1, seqs[0] + 2]));
    });

    test('the api line carries the ACTIVE SCREEN route at call time',
        () async {
      Diag.currentScreen = '/jeeber/requests/:id';
      final dio = _dioWith(_StubAdapter(status: 200));
      await dio.get<dynamic>('/v1/offers');

      expect(decodeLine(lines.single)['screen'], '/jeeber/requests/:id');
    });

    test('screen is captured at REQUEST time, surviving a mid-flight nav',
        () async {
      Diag.currentScreen = '/checkout';
      final adapter = _GatedAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://x'))
        ..httpClientAdapter = adapter
        ..interceptors.add(const DiagDioInterceptor());
      final call = dio.get<dynamic>('/v1/pay');
      // Wait until the request has genuinely FIRED (onRequest ran, the
      await adapter.started.future;
      Diag.currentScreen = '/home';
      adapter.release.complete();
      await call;

      expect(decodeLine(lines.single)['screen'], '/checkout');
    });

    test('no screen recorded before the first navigation (field omitted)',
        () async {
      final dio = _dioWith(_StubAdapter(status: 200));
      await dio.get<dynamic>('/v1/boot');

      expect(decodeLine(lines.single).containsKey('screen'), isFalse);
    });

    test('an error-path line still carries seq + screen', () async {
      Diag.currentScreen = '/wallet';
      final dio = _dioWith(_StubAdapter(status: 500));
      await expectLater(
        dio.get<dynamic>('/v1/wallet'),
        throwsA(isA<DioException>()),
      );

      final record = decodeLine(lines.single);
      expect(record['seq'], isA<int>());
      expect(record['screen'], '/wallet');
    });
  });
}
