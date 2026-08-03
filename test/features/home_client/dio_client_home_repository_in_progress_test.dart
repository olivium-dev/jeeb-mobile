// S10 Defect A — DioClientHomeRepository In-Progress merge.

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

  // Stub paths/type-args trued up to the CURRENT repository architecture
  void stubDeliveries(Map<String, dynamic> body) {
    when(() => dio.get<dynamic>(
          '/deliveries',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok(body));
  }

  void stubDeliveriesError(int statusCode) {
    when(() => dio.get<dynamic>(
          '/deliveries',
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/deliveries'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/deliveries'),
        statusCode: statusCode,
      ),
      type: DioExceptionType.badResponse,
    ));
  }

  void stubRequests(Map<String, dynamic> body) {
    when(() => dio.get<dynamic>(
          '/requests',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok(body));
  }

  // BUG-3 offer probes (`GET /v1/offers?requestId=`) run for every
  void stubOffers() {
    when(() => dio.get<dynamic>(
          '/v1/offers',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => _ok(<String, dynamic>{'items': <dynamic>[]}),
    );
  }

  // A seeded active delivery row + an accept-minted delivery row (covers
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
    stubOffers();

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
    stubOffers();

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    // `request-covered` is the parent of `delivery-acc` → it must appear ONLY
    expect(ids, isNot(contains('request-covered')));
    expect(ids.where((id) => id == 'delivery-acc').length, 1);
  });

  test('pending / delivered requests never leak into In-Progress', () async {
    stubDeliveries(deliveriesBody);
    stubRequests(requestsBody);
    stubOffers();

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
    stubOffers();

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

  // ---------------------------------------------------------------------------
  final orderedDeliveryBody = <String, dynamic>{
    'items': <Map<String, dynamic>>[
      {
        'id': 'delivery-x',
        'requestId': 'req-x',
        'clientId': 'user-client-001',
        'status': 'Ordered',
        'progressStep': 0,
        'title': 'Brand-new order',
      },
    ],
    'totalCount': 1,
  };

  final matchedRequestBody = <String, dynamic>{
    'items': <Map<String, dynamic>>[
      {
        'id': 'req-x',
        'clientId': 'user-client-001',
        'status': 'matched',
        'deliveryId': 'delivery-x',
        'title': 'Brand-new order',
        'offersCount': 1,
      },
    ],
    'totalCount': 1,
  };

  test(
      'S12: an `Ordered` delivery row maps to accepted (trackable), not '
      'searching — and progressStep stays 0 so the stepper is unchanged',
      () async {
    stubDeliveries(orderedDeliveryBody);
    stubRequests(matchedRequestBody);
    stubOffers();

    final snapshot = await repo.loadSnapshot();
    final row = snapshot.inProgress.firstWhere((r) => r.id == 'delivery-x');

    // THE FIX: `Ordered` → accepted so the "Track my order" / "Open chat" CTA
    expect(row.status, ClientRequestStatus.accepted);
    // The visual stage is read independently from `progressStep`, so the
    expect(row.progressStep, 0);
  });

  test(
      'S12 guard: a delivery row carrying `requestId` yields exactly ONE '
      'trackable row for that order (no duplicate from the request path)',
      () async {
    stubDeliveries(orderedDeliveryBody);
    stubRequests(matchedRequestBody);
    stubOffers();

    final snapshot = await repo.loadSnapshot();
    final forOrder = snapshot.inProgress
        .where((r) => r.id == 'delivery-x' || r.id == 'req-x')
        .toList();

    // Exactly one row, and it's the delivery-backed (tracking-id-bearing) row —
    expect(forOrder.length, 1);
    expect(forOrder.single.id, 'delivery-x');
  });
}
