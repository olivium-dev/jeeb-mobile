import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/unversioned_path_fallback_interceptor.dart';

/// Lowest-level adapter that answers per path and records every path it saw, so
/// the versioned-then-unversioned replay order can be asserted without a socket.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

({Dio dio, _ScriptedAdapter adapter}) _harness(
  ResponseBody Function(RequestOptions options) responder, {
  List<String> scopedToSubtrees = const <String>[],
}) {
  final adapter = _ScriptedAdapter(responder);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:10090'))
    ..httpClientAdapter = adapter;
  dio.interceptors.add(
    UnversionedPathFallbackInterceptor(dio, scopedToSubtrees: scopedToSubtrees),
  );
  return (dio: dio, adapter: adapter);
}

void main() {
  test('a 404 on a versioned GET is replayed on the unversioned twin', () async {
    final harness = _harness(
      (options) => options.path == '/v1/requests'
          ? _json({'error': 'not found'}, 404)
          : _json({'items': <dynamic>[]}, 200),
    );

    final response = await harness.dio.get<Map<String, dynamic>>('/v1/requests');

    expect(response.statusCode, 200);
    expect(harness.adapter.paths, ['/v1/requests', '/requests']);
  });

  test('a 405 on a versioned POST is replayed unversioned', () async {
    final harness = _harness(
      (options) =>
          options.path.startsWith('/v1/') ? _json({}, 405) : _json({}, 200),
    );

    final response = await harness.dio.post<Map<String, dynamic>>(
      '/v1/matching/broadcast',
      data: <String, Object?>{'requestId': 'r-1'},
    );

    expect(response.statusCode, 200);
    expect(
      harness.adapter.paths,
      ['/v1/matching/broadcast', '/matching/broadcast'],
    );
  });

  test('a non-routing failure is never replayed', () async {
    final harness = _harness((_) => _json({}, 500));

    await expectLater(
      harness.dio.get<dynamic>('/v1/requests'),
      throwsA(isA<DioException>()),
    );
    expect(harness.adapter.paths, ['/v1/requests']);
  });

  test('an already-unversioned path is left alone', () async {
    final harness = _harness((_) => _json({}, 404));

    await expectLater(
      harness.dio.get<dynamic>('/jeebers/me/availability'),
      throwsA(isA<DioException>()),
    );
    expect(harness.adapter.paths, ['/jeebers/me/availability']);
  });

  test('both paths 404 surfaces the original versioned failure', () async {
    final harness = _harness((_) => _json({}, 404));

    DioException? captured;
    try {
      await harness.dio.get<dynamic>('/v1/deliveries/d-1');
    } on DioException catch (e) {
      captured = e;
    }

    expect(captured, isNotNull);
    expect(captured!.response?.statusCode, 404);
    expect(captured.requestOptions.path, '/v1/deliveries/d-1');
    expect(harness.adapter.paths, ['/v1/deliveries/d-1', '/deliveries/d-1']);
  });

  test('a path whose unversioned twin is a different route is not replayed',
      () async {
    final harness = _harness((_) => _json({}, 404));

    await expectLater(
      harness.dio.get<dynamic>(
        '/v1/deliveries',
        queryParameters: <String, Object?>{'role': 'jeeber'},
      ),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      harness.dio.post<dynamic>('/v1/requests', data: <String, Object?>{}),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      harness.dio.get<dynamic>('/v1/requests/r-1'),
      throwsA(isA<DioException>()),
    );

    expect(harness.adapter.paths, [
      '/v1/deliveries',
      '/v1/requests',
      '/v1/requests/r-1',
    ]);
  });

  test('collides() ignores the query string', () {
    expect(
      UnversionedPathFallbackInterceptor.collides('/v1/deliveries?role=jeeber'),
      isTrue,
    );
    expect(
      UnversionedPathFallbackInterceptor.collides('/v1/deliveries/d-1'),
      isFalse,
    );
    expect(
      UnversionedPathFallbackInterceptor.collides('/v1/offers'),
      isFalse,
    );
  });

  test('a FormData body is never replayed', () {
    final options = RequestOptions(
      path: '/v1/voice/transcribe',
      data: FormData(),
    );

    expect(
      UnversionedPathFallbackInterceptor.shouldReplay(options, 404),
      isFalse,
    );
  });

  test('unversioned() strips exactly one leading /v1', () {
    String? strip(String path) =>
        UnversionedPathFallbackInterceptor.unversioned(path);

    expect(strip('/v1/requests/7'), '/requests/7');
    expect(strip('/v1/jeeb/wallet'), '/jeeb/wallet');
    expect(strip('/requests'), isNull);
    expect(strip('/v1'), isNull);
    expect(strip('/api/v1/requests'), isNull);
  });

  test('a scoped instance replays only inside its subtrees', () async {
    final harness = _harness(
      (options) =>
          options.path.startsWith('/v1/') ? _json({}, 404) : _json({}, 200),
      scopedToSubtrees: const <String>['/v1/auth'],
    );

    final inside = await harness.dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: <String, Object?>{'refreshToken': 'r'},
    );
    expect(inside.statusCode, 200);

    // Outside the scope the error is passed straight through, unreplayed.
    await expectLater(
      harness.dio.get<dynamic>('/v1/jeeb/wallet'),
      throwsA(isA<DioException>()),
    );

    expect(harness.adapter.paths, [
      '/v1/auth/refresh',
      '/auth/refresh',
      '/v1/jeeb/wallet',
    ]);
  });

  test('a scoped instance replays at most once', () async {
    final harness = _harness(
      (_) => _json({}, 404),
      scopedToSubtrees: const <String>['/v1/auth'],
    );

    await expectLater(
      harness.dio.post<dynamic>('/v1/auth/refresh', data: <String, Object?>{}),
      throwsA(
        isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 404),
      ),
    );

    expect(harness.adapter.paths, ['/v1/auth/refresh', '/auth/refresh']);
  });

  test('inScope() is exact-or-descendant, never a bare prefix', () {
    final open = UnversionedPathFallbackInterceptor(Dio());
    final scoped = UnversionedPathFallbackInterceptor(
      Dio(),
      scopedToSubtrees: const <String>['/v1/auth'],
    );

    expect(open.inScope('/v1/anything'), isTrue);
    expect(scoped.inScope('/v1/auth'), isTrue);
    expect(scoped.inScope('/v1/auth/refresh'), isTrue);
    expect(scoped.inScope('/v1/auth/refresh?x=1'), isTrue);
    expect(scoped.inScope('/v1/authz/refresh'), isFalse);
    expect(scoped.inScope('/v1/jeeb/wallet'), isFalse);
  });
}
