// Jeeber feed — PERIODIC POLL ELIMINATED (b02, POLLING-ELIMINATION-PLAN A.1).
//
// This file used to assert the SHAPE of a 60 s safety-net poll: that it ticked
// 6× per virtual minute at a 10 s cadence, stopped while backgrounded, and
// re-armed on resume. That poll is deleted, so those assertions are inverted
// here rather than removed — an assertion that a cadence is ABSENT is the only
// one that can catch its accidental return, and deleting the file would leave
// nothing watching the seam.
//
// The owner's rule (POLLING-ELIMINATION-PLAN §0): *if the user does nothing and
// no push arrives, a second network call is banned.* Virtual time is the honest
// instrument for that — `FakeAsync` cannot be fooled by a slow test host, and a
// re-added `Timer.periodic` fires under it exactly as it would on a device.

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
        // foreground, and a consumer has declared interest. Under the old
        // build this state ticked every 60 s forever.
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
      // feature. This proves the counting Dio is wired and the one-shot path
      // — the path `start()`, `FeedResumeRefetcher` and the `new_request`
      // push all funnel into — still reaches the network.
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
