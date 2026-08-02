// Jeeber feed — PERIODIC POLL ELIMINATED (b02, POLLING-ELIMINATION-PLAN A.1).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';

/// Far longer than any cadence this repository ever shipped (60 s), and longer
/// than the 5-minute device observation window the DoD mandates.
const _idleWindow = Duration(hours: 1);

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
    'FOREGROUND + INTERESTED + one hour of virtual time ⇒ ZERO network calls',
    () {
      FakeAsync().run((async) {
        final dio = _CountingDio();
        final gate = ManualAppLifecycleGate();
        gate.setForeground(true);
        final repository = DioRequestFeedRepository(dio: dio);
        final owner = Object();

        // The worst case for the mandate: the surface is open, the app is
        repository.addPollInterest(owner);
        async.elapse(_idleWindow);

        expect(
          dio.getCount,
          0,
          reason:
              'declaring interest must arm NOTHING. A non-zero count here is '
              'the 60s safety-net poll back from the dead (JEBV4-342).',
        );

        unawaited(repository.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'POSITIVE CONTROL: refresh() still issues exactly one GET, and only one',
    () {
      // Zero calls plus a dead repository is not success, it is a removed
      FakeAsync().run((async) {
        final dio = _CountingDio();
        final repository = DioRequestFeedRepository(dio: dio);
        final owner = Object();

        repository.addPollInterest(owner);
        expect(dio.getCount, 0);

        unawaited(repository.refresh());
        async.flushMicrotasks();
        expect(dio.getCount, 1, reason: 'the one-shot fetch must still fire');

        async.elapse(_idleWindow);
        expect(
          dio.getCount,
          1,
          reason: 'a one-shot fetch must not leave a cadence behind it',
        );

        unawaited(repository.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('backgrounding and resuming issue no calls of their own', () {
    FakeAsync().run((async) {
      final dio = _CountingDio();
      final gate = ManualAppLifecycleGate();
      final repository = DioRequestFeedRepository(dio: dio);
      final owner = Object();

      repository.addPollInterest(owner);
      gate.setForeground(false);
      async.elapse(_idleWindow);
      gate.setForeground(true);
      async.elapse(_idleWindow);

      expect(
        dio.getCount,
        0,
        reason:
            'the repository no longer observes the lifecycle at all — the '
            'resume refetch is one-shot and owned by FeedResumeRefetcher',
      );

      unawaited(repository.dispose());
      async.flushMicrotasks();
    });
  });
}
