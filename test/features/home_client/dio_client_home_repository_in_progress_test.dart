// S10 Defect A — DioClientHomeRepository In-Progress merge.
//
// A freshly-accepted order whose parent REQUEST flips to `matched` must surface
// in the client home "In Progress" tab even when the deliveries-only source
// (`GET /v1/deliveries?stage=active`) omits it (e.g. Mockoon :3055 has no
// `/v1/deliveries` route → 404 → empty; a gateway can flip the request status
// without surfacing a delivery row yet). The repository now merges the
// client-scoped `GET /v1/requests?role=client` in-flight requests, additively
// (seeded delivery rows still render) and deduped by the delivery rows'
// `requestId` (no double-rendering of an order already shown as a delivery row).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: data,
    );

void main() {
  late _MockDio dio;
  late DioClientHomeRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioClientHomeRepository(dio);
  });

  void stubDeliveries(Map<String, dynamic> body) {
    when(() => dio.get<Map<String, dynamic>>(
          '/v1/deliveries',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok(body));
  }

  void stubDeliveriesError(int statusCode) {
    when(() => dio.get<Map<String, dynamic>>(
          '/v1/deliveries',
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/v1/deliveries'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/v1/deliveries'),
        statusCode: statusCode,
      ),
      type: DioExceptionType.badResponse,
    ));
  }

  void stubRequests(Map<String, dynamic> body) {
    when(() => dio.get<Map<String, dynamic>>(
          '/v1/requests',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok(body));
  }

  // A seeded active delivery row + an accept-minted delivery row (covers
  // `request-covered`). Mirrors the Express-mock `/v1/deliveries?stage=active`
  // envelope: `{ items, totalCount, ... }` with `requestId` per row.
  final deliveriesBody = <String, dynamic>{
    'items': <Map<String, dynamic>>[
      {
        'id': 'delivery-001',
        'requestId': 'request-seed-1',
        'clientId': 'user-client-001',
        'status': 'Ordered',
        'title': 'Seeded order',
      },
      {
        'id': 'delivery-acc',
        'requestId': 'request-covered',
        'clientId': 'user-client-001',
        'status': 'Ordered',
        'title': 'Accept-minted order',
      },
    ],
    'totalCount': 2,
  };

  // The client-scoped requests list: a FRESH matched request (not covered by a
  // delivery row), the already-covered request (must dedupe), and pre/terminal
  // requests that must NOT leak into In-Progress.
  final requestsBody = <String, dynamic>{
    'items': <Map<String, dynamic>>[
      {
        'id': 'request-fresh-1',
        'clientId': 'user-client-001',
        'status': 'matched',
        'title': 'Fresh accepted order',
        'offersCount': 1,
      },
      {
        'id': 'request-covered',
        'clientId': 'user-client-001',
        'status': 'matched',
        'title': 'Already a delivery row',
        'offersCount': 1,
      },
      {
        'id': 'request-pending-1',
        'clientId': 'user-client-001',
        'status': 'pending',
        'title': 'Still searching',
        'offersCount': 0,
      },
      {
        'id': 'request-delivered-1',
        'clientId': 'user-client-001',
        'status': 'delivered',
        'title': 'Old completed order',
        'offersCount': 0,
      },
    ],
    'totalCount': 4,
  };

  test(
      'In-Progress includes BOTH seeded delivery rows AND a fresh matched '
      'request (client-scoped), without narrowing the seeded predicate',
      () async {
    stubDeliveries(deliveriesBody);
    stubRequests(requestsBody);

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    // Seeded + accept-minted delivery rows still render (predicate not narrowed).
    expect(ids, contains('delivery-001'));
    expect(ids, contains('delivery-acc'));
    // The freshly-accepted order surfaces via the requests merge.
    expect(ids, contains('request-fresh-1'));
  });

  test('a request already represented by a delivery row is NOT duplicated',
      () async {
    stubDeliveries(deliveriesBody);
    stubRequests(requestsBody);

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    // `request-covered` is the parent of `delivery-acc` → it must appear ONLY
    // as the delivery row, never as a second (request-id) row.
    expect(ids, isNot(contains('request-covered')));
    expect(ids.where((id) => id == 'delivery-acc').length, 1);
  });

  test('pending / delivered requests never leak into In-Progress', () async {
    stubDeliveries(deliveriesBody);
    stubRequests(requestsBody);

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    expect(ids, isNot(contains('request-pending-1')));
    expect(ids, isNot(contains('request-delivered-1')));
  });

  test(
      'fresh matched request STILL surfaces when /v1/deliveries 404s '
      '(Mockoon :3055 / gateway omits the delivery row)', () async {
    stubDeliveriesError(404);
    stubRequests(requestsBody);

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    // No delivery rows (source 404'd) but the matched request is rescued.
    expect(ids, contains('request-fresh-1'));
    // The covered request now has no delivery row, so it surfaces too.
    expect(ids, contains('request-covered'));
    final fresh =
        snapshot.inProgress.firstWhere((r) => r.id == 'request-fresh-1');
    expect(fresh.status, ClientRequestStatus.accepted);
  });
}
