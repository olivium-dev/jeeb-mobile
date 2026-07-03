// G1 (sprint-009 P0) — the waiting screen's request row parse must carry the
// customer's request content. `GET /v1/requests/:id` returns the `description`
// the compose flow POSTed (verified against JeebRequestsController: the
// create requires a non-blank Description and the read echoes it); a dedicated
// short `title` wins when the gateway mints one.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/data/dio_waiting_repository.dart';

/// Stub Dio serving canned bodies per path prefix (request row + offers list).
class _FakeDio extends Fake implements Dio {
  _FakeDio({required this.requestBody});

  final Map<String, dynamic> requestBody;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final body = path.startsWith('/v1/requests/')
        ? requestBody
        : <String, dynamic>{'offers': <dynamic>[]};
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body as T,
    );
  }
}

void main() {
  group('DioWaitingRepository — G1 request-content parse', () {
    test('falls back to the wire `description` when no title is minted',
        () async {
      final repo = DioWaitingRepository(_FakeDio(requestBody: const {
        'id': 'req-1',
        'status': 'pending',
        'description': '2 shawarma + cola from Barbar',
      }));

      final waiting = await repo.fetchWaiting('req-1');

      expect(waiting.title, '2 shawarma + cola from Barbar',
          reason: 'the customer\'s own words must reach the waiting screen');
    });

    test('a dedicated short `title` wins over the description', () async {
      final repo = DioWaitingRepository(_FakeDio(requestBody: const {
        'id': 'req-1',
        'status': 'pending',
        'title': 'Barbar order',
        'description': '2 shawarma + cola from Barbar',
      }));

      final waiting = await repo.fetchWaiting('req-1');

      expect(waiting.title, 'Barbar order');
    });

    test('title stays null when the row carries neither field', () async {
      final repo = DioWaitingRepository(_FakeDio(requestBody: const {
        'id': 'req-1',
        'status': 'pending',
      }));

      final waiting = await repo.fetchWaiting('req-1');

      expect(waiting.title, isNull);
    });
  });
}
