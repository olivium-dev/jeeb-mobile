// §7-13 (j): accept/decline are non-idempotent POSTs that this lane now lets
// the jeeber RETRY by hand — each act must carry a stable Idempotency-Key.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/data/dio_prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';

class _KeyRecordingAdapter implements HttpClientAdapter {
  int postStatus = 204;
  final List<String> paths = <String>[];
  final List<String?> keys = <String?>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    keys.add(options.headers['Idempotency-Key'] as String?);
    if (postStatus >= 400) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<void>(
          requestOptions: options,
          statusCode: postStatus,
        ),
      );
    }
    return ResponseBody.fromString('', postStatus);
  }
}

void main() {
  late _KeyRecordingAdapter adapter;
  late Dio dio;
  late DioRequestFeedRepository repo;

  setUp(() {
    adapter = _KeyRecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    repo = DioRequestFeedRepository(dio: dio);
  });

  tearDown(() async => repo.dispose());

  test('accept carries an Idempotency-Key', () async {
    await repo.accept('r1');

    expect(adapter.keys.single, isNotNull);
    expect(adapter.keys.single, isNotEmpty);
  });

  test('a RETRIED accept replays the SAME key, never a second mutation',
      () async {
    adapter.postStatus = 500;
    await expectLater(repo.accept('r1'), throwsA(isA<ServerFailure>()));
    adapter.postStatus = 204;
    await repo.accept('r1');

    expect(adapter.keys, hasLength(2));
    expect(adapter.keys.first, adapter.keys.last);
  });

  test('decline keys are its own, and a settled act mints a fresh one',
      () async {
    adapter.postStatus = 500;
    await expectLater(repo.decline('r1'), throwsA(isA<ServerFailure>()));
    adapter.postStatus = 204;
    await repo.decline('r1');
    final String settled = adapter.keys.last!;

    await repo.accept('r1');
    expect(adapter.keys.last, isNot(settled));

    await repo.decline('r2');
    expect(adapter.keys.last, isNot(settled));
  });

  test('a 409 settles the accept: the next act is a NEW mutation', () async {
    adapter.postStatus = 409;
    await repo.accept('r1');
    final String taken = adapter.keys.last!;

    adapter.postStatus = 204;
    await repo.accept('r1');
    expect(adapter.keys.last, isNot(taken));
  });

  test('the prohibited-item report carries a key too', () async {
    final service = DioProhibitedItemReportService(dio);
    await service.report(requestId: 'r1', reason: 'weapon');

    expect(adapter.paths.single, '/v1/requests/r1/report');
    expect(adapter.keys.single, isNotNull);
  });
}
