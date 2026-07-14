import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/single_flight_get.dart';

/// Lowest-level Dio adapter that DELAYS each response until its gate completes
/// and counts how many requests actually reach the wire. The gate lets a test
/// hold two identical reads concurrently in flight so it can prove the
/// single-flight coalescer collapses them onto ONE wire call (FIX-A).
class _GatedAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  final Completer<void> gate = Completer<void>();

  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await gate.future;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _GatedAdapter adapter;
  late Dio dio;
  late SingleFlightGet coalescer;

  setUp(() {
    adapter = _GatedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = adapter;
    coalescer = SingleFlightGet(dio);
  });

  test('two concurrent identical GETs collapse to ONE wire call', () async {
    final a = coalescer.get('/v1/offers', queryParameters: {'requestId': 'r1'});
    final b = coalescer.get('/v1/offers', queryParameters: {'requestId': 'r1'});

    // Both callers hold the SAME future — the duplicate is coalesced and never
    // issues a second `Dio.get` (the wire hit itself lands asynchronously).
    expect(identical(a, b), isTrue);

    adapter.gate.complete();
    final ra = await a;
    final rb = await b;
    expect(ra.statusCode, 200);
    expect(rb.statusCode, 200);
    // Exactly one wire hit for the two concurrent identical reads.
    expect(adapter.callCount, 1);
  });

  test('order-independent query keys collapse ({a,b} == {b,a})', () async {
    final a = coalescer
        .get('/v1/offers', queryParameters: {'requestId': 'r1', 'page': 1});
    final b = coalescer
        .get('/v1/offers', queryParameters: {'page': 1, 'requestId': 'r1'});
    expect(identical(a, b), isTrue);
    adapter.gate.complete();
    await a;
    await b;
    expect(adapter.callCount, 1);
  });

  test('distinct request ids do NOT collapse', () async {
    final a = coalescer.get('/v1/offers', queryParameters: {'requestId': 'r1'});
    final b = coalescer.get('/v1/offers', queryParameters: {'requestId': 'r2'});
    expect(identical(a, b), isFalse);
    adapter.gate.complete();
    await a;
    await b;
    expect(adapter.callCount, 2);
  });

  test('entries self-evict — a later read is a FRESH call, never cached',
      () async {
    adapter.gate.complete(); // resolve immediately for this scenario
    await coalescer.get('/v1/offers', queryParameters: {'requestId': 'r1'});
    // The first read settled and evicted; the second must hit the wire again
    // (single-flight, not a cache).
    await coalescer.get('/v1/offers', queryParameters: {'requestId': 'r1'});
    expect(adapter.callCount, 2);
  });
}
