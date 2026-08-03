// Lane C (PR-C1) — terminal-safe bucketing on the customer home.

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

  setUp(() {
    dio = _MockDio();
    repo = DioClientHomeRepository(dio);
  });

  void stub({
    List<dynamic> shipments = const [],
    List<dynamic> requests = const [],
    List<dynamic> offers = const [],
  }) {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/deliveries') return _resp(path, {'shipments': shipments});
      if (path == '/requests') return _resp(path, {'items': requests});
      if (path == '/v1/offers') return _resp(path, {'items': offers});
      return _resp(path, {'items': <dynamic>[]});
    });
  }

  group('terminal requests are history — never Pending/Replies', () {
    for (final status in const ['cancelled', 'expired', 'Cancelled', 'DELIVERED']) {
      test('a $status request is dropped from every auction bucket', () async {
        stub(requests: [
          {
            'id': 'r-term',
            'status': status,
            'offersCount': 0,
            'title': 'Terminal request',
          },
        ]);

        final snapshot = await repo.loadSnapshot();

        expect(snapshot.pending.where((r) => r.id == 'r-term'), isEmpty,
            reason: '$status must not land in Pending');
        expect(snapshot.replies.where((r) => r.id == 'r-term'), isEmpty,
            reason: '$status must not land in Replies');
        expect(snapshot.inProgress.where((r) => r.id == 'r-term'), isEmpty,
            reason: '$status must not land in In Progress');
      });
    }

    test('a terminal request does not re-arm Replies even with a live offer',
        () async {
      stub(
        requests: [
          {'id': 'r-expired', 'status': 'expired', 'title': 'Expired'},
        ],
        offers: [
          {'id': 'o-1', 'status': 'pending'},
        ],
      );

      final snapshot = await repo.loadSnapshot();
      expect(snapshot.replies.where((r) => r.id == 'r-expired'), isEmpty);
      expect(snapshot.pending.where((r) => r.id == 'r-expired'), isEmpty);
    });
  });

  group('in-flight requests → In Progress with a mapped stage', () {
    test('an in_transit request surfaces In Progress as enRoute (not Pending)',
        () async {
      stub(requests: [
        {
          'id': 'r-live',
          'status': 'in_transit',
          'title': 'On the road',
          'conversationId': 'conv-live',
        },
      ]);

      final snapshot = await repo.loadSnapshot();
      final row = snapshot.inProgress.where((r) => r.id == 'r-live');
      expect(row, hasLength(1));
      expect(row.single.status, ClientRequestStatus.enRoute);
      expect(snapshot.pending.where((r) => r.id == 'r-live'), isEmpty);
      expect(snapshot.replies.where((r) => r.id == 'r-live'), isEmpty);
    });

    test('a Picked request surfaces In Progress as atPickup', () async {
      stub(requests: [
        {'id': 'r-picked', 'status': 'Picked', 'title': 'Picked up'},
      ]);

      final snapshot = await repo.loadSnapshot();
      final row = snapshot.inProgress.where((r) => r.id == 'r-picked');
      expect(row, hasLength(1));
      expect(row.single.status, ClientRequestStatus.atPickup);
    });
  });

  group('cancelled shipments drop out of In Progress like delivered', () {
    test('a Cancelled shipment is not in the active In Progress list',
        () async {
      stub(shipments: [
        {
          'id': 'dlv-cancelled',
          'currentStage': 'Cancelled',
          'title': 'Cancelled run',
          'dropoff': {'address': 'Verdun'},
        },
      ]);

      final snapshot = await repo.loadSnapshot();
      expect(snapshot.inProgress.where((r) => r.id == 'dlv-cancelled'), isEmpty);
    });
  });
}
