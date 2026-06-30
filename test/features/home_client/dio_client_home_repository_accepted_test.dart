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
    // No live shipments; one accepted order + one reply + one pending request.
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/deliveries') return _resp(path, {'shipments': <dynamic>[]});
      if (path == '/requests') {
        return _resp(path, {
          'items': [
            {
              'id': 'r-acc',
              'status': 'accepted',
              'offersCount': 0,
              'conversationId': 'conv-1',
              'title': 'Two-device chat verify',
            },
            {'id': 'r-rep', 'offersCount': 3, 'title': 'Pharmacy run'},
            {'id': 'r-pen', 'offersCount': 0, 'title': 'Grocery run'},
          ],
        });
      }
      return _resp(path, {'items': <dynamic>[]});
    });
  });

  test('accepted request surfaces in In Progress with accepted status + chat id', () async {
    final snapshot = await repo.loadSnapshot();

    final inProgress = snapshot.inProgress.where((r) => r.id == 'r-acc');
    expect(inProgress, hasLength(1));
    expect(inProgress.single.status, ClientRequestStatus.accepted);
    expect(inProgress.single.conversationId, 'conv-1');
  });

  test('accepted request is NOT in Pending (no dead Expired card) nor Replies', () async {
    final snapshot = await repo.loadSnapshot();

    expect(snapshot.pending.where((r) => r.id == 'r-acc'), isEmpty);
    expect(snapshot.replies.where((r) => r.id == 'r-acc'), isEmpty);
  });

  test('non-accepted rows still partition into Replies (offers>0) and Pending', () async {
    final snapshot = await repo.loadSnapshot();

    expect(snapshot.replies.map((r) => r.id), contains('r-rep'));
    expect(snapshot.pending.map((r) => r.id), contains('r-pen'));
  });

  test('with no accepted rows the prior buckets are unchanged', () async {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/requests') {
        return _resp(path, {
          'items': [
            {'id': 'r-rep', 'offersCount': 3},
            {'id': 'r-pen', 'offersCount': 0},
          ],
        });
      }
      return _resp(path, {'items': <dynamic>[]});
    });

    final snapshot = await repo.loadSnapshot();

    expect(snapshot.inProgress, isEmpty);
    expect(snapshot.replies.map((r) => r.id), contains('r-rep'));
    expect(snapshot.pending.map((r) => r.id), contains('r-pen'));
  });
}
