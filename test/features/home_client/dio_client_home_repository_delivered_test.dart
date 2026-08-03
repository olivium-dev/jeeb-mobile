// BUG / Core Flow step 7: a delivery that reached V3 `Done` must surface as the

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

  void stub({required List<dynamic> shipments, required List<dynamic> requests}) {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/deliveries') return _resp(path, {'shipments': shipments});
      if (path == '/requests') return _resp(path, {'items': requests});
      return _resp(path, {'items': <dynamic>[]});
    });
  }

  test('a Done shipment maps to the delivered terminal status, NOT accepted',
      () async {
    stub(
      shipments: [
        {
          'id': 'dlv-done',
          'currentStage': 'Done',
          'title': 'Completed run',
          'dropoff': {'address': 'Verdun'},
        },
      ],
      requests: const [],
    );

    final snapshot = await repo.loadSnapshot();

    // The completed delivery is NOT in the active "In Progress" list (it has
    expect(
      snapshot.inProgress.where((r) => r.id == 'dlv-done'),
      isEmpty,
      reason: 'a Done/delivered shipment must not linger in In Progress',
    );
  });

  test('an in-flight (InTransit) shipment still shows in In Progress', () async {
    stub(
      shipments: [
        {
          'id': 'dlv-live',
          'currentStage': 'InTransit',
          'title': 'On the road',
          'dropoff': {'address': 'Hamra'},
        },
      ],
      requests: const [],
    );

    final snapshot = await repo.loadSnapshot();
    final row = snapshot.inProgress.where((r) => r.id == 'dlv-live');
    expect(row, hasLength(1));
    expect(row.single.status, ClientRequestStatus.enRoute);
  });

  test('accepted request stays In Progress (accepted == In Progress lesson)',
      () async {
    stub(
      shipments: const [],
      requests: [
        {
          'id': 'r-acc',
          'status': 'accepted',
          'offersCount': 0,
          'conversationId': 'conv-1',
          'title': 'Accepted, no shipment yet',
        },
      ],
    );

    final snapshot = await repo.loadSnapshot();
    final row = snapshot.inProgress.where((r) => r.id == 'r-acc');
    expect(row, hasLength(1));
    expect(row.single.status, ClientRequestStatus.accepted);
    expect(snapshot.pending.where((r) => r.id == 'r-acc'), isEmpty);
  });
}
