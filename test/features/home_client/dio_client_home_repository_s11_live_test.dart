// S11 Defect-A LIVE regression — DioClientHomeRepository In-Progress merge.

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

// The live request id + amount the field run used (request-1b9c9153, $8).
const _freshRequestId = 'request-1b9c9153';
const _freshDeliveryId = 'delivery-1b9c9153-acc';

// ACTUAL `/v1/requests` row shape for the freshly-matched order (captured from
final _freshMatchedRequestRow = <String, dynamic>{
  'id': _freshRequestId,
  'displayId': 'ORD-234812',
  'clientId': 'user-client-001',
  'tier': 'express',
  'status': 'matched',
  'title': 'S11 repro grocery run',
  'pickup': {'address': 'Hamra', 'lat': 33.8938, 'lng': 35.5018},
  'dropoff': {'address': 'Ashrafieh', 'lat': 33.8886, 'lng': 35.4955},
  'recipientPhone': null,
  'offersCount': 1,
  'createdAt': '2026-06-26T17:44:07.643Z',
  'updatedAt': '2026-06-26T17:44:28.527Z',
  'conversationId': '8d44a60e-b450-4f7d-abe1-3ed9bb10935d',
  'deliveryStatus': 'matched',
  'jeeberId': 'user-jeeber-002',
  'amount': {'value': 8, 'minorUnits': 800, 'currency': 'USD'},
  'offerAvatars': <String>['https://cdn.jeeb.app/avatars/user-jeeber-002.png'],
};

// Seeded request rows the gateway returns under `status=active` (non-terminal),
final _seededActiveRequestRows = <Map<String, dynamic>>[
  {
    'id': 'request-pending-001',
    'status': 'pending',
    'title': 'Groceries from Spinneys',
    'offersCount': 2,
    'amount': {'value': 25, 'minorUnits': 2500, 'currency': 'USD'},
  },
  {
    'id': 'delivery-001',
    'status': 'matched',
    'title': 'Pharmacy → Ashrafieh',
    'offersCount': 2,
    'amount': {'value': 4.5, 'minorUnits': 450, 'currency': 'USD'},
  },
  {
    'id': 'delivery-002',
    'status': 'picked_up',
    'title': 'Mini-market run',
    'offersCount': 0,
    'amount': {'value': 8, 'minorUnits': 800, 'currency': 'USD'},
  },
];

// `/v1/requests?status=active` envelope — the live-proven filter that DOES
Map<String, dynamic> _activeRequestsBody() => <String, dynamic>{
      'items': <Map<String, dynamic>>[
        ..._seededActiveRequestRows,
        _freshMatchedRequestRow,
      ],
      'page': 1,
      'pageSize': 50,
      'totalCount': _seededActiveRequestRows.length + 1,
    };

// `/v1/requests` WITHOUT `status=active` (role-only) — simulates the live
Map<String, dynamic> _roleOnlyRequestsBody() => <String, dynamic>{
      'items': <Map<String, dynamic>>[..._seededActiveRequestRows],
      'page': 1,
      'pageSize': 50,
      'totalCount': _seededActiveRequestRows.length,
    };

// ACTUAL `/v1/deliveries?stage=active` row shape: id == deliveryId == the
Map<String, dynamic> _seededDeliveryRow(String id, String requestId,
        String title, String stage) =>
    <String, dynamic>{
      'id': id,
      'requestId': requestId,
      'clientId': 'user-client-001',
      'jeeberId': 'user-jeeber-002',
      'tier': 'express',
      'status': stage,
      'title': title,
      'amount': {'value': 8, 'minorUnits': 800, 'currency': 'USD'},
      'deliveryId': id,
      'delivery_id': id,
      'currentStage': stage,
      'jeeberName': 'Kamal Hajj',
    };

// Deliveries source that has minted the new order's row (steady state) — the
Map<String, dynamic> _deliveriesWithFreshRow() => <String, dynamic>{
      'items': <Map<String, dynamic>>[
        _seededDeliveryRow('delivery-001', 'delivery-001',
            'Pharmacy → Ashrafieh', 'Ordered'),
        _seededDeliveryRow('delivery-002', 'delivery-002', 'Mini-market run',
            'Picked'),
        _seededDeliveryRow(
            _freshDeliveryId, _freshRequestId, 'S11 repro grocery run',
            'Ordered'),
      ],
      'page': 1,
      'pageSize': 50,
      'totalCount': 3,
    };

// Deliveries source that has NOT yet minted the new order's delivery row (the
Map<String, dynamic> _deliveriesWithoutFreshRow() => <String, dynamic>{
      'items': <Map<String, dynamic>>[
        _seededDeliveryRow('delivery-001', 'delivery-001',
            'Pharmacy → Ashrafieh', 'Ordered'),
        _seededDeliveryRow('delivery-002', 'delivery-002', 'Mini-market run',
            'Picked'),
      ],
      'page': 1,
      'pageSize': 50,
      'totalCount': 2,
    };

void main() {
  late _MockDio dio;
  late DioClientHomeRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioClientHomeRepository(dio);
  });

  // PARAM-SENSITIVE requests stub: the matched row is surfaced ONLY when the
  void stubRequestsBySurface() {
    when(() => dio.get<dynamic>(
          '/requests',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((invocation) async {
      final qp = invocation.namedArguments[#queryParameters]
          as Map<String, dynamic>?;
      final isActive = qp?['status'] == 'active';
      return _ok(isActive ? _activeRequestsBody() : _roleOnlyRequestsBody());
    });
  }

  void stubDeliveries(Map<String, dynamic> body) {
    when(() => dio.get<dynamic>(
          '/deliveries',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok(body));
  }

  // BUG-3 offer probes (`GET /v1/offers?requestId=`) run for every
  void stubOfferProbes() {
    when(() => dio.get<dynamic>(
          '/v1/offers',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok(<String, dynamic>{'items': <Object>[]}));
  }

  test(
      'the merge queries /v1/requests with status=active (the live-proven '
      'filter) — NOT the S10 role-only query', () async {
    stubDeliveries(_deliveriesWithoutFreshRow());
    stubRequestsBySurface();
    stubOfferProbes();

    await repo.loadSnapshot();

    // At least one /requests call must carry status=active (the active
    final activeCalls = verify(() => dio.get<dynamic>(
          '/requests',
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured;
    final sawStatusActive = activeCalls
        .whereType<Map<String, dynamic>>()
        .any((qp) => qp['status'] == 'active');
    expect(sawStatusActive, isTrue,
        reason: 'active merge must query /v1/requests?status=active');
  });

  test(
      'LIVE BUG: fresh matched request renders even when the deliveries source '
      'has not minted its row yet (surfaced via status=active merge)', () async {
    // Deliveries source lags (no delivery row for the new order yet).
    stubDeliveries(_deliveriesWithoutFreshRow());
    stubRequestsBySurface();
    stubOfferProbes();

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    // The brand-new matched order surfaces (this is the live regression).
    expect(ids, contains(_freshRequestId),
        reason: 'fresh matched request must surface via status=active merge');
    // Seeded delivery rows still render — merge is additive, not narrowing.
    expect(ids, contains('delivery-001'));
    expect(ids, contains('delivery-002'));

    final fresh =
        snapshot.inProgress.firstWhere((r) => r.id == _freshRequestId);
    expect(fresh.status, ClientRequestStatus.accepted);
    expect(fresh.title, 'S11 repro grocery run');
  });

  test(
      'steady state: when the deliveries source HAS minted the row, the '
      'In-Progress card carries the server deliveryId for the Track CTA and '
      'the order is NOT doubled', () async {
    stubDeliveries(_deliveriesWithFreshRow());
    stubRequestsBySurface();
    stubOfferProbes();

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    // Surfaced via the delivery row (which carries the real delivery id).
    expect(ids, contains(_freshDeliveryId));
    // Deduped: the request-id projection of the same order must NOT also appear.
    expect(ids, isNot(contains(_freshRequestId)));

    final card =
        snapshot.inProgress.firstWhere((r) => r.id == _freshDeliveryId);
    // Track CTA: the card exposes the server delivery id (GET /v1/delivery/<id>
    expect(card.deliveryId, _freshDeliveryId);
    expect(card.trackingId, _freshDeliveryId);

    // Seeded rows still render.
    expect(ids, contains('delivery-001'));
    expect(ids, contains('delivery-002'));
  });

  test('pending requests never leak into In-Progress', () async {
    stubDeliveries(_deliveriesWithoutFreshRow());
    stubRequestsBySurface();
    stubOfferProbes();

    final snapshot = await repo.loadSnapshot();
    final ids = snapshot.inProgress.map((r) => r.id).toList();

    expect(ids, isNot(contains('request-pending-001')));
  });
}
