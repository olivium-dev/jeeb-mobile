import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _resp(String path, Object? data) => Response<dynamic>(
  data: data,
  requestOptions: RequestOptions(path: path),
);

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
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((invocation) async {
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

  test('offer-bearing request surfaces in Replies via GET /v1/offers?requestId '
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

  test(
    'withdrawn lifecycle is retained without erasing a positive payload count',
    () async {
      stub(
        requests: [
          {
            'id': 'req-C',
            'status': 'pending',
            'title': 'Stale bid',
            'offersCount': 4,
          },
        ],
        offersByRequestId: {
          'req-C': [
            {'id': 'off-x', 'jeeberId': 'jb-1', 'status': 'withdrawn'},
          ],
        },
      );

      final snapshot = await repo.loadSnapshot();

      expect(snapshot.replies.map((r) => r.id), contains('req-C'));
      expect(snapshot.pending, isEmpty);
      expect(
        snapshot.offerStatusRequests.single.offerStatuses,
        contains(ClientOfferStatus.withdrawn),
      );
    },
  );

  test(
    'rejected wire status is retained as superseded for More filtering',
    () async {
      stub(
        requests: [
          {'id': 'req-rejected', 'status': 'pending', 'title': 'Rejected bid'},
        ],
        offersByRequestId: {
          'req-rejected': [
            {'id': 'offer-rejected', 'status': 'rejected'},
          ],
        },
      );

      final snapshot = await repo.loadSnapshot();

      expect(snapshot.offerStatusRequests.single.offerStatuses, {
        ClientOfferStatus.superseded,
      });
    },
  );

  test(
    'all backend offer lifecycle statuses are retained distinctly for filtering',
    () async {
      stub(
        requests: [
          {'id': 'req-all', 'status': 'pending', 'title': 'All statuses'},
        ],
        offersByRequestId: {
          'req-all': [
            for (final status in const [
              'pending',
              'submitted',
              'edited',
              'accepted',
              'withdrawn',
              'expired',
              'rejected',
            ])
              {'id': 'offer-$status', 'status': status},
          ],
        },
      );

      final snapshot = await repo.loadSnapshot();

      expect(
        snapshot.offerStatusRequests.single.offerStatuses,
        ClientOfferStatus.values.toSet(),
      );
    },
  );

  test(
    'a failed unresolved probe never fabricates a Pending classification',
    () async {
      stub(
        requests: [
          {'id': 'req-D', 'status': 'pending', 'title': 'Resilience'},
        ],
        offersByRequestId: {'req-D': null},
      );

      final snapshot = await repo.loadSnapshot();

      expect(snapshot.pending, isEmpty);
      expect(snapshot.replies, isEmpty);
      expect(snapshot.offerStatusRequests, isEmpty);
    },
  );

  test(
    'rotating ten-probe window reaches later requests without false Pending rows',
    () async {
      final requests = <Map<String, dynamic>>[
        for (var i = 0; i < 12; i++)
          {'id': 'req-$i', 'status': 'pending', 'title': 'Request $i'},
      ];
      stub(
        requests: requests,
        offersByRequestId: {
          for (var i = 0; i < 11; i++) 'req-$i': <Map<String, dynamic>>[],
          'req-11': [
            {'id': 'offer-late', 'status': 'submitted'},
          ],
        },
      );

      final first = await repo.loadSnapshot();

      expect(offerRequestIds, hasLength(10));
      expect(offerRequestIds, isNot(contains('req-10')));
      expect(offerRequestIds, isNot(contains('req-11')));
      expect(
        first.pending.map((request) => request.id),
        isNot(contains('req-10')),
      );
      expect(
        first.pending.map((request) => request.id),
        isNot(contains('req-11')),
      );
      expect(
        first.replies.map((request) => request.id),
        isNot(contains('req-11')),
      );

      final second = await repo.loadSnapshot();
      final secondWindow = offerRequestIds.skip(10).toList(growable: false);

      expect(secondWindow, hasLength(10));
      expect(secondWindow, containsAll(<String>['req-10', 'req-11']));
      expect(second.pending.map((request) => request.id), contains('req-10'));
      expect(second.replies.map((request) => request.id), contains('req-11'));
      expect(
        second.offerStatusRequests
            .singleWhere((request) => request.id == 'req-11')
            .offerStatuses,
        {ClientOfferStatus.submitted},
      );
    },
  );

  // The Replies card's "N offers · from $X" floor. It is computed over the
  // SAME probe payload the count comes from — zero extra network — and it is
  // absent when the probe fails, is capped, or has no fee-bearing offer.
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

    test(
      'fee-less offers are ignored by the floor, not counted as zero',
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
        expect(
          reply.lowestOfferFee,
          9,
          reason: 'the fee-less offer contributes nothing',
        );
        expect(reply.offerCurrency, 'LBP');
      },
    );

    test(
      'a probe enriches a payload-count reply with fee and lifecycle status',
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
          offersByRequestId: {
            'req-H': [
              {'id': 'o1', 'status': 'edited', 'fee': 7, 'currency': 'USD'},
            ],
          },
        );

        final snapshot = await repo.loadSnapshot();

        expect(offerRequestIds, contains('req-H'));
        final reply = snapshot.replies.singleWhere((r) => r.id == 'req-H');
        expect(reply.offerCount, 4);
        expect(reply.lowestOfferFee, 7);
        expect(reply.offerCurrency, 'USD');
        expect(reply.offerStatuses, contains(ClientOfferStatus.edited));
      },
    );

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

  test(
    'accepted requests are NOT probed for offers (stay In Progress)',
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

      expect(
        offerRequestIds,
        isEmpty,
        reason: 'accepted rows must not trigger an offers probe',
      );
      expect(snapshot.inProgress.map((r) => r.id), contains('req-acc'));
      expect(
        snapshot.offerStatusRequests.single.offerStatuses,
        contains(ClientOfferStatus.accepted),
      );
    },
  );
}
