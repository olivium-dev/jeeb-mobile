// BUG-3 (customer offer discovery): the LIVE `GET /requests?role=client`
// payload carries NO offer indicator (offersCount/jeeberId null even when a
// jeeber has offered — confirmed by a read-only probe against :10090). So the
// client must make offer discovery DETERMINISTIC by fetching the live offers
// for each non-accepted request via `GET /v1/offers?requestId` and bucketing on
// that count — otherwise the Replies tab reads "No replies yet" and the offer
// is never reachable/acceptable.
//
// These tests pin:
//  - the exact offers-read route + query param the repo issues per request,
//  - an offer-bearing request surfacing in Replies even when the payload has
//    NO offer indicator,
//  - a no-offer request staying in Pending,
//  - withdrawn offers NOT counting,
//  - a degraded/erroring offers endpoint (the live 500) failing soft — the
//    home load still resolves and never throws.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _resp(String path, Object? data) =>
    Response<dynamic>(data: data, requestOptions: RequestOptions(path: path));

void main() {
  late _MockDio dio;
  late DioClientHomeRepository repo;
  late List<String> offerRequestIds;

  setUp(() {
    dio = _MockDio();
    repo = DioClientHomeRepository(dio);
    offerRequestIds = <String>[];
  });

  /// Wires the three home GETs. `offersByRequestId` maps a requestId to the
  /// offer rows the offer-service returns for it; a `null` entry makes the
  /// offers read THROW (simulating the live 500) so we can assert soft-fail.
  void stub({
    required List<dynamic> requests,
    required Map<String, List<Map<String, dynamic>>?> offersByRequestId,
  }) {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      final query =
          invocation.namedArguments[#queryParameters] as Map<String, dynamic>?;
      if (path == '/deliveries') return _resp(path, {'shipments': <dynamic>[]});
      if (path == '/requests') return _resp(path, {'items': requests});
      if (path == '/v1/offers') {
        final rid = query?['requestId'] as String? ?? '';
        offerRequestIds.add(rid);
        final rows = offersByRequestId[rid];
        if (rows == null) {
          // Simulate the live offers-read 500 → repo must degrade, not throw.
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response<dynamic>(
              statusCode: 500,
              requestOptions: RequestOptions(path: path),
            ),
          );
        }
        return _resp(path, {'items': rows});
      }
      return _resp(path, {'items': <dynamic>[]});
    });
  }

  test(
      'offer-bearing request surfaces in Replies via GET /v1/offers?requestId '
      'EVEN WHEN the role=client payload has NO offer indicator', () async {
    // Mirrors the live shape: no offersCount/jeeberId on the request row.
    stub(
      requests: [
        {'id': 'req-A', 'status': 'pending', 'title': 'Pharmacy run'},
      ],
      offersByRequestId: {
        'req-A': [
          {'id': 'off-1', 'jeeberId': 'jb-9', 'status': 'pending'},
        ],
      },
    );

    final snapshot = await repo.loadSnapshot();

    // The deterministic probe hit the customer offers route with the request id.
    expect(offerRequestIds, contains('req-A'));
    // The request is now an actionable reply, not a stuck pending row.
    final reply = snapshot.replies.where((r) => r.id == 'req-A');
    expect(reply, hasLength(1));
    expect(reply.single.status, ClientRequestStatus.offersReceived);
    expect(reply.single.offerCount, 1);
    expect(snapshot.pending.where((r) => r.id == 'req-A'), isEmpty);
  });

  test('a request with no live offers stays in Pending', () async {
    stub(
      requests: [
        {'id': 'req-B', 'status': 'pending', 'title': 'Grocery run'},
      ],
      offersByRequestId: {'req-B': <Map<String, dynamic>>[]},
    );

    final snapshot = await repo.loadSnapshot();

    expect(offerRequestIds, contains('req-B'));
    expect(snapshot.pending.map((r) => r.id), contains('req-B'));
    expect(snapshot.replies, isEmpty);
  });

  test('withdrawn offers do NOT flip a request into Replies', () async {
    stub(
      requests: [
        {'id': 'req-C', 'status': 'pending', 'title': 'Stale bid'},
      ],
      offersByRequestId: {
        'req-C': [
          {'id': 'off-x', 'jeeberId': 'jb-1', 'status': 'withdrawn'},
        ],
      },
    );

    final snapshot = await repo.loadSnapshot();

    expect(snapshot.replies, isEmpty);
    expect(snapshot.pending.map((r) => r.id), contains('req-C'));
  });

  test('a 500 from the offers-read degrades to the payload count (no throw)',
      () async {
    // `null` rows → the stub throws a 500 DioException for this request, exactly
    // like the live binary. The home load must still resolve.
    stub(
      requests: [
        {'id': 'req-D', 'status': 'pending', 'title': 'Resilience'},
      ],
      offersByRequestId: {'req-D': null},
    );

    final snapshot = await repo.loadSnapshot();

    // No live count available → falls back to the (absent) payload count → 0 →
    // stays pending. Crucially: it did not throw.
    expect(snapshot.pending.map((r) => r.id), contains('req-D'));
    expect(snapshot.replies, isEmpty);
  });

  test('accepted requests are NOT probed for offers (stay In Progress)',
      () async {
    stub(
      requests: [
        {
          'id': 'req-acc',
          'status': 'accepted',
          'conversationId': 'conv-1',
          'title': 'Already accepted',
        },
      ],
      offersByRequestId: const {},
    );

    final snapshot = await repo.loadSnapshot();

    expect(offerRequestIds, isEmpty,
        reason: 'accepted rows must not trigger an offers probe');
    expect(snapshot.inProgress.map((r) => r.id), contains('req-acc'));
  });
}
