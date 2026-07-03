// cycle-4 P0 fix — customer cancellations must actually reach the server.
//
// The old repo POSTed the mock-era `/v1/delivery/cancel` (404s on the real
// gateway) and SWALLOWED 404/422, so the UI pretended success while the
// request stayed live server-side. These tests pin the corrected contract:
//
//   1. Verb + path: DELETE /v1/requests/{id} (request-keyed cancel,
//      requestId == deliveryId convention) — never the dead POST.
//   2. Typed mapping: 409 → conflict, 404 → notFound, 403 → forbidden,
//      connection/timeout → network, 5xx/other → unknown.
//   3. NO swallowing: every non-2xx throws — a failing cancel MUST surface.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/cancel_request/data/dio_cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart';

/// Stub Dio that records the last DELETE call and throws/returns on demand.
/// Also traps any POST so a regression back to `/v1/delivery/cancel` fails
/// loudly instead of silently passing.
class _FakeDio extends Fake implements Dio {
  String? lastDeletePath;
  int deleteCalls = 0;
  DioException? nextError;

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    deleteCalls++;
    lastDeletePath = path;
    final err = nextError;
    if (err != null) throw err;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 204,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    fail('Cancel must not POST (got POST $path) — the mock-era '
        '/v1/delivery/cancel path is dead. Use DELETE /v1/requests/{id}.');
  }
}

DioException _status(int code) => DioException(
      requestOptions: RequestOptions(path: '/v1/requests/req-1'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/v1/requests/req-1'),
        statusCode: code,
      ),
      type: DioExceptionType.badResponse,
    );

DioException _transport(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/v1/requests/req-1'),
      type: type,
    );

void main() {
  late _FakeDio dio;
  late DioCancelRequestRepository repo;

  setUp(() {
    dio = _FakeDio();
    repo = DioCancelRequestRepository(dio);
  });

  group('verb + path contract', () {
    test('cancel DELETEs /v1/requests/{id} — request-keyed, no POST body',
        () async {
      await repo.cancelRequest(requestId: 'req-client-001');

      expect(dio.deleteCalls, 1);
      expect(dio.lastDeletePath, '/v1/requests/req-client-001');
      expect(dio.lastDeletePath, isNot(contains('/v1/delivery/cancel')));
    });

    test('request id is URI-encoded into the path', () async {
      await repo.cancelRequest(requestId: 'req/../evil');

      expect(dio.lastDeletePath, '/v1/requests/${Uri.encodeComponent('req/../evil')}');
    });
  });

  group('typed failure mapping — nothing is swallowed', () {
    Future<CancelRequestFailure> failureFor(DioException e) async {
      dio.nextError = e;
      try {
        await repo.cancelRequest(requestId: 'req-1');
        fail('cancelRequest must throw when the server did not confirm');
      } on CancelRequestException catch (ex) {
        return ex.failure;
      }
    }

    test('409 → conflict (no longer cancellable)', () async {
      expect(await failureFor(_status(409)), CancelRequestFailure.conflict);
    });

    test('404 → notFound (regression: used to be silently swallowed)',
        () async {
      expect(await failureFor(_status(404)), CancelRequestFailure.notFound);
    });

    test('403 → forbidden', () async {
      expect(await failureFor(_status(403)), CancelRequestFailure.forbidden);
    });

    test('connection error / timeouts → network (retryable)', () async {
      expect(
        await failureFor(_transport(DioExceptionType.connectionError)),
        CancelRequestFailure.network,
      );
      expect(
        await failureFor(_transport(DioExceptionType.connectionTimeout)),
        CancelRequestFailure.network,
      );
      expect(
        await failureFor(_transport(DioExceptionType.receiveTimeout)),
        CancelRequestFailure.network,
      );
    });

    test('500 → unknown (regression: soft-failures used to fake success)',
        () async {
      expect(await failureFor(_status(500)), CancelRequestFailure.unknown);
    });
  });
}
