import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_state.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';

/// b02 wave C — N9. The waiting / no-coverage screen ran an UNG
class _FakeWaitingRepository implements WaitingRepository {
  _FakeWaitingRepository({this.phase = WaitingRequestPhase.broadcasting});

  WaitingRequestPhase phase;

  int offerCount = 0;
  int fetchWaitingCount = 0;
  int fetchRequestCount = 0;
  int fetchOfferCountCount = 0;

  WaitingRequest _build() => WaitingRequest(
    requestId: 'req-1',
    phase: phase,
    notifiedCount: 4,
    offerCount: offerCount,
    receivedAt: DateTime.utc(2026, 7, 26, 12),
    remainingAtReceipt: const Duration(minutes: 5),
  );

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    fetchWaitingCount++;
    return _build();
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async {
    fetchRequestCount++;
    return _build();
  }

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) async {
    fetchOfferCountCount++;
    return offerCount;
  }
}

void main() {
  group('N9 waiting — push-driven, no wall-clock poll', () {
    test('a push on the refresh bus triggers exactly one re-read', () async {
      final repo = _FakeWaitingRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        refreshSignals: bus.stream,
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(
        repo.fetchWaitingCount,
        0,
        reason: 'the cold load uses fetchRequest, not fetchWaiting',
      );
      expect(cubit.debugPushRefreshWired, isTrue);

      repo.offerCount = 1;
      repo.phase = WaitingRequestPhase.offersArrived;
      bus.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(repo.fetchWaitingCount, 1, reason: 'one push → one re-read');
      expect(cubit.state.request?.phase, WaitingRequestPhase.offersArrived);
    });

    test('no push ⇒ no read after 30 virtual seconds, but the countdown still '
        'ticks', () {
      fakeAsync((async) {
        final repo = _FakeWaitingRepository();
        final clock = StreamController<void>.broadcast();
        final cubit = WaitingCubit(
          repository: repo,
          requestId: 'req-1',
          refreshSignals: const Stream<void>.empty(),
          clockTicks: clock.stream,
        );
        cubit.load();
        async.flushMicrotasks();
        final coldRequestReads = repo.fetchRequestCount;

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(
          repo.fetchWaitingCount,
          0,
          reason: 'the ungated 5s poll must be GONE',
        );
        expect(
          repo.fetchRequestCount,
          coldRequestReads,
          reason: 'no extra request reads either',
        );

        final before = cubit.state.now;
        clock.add(null);
        async.flushMicrotasks();
        expect(
          cubit.state.now,
          isNot(before),
          reason: 'the 1s countdown tick is NOT a poll and must survive',
        );
        expect(repo.fetchWaitingCount, 0);

        cubit.close();
        clock.close();
      });
    });

    test('a terminal phase (expired) retires the subscription', () async {
      final repo = _FakeWaitingRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        refreshSignals: bus.stream,
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.debugPushRefreshWired, isTrue);

      repo.phase = WaitingRequestPhase.expired;
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchWaitingCount, 1);
      expect(cubit.state.request?.phase, WaitingRequestPhase.expired);
      expect(cubit.debugPushRefreshWired, isFalse);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(
        repo.fetchWaitingCount,
        1,
        reason: 'a dead request takes no further reads',
      );
    });

    test(
      'a cold load that already reads a terminal phase never arms the bus',
      () async {
        final repo = _FakeWaitingRepository(phase: WaitingRequestPhase.expired);
        final bus = StreamController<void>.broadcast();
        addTearDown(bus.close);

        final cubit = WaitingCubit(
          repository: repo,
          requestId: 'req-1',
          refreshSignals: bus.stream,
          clockTicks: const Stream<void>.empty(),
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.status, WaitingScreenStatus.loaded);
        expect(cubit.debugPushRefreshWired, isFalse);
      },
    );
  });
}
