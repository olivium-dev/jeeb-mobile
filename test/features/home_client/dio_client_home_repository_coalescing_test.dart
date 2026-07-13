// F3 (offers polling storm): the home load must COALESCE its reads so a
// steady-state customer session stays well under the per-subscription rate
// budget. These tests pin the two coalescing wins:
//   1. the `role=client` list is fetched ONCE and shared between the auction
//      buckets and the recent-deliveries strip — no duplicate same-cycle GET;
//   2. a candidate whose payload already reports an offer is NOT probed again
//      via `GET /v1/offers` (the probe can only raise a count that already
//      buckets it into Replies).

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

  void stub({required List<dynamic> requests}) {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      final query =
          invocation.namedArguments[#queryParameters] as Map<String, dynamic>?;
      if (path == '/deliveries') return _resp(path, {'shipments': <dynamic>[]});
      if (path == '/requests') return _resp(path, {'items': requests});
      if (path == '/v1/offers') {
        offerRequestIds.add(query?['requestId'] as String? ?? '');
        return _resp(path, {'items': <dynamic>[]});
      }
      return _resp(path, {'items': <dynamic>[]});
    });
  }

  test(
      'the role=client list is fetched ONCE per load — the recent-deliveries '
      'strip reuses it instead of issuing a second GET /requests', () async {
    stub(requests: [
      {'id': 'r-1', 'status': 'pending', 'title': 'Grocery run'},
    ]);

    await repo.loadSnapshot();

    // Capture every /requests query. Exactly one is the plain role=client read
    // (no `status`); the only other legitimate /requests call is the
    // status=active in-flight merge. The old code fired the role=client read
    // TWICE (pageSize 50 for buckets + pageSize 10 for recents).
    final requestCalls = verify(() => dio.get<dynamic>(
          '/requests',
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured.whereType<Map<String, dynamic>>();

    final roleOnlyCalls = requestCalls
        .where((qp) => qp['role'] == 'client' && qp['status'] == null)
        .toList();
    expect(roleOnlyCalls, hasLength(1),
        reason: 'role=client must be read exactly once, then shared');
  });

  test(
      'a candidate whose payload already reports an offer is NOT probed '
      '(skip-known reply — saves a GET /v1/offers)', () async {
    stub(requests: [
      // payload already carries offersCount > 0 → known reply.
      {'id': 'r-known', 'status': 'pending', 'offersCount': 2, 'title': 'Known'},
      // payload has no offer indicator → must be probed.
      {'id': 'r-unknown', 'status': 'pending', 'title': 'Unknown'},
    ]);

    final snapshot = await repo.loadSnapshot();

    expect(offerRequestIds, contains('r-unknown'));
    expect(offerRequestIds, isNot(contains('r-known')),
        reason: 'a payload-known reply must not trigger a probe');

    // The known-reply row still surfaces in Replies with its payload count.
    final known = snapshot.replies.where((r) => r.id == 'r-known');
    expect(known, hasLength(1));
    expect(known.single.status, ClientRequestStatus.offersReceived);
    expect(known.single.offerCount, 2);
  });
}
