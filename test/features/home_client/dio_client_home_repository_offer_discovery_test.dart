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

    expect(offerRequestIds, contains('req-A'));
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
    stub(
      requests: [
        {'id': 'req-D', 'status': 'pending', 'title': 'Resilience'},
      ],
      offersByRequestId: {'req-D': null},
    );

    final snapshot = await repo.loadSnapshot();

    expect(snapshot.pending.map((r) => r.id), contains('req-D'));
    expect(snapshot.replies, isEmpty);
  });

  // The Replies card's "N offers · from $X" floor. It is computed over the
  // SAME probe payload the count comes from — zero extra network — and it is
  // absent by construction wherever the probe is skipped.
  group('offer floor (redesign-2026-08 screen 04)', () {
    test('probed row carries the lowest fee and its currency', () async {
      stub(
        requests: [
          {'id': 'req-F', 'status': 'pending', 'title': 'Groceries'},
        ],
        offersByRequestId: {
          'req-F': [
            {'id': 'o1', 'status': 'pending', 'fee': 12, 'currency': 'USD'},
            {'id': 'o2', 'status': 'pending', 'fee': 8.5, 'currency': 'USD'},
            {'id': 'o3', 'status': 'pending', 'fee': 20, 'currency': 'USD'},
          ],
        },
      );

      final snapshot = await repo.loadSnapshot();

      final reply = snapshot.replies.singleWhere((r) => r.id == 'req-F');
      expect(reply.offerCount, 3);
      expect(reply.lowestOfferFee, 8.5);
      expect(reply.offerCurrency, 'USD');
    });

    test('fee-less offers are ignored by the floor, not counted as zero',
        () async {
      stub(
        requests: [
          {'id': 'req-G', 'status': 'pending', 'title': 'Pharmacy'},
        ],
        offersByRequestId: {
          'req-G': [
            {'id': 'o1', 'status': 'pending'},
            {'id': 'o2', 'status': 'pending', 'fee': 9, 'currency': 'LBP'},
          ],
        },
      );

      final snapshot = await repo.loadSnapshot();

      final reply = snapshot.replies.singleWhere((r) => r.id == 'req-G');
      expect(reply.offerCount, 2, reason: 'both offers are live');
      expect(reply.lowestOfferFee, 9, reason: 'the fee-less offer contributes nothing');
      expect(reply.offerCurrency, 'LBP');
    });

    test('a row bucketed by its payload count gets NO floor (never probed)',
        () async {
      stub(
        requests: [
          {
            'id': 'req-H',
            'status': 'pending',
            'title': 'Declared reply',
            'offersCount': 4,
          },
        ],
        offersByRequestId: const {},
      );

      final snapshot = await repo.loadSnapshot();

      expect(offerRequestIds, isEmpty,
          reason: 'the probe-skip must survive — a declared reply is not probed');
      final reply = snapshot.replies.singleWhere((r) => r.id == 'req-H');
      expect(reply.offerCount, 4);
      expect(reply.lowestOfferFee, isNull);
      expect(reply.offerCurrency, isNull);
    });

    test('offers with no fee at all leave the floor null', () async {
      stub(
        requests: [
          {'id': 'req-I', 'status': 'pending', 'title': 'No quotes'},
        ],
        offersByRequestId: {
          'req-I': [
            {'id': 'o1', 'status': 'pending'},
          ],
        },
      );

      final snapshot = await repo.loadSnapshot();

      final reply = snapshot.replies.singleWhere((r) => r.id == 'req-I');
      expect(reply.offerCount, 1);
      expect(reply.lowestOfferFee, isNull);
    });
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
