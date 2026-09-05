// NET-27: every request carries a client correlation id the diagnostics
// interceptor can log and a bug report can quote.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/idempotency/operation_id.dart';
import 'package:jeeb_mobile/core/network/request_id_interceptor.dart';

class _CapturingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 200, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _CapturingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..interceptors.add(RequestIdInterceptor())
      ..httpClientAdapter = adapter;
  });

  test('every request gets a fresh operation id', () async {
    await dio.get<dynamic>('/v1/offers');
    await dio.get<dynamic>('/v1/offers');

    final ids = adapter.requests
        .map((r) => r.headers[RequestIdInterceptor.headerName] as String)
        .toList();
    expect(ids, hasLength(2));
    expect(ids.every(isOperationId), isTrue);
    expect(ids.first, isNot(ids.last));
  });

  test('a caller-supplied id is never overwritten, whatever its casing',
      () async {
    await dio.get<dynamic>(
      '/v1/offers',
      options: Options(headers: <String, dynamic>{'x-request-id': 'pinned'}),
    );

    expect(adapter.requests.single.headers['x-request-id'], 'pinned');
    // One id, not two: the interceptor never adds a second spelling.
    expect(
      adapter.requests.single.headers.keys
          .where((k) => k.toLowerCase() == 'x-request-id'),
      hasLength(1),
    );
  });
}
