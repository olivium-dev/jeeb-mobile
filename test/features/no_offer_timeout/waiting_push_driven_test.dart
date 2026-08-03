import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_state.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';

/// b02 wave C — N9. The waiting / no-coverage screen ran an UNGATED 5s poll of
/// `GET /v1/requests/{id}` + `GET /v1/offers?requestId` (`fetchWaiting` fans ONE
/// call into TWO reads: `dio_waiting_repository.dart:49` → `:70` and → `:87`).
/// Two gateway pushes already cover everything that poll was watching for:
///
///  * `type=offer` — a bid arrived → flip to the review-offers CTA (AC2).
///    Emitted at `Notifications/OfferPushNotifier.cs:227`.
///  * `type=request_expired` / `type=try_expand_tier` — the request timed out or
///    is expanding its tier. Emitted at
///    `Requests/DispatchingRequestExpiryNotifier.cs:112` (both carry
///    `requestId` + `request_id`).
///
/// Both land on the SAME payload-less `PushRefreshSignals` bus, so the
/// subscriber needs no discriminator: it re-pulls its own snapshot.
///
/// The 1s COUNTDOWN tick is deliberately untouched. It is a LOCAL timer that
/// only advances `now` so the countdown widget rebuilds; it issues zero gateway
/// reads, and removing it would break the UI while saving no traffic.
class _FakeWaitingRepository implements WaitingRepository {
  _FakeWaitingRepository({this.phase = WaitingRequestPhase.broadcasting});

  WaitingRequestPhase phase;

  // Mutable FIELD, not a constructor parameter: the tests flip it mid-run and
  // none seeds it, and a never-supplied optional parameter is an
  // `unused_element_parameter` warning, which CI treats as fatal.
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

      // An inbound `type=offer` push: the bid is now visible to the server.
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

        // The LOCAL countdown timer is untouched — it advances `now` and does
        // not touch the gateway.
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

      // The `type=request_expired` push lands and the snapshot confirms it.
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
