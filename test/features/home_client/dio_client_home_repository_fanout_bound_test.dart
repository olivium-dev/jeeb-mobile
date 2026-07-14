// F3 (offers-polling storm — fan-out bound + 429 tolerance).
//
// The customer HOME used to brick on New Order because a customer with N active
// requests fanned out N DISTINCT `GET /v1/offers?requestId` reads in one
// unbounded burst, tripping the gateway's per-subscription 429, and the home
// path then treated that 429 as a fatal "Couldn't reach Jeeb."
//
// These two tests pin the fix at the REPOSITORY seam:
//   1. the per-request offer fan-out is drained through a BOUNDED worker pool —
//      at most K (=2) `GET /v1/offers` are ever in flight at once, no matter how
//      many active requests the customer has;
//   2. a 429 on those probes NEVER throws out of `loadSnapshot` — it degrades to
//      a snapshot that still carries the requests AND flags `rateLimited` (with
//      the advertised `Retry-After`), so the cubit can keep data + back off
//      instead of failing the whole home tab.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _resp(String path, Object? data) =>
    Response<dynamic>(data: data, requestOptions: RequestOptions(path: path));

/// Max concurrent `/v1/offers` probes the repo is allowed to have in flight.
/// Mirrors `DioClientHomeRepository._probeConcurrency`.
const int _kMaxConcurrentOfferProbes = 2;

void main() {
  late _MockDio dio;
  late DioClientHomeRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioClientHomeRepository(dio);
  });

  /// Builds N distinct offer-less pending requests, forcing N distinct
  /// `/v1/offers?requestId` probes (no payload `offersCount`, so each row is an
  /// unknown that must be probed).
  List<Map<String, dynamic>> pendingRequests(int n) => [
        for (var i = 0; i < n; i++)
          {'id': 'r-$i', 'status': 'pending', 'title': 'Req $i'},
      ];

  test(
      'a customer with many active requests never bursts the /v1/offers '
      'fan-out — at most K probes are ever in flight at once', () async {
    const requestCount = 8; // well above the K=2 bound
    var inFlight = 0;
    var peakInFlight = 0;
    // Gate the probes open only once all that CAN start have started, so the
    // peak is observed under maximum contention.
    final release = Completer<void>();

    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/deliveries') return _resp(path, {'shipments': <dynamic>[]});
      if (path == '/requests') {
        return _resp(path, {'items': pendingRequests(requestCount)});
      }
      if (path == '/v1/offers') {
        inFlight += 1;
        if (inFlight > peakInFlight) peakInFlight = inFlight;
        // Hold the probe open until released so overlapping probes accumulate.
        await release.future;
        inFlight -= 1;
        return _resp(path, {'items': <dynamic>[]});
      }
      return _resp(path, {'items': <dynamic>[]});
    });

    final future = repo.loadSnapshot();

    // Let the bounded pool spin up its workers and saturate.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    // The bound holds: never more than K probes concurrently, even though the
    // customer has 8 offer-less requests to resolve.
    expect(
      peakInFlight,
      lessThanOrEqualTo(_kMaxConcurrentOfferProbes),
      reason: 'the per-request /v1/offers fan-out must be bounded to K=$_kMaxConcurrentOfferProbes',
    );
    expect(peakInFlight, greaterThan(0), reason: 'probes must actually run');

    release.complete();
    await future; // drains cleanly
  });

  test(
      'a 429 on the offer probes degrades gracefully — loadSnapshot does NOT '
      'throw, still returns the requests, and flags rateLimited + Retry-After',
      () async {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/deliveries') return _resp(path, {'shipments': <dynamic>[]});
      if (path == '/requests') {
        return _resp(path, {'items': pendingRequests(3)});
      }
      if (path == '/v1/offers') {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            statusCode: 429,
            headers: Headers.fromMap({
              'retry-after': ['30'],
            }),
          ),
          type: DioExceptionType.badResponse,
        );
      }
      return _resp(path, {'items': <dynamic>[]});
    });

    // Must NOT throw despite every probe 429ing.
    final snapshot = await repo.loadSnapshot();

    expect(snapshot.rateLimited, isTrue,
        reason: 'a throttled probe must surface as rateLimited, never thrown');
    expect(snapshot.retryAfter, const Duration(seconds: 30),
        reason: 'the advertised Retry-After must be parsed and surfaced');
    // The requests still came back (they degrade to Pending on the null probe).
    expect(snapshot.pending, hasLength(3),
        reason: 'partial data must survive a 429 — the load is best-effort');
  });
}
