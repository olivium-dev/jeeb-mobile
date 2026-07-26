import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';

const _pollInterval = Duration(seconds: 10);
const _testWindow = Duration(seconds: 60);

class _CountingDio extends Fake implements Dio {
  int getCount = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getCount++;
    return Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: const <String, Object>{'items': <Object>[], 'totalCount': 0},
        )
        as Response<T>;
  }
}

void main() {
  test(
    'AC2a: backgrounded for 60s of virtual time issues ZERO network calls and cancels the timer',
    () {
      FakeAsync().run((async) {
        final dio = _CountingDio();
        final gate = ManualAppLifecycleGate();
        final repository = DioRequestFeedRepository(
          dio: dio,
          pollInterval: _pollInterval,
          lifecycleGate: gate,
        );
        final owner = Object();

        repository.addPollInterest(owner);
        async.elapse(_testWindow);
        expect(dio.getCount, 6);

        final backgroundBaseline = dio.getCount;
        gate.setForeground(false);
        async.elapse(_testWindow);
        expect(dio.getCount - backgroundBaseline, 0);

        expect(repository.debugIsPolling, isFalse);

        final resumeBaseline = dio.getCount;
        gate.setForeground(true);
        expect(
          dio.getCount,
          resumeBaseline,
          reason:
              'resume itself must fetch nothing '
              '(tickOnResume defaults false)',
        );
        async.elapse(_testWindow);
        expect(dio.getCount - resumeBaseline, 6);

        unawaited(repository.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'E2c: refresh() while paused issues exactly one GET and does not arm the poll',
    () {
      FakeAsync().run((async) {
        final dio = _CountingDio();
        final gate = ManualAppLifecycleGate();
        final repository = DioRequestFeedRepository(
          dio: dio,
          pollInterval: _pollInterval,
          lifecycleGate: gate,
        );
        final owner = Object();

        repository.addPollInterest(owner);
        gate.setForeground(false);
        final pausedBaseline = dio.getCount;

        unawaited(repository.refresh());
        async.flushMicrotasks();
        expect(dio.getCount - pausedBaseline, 1);
        expect(repository.debugIsPolling, isFalse);

        async.elapse(_testWindow);
        expect(dio.getCount - pausedBaseline, 1);

        unawaited(repository.dispose());
        async.flushMicrotasks();
      });
    },
  );
}
