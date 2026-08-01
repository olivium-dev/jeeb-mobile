import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

/// MB1 — THE TRAILING-EDGE DROPPED PUSH.
///
/// Ported from `b05/mb1@0ad2752` onto the current main line. The commit could
/// not be cherry-picked: the drop it repaired sat on a latch
/// (`_positionReadInFlight`) that only ever existed on `b05/mb1`. On this line
/// the SAME defect lives one layer up, on `_statusReadInFlight` in
/// `_refreshFromPush`, which returned outright when a push landed inside another
/// push's round trip.
///
/// Why that is a correctness bug rather than a throttle: this transport has NO
/// cadence. With a poll, a dropped edge is repaired by the next tick. Here
/// nothing repairs it — the row and the courier marker stay at the pre-push
/// snapshot until some later, unrelated event happens to arrive, and the
/// `cause:"push"` breadcrumb that MB1's V-2 contract counts disappears with it,
/// so the capture reads as "no push arrived".
///
/// Both legs below are POSITIVE controls for the coalesce. Their matching
/// NEGATIVE control is `tool/mb1/neg-control-dropped-edge.sh`, which strips the
/// coalesce out of the source and re-runs this file expecting RED.
class _GatedTrackingRepository
    implements LiveTrackingRepository, LivePositionSource {
  /// One gate per status read, opened by the test. A status read that has no
  /// gate yet creates one, so the test can always reach in and hold it.
  final List<Completer<void>> statusGates = [];

  /// Consumed one per position read; the courier is at a NEW place each time,
  /// which is what makes a dropped edge visible as a frozen marker.
  final List<GpsPoint> positions = const [
    GpsPoint(lat: 1.0, lng: 1.0),
    GpsPoint(lat: 2.0, lng: 2.0),
    GpsPoint(lat: 3.0, lng: 3.0),
    GpsPoint(lat: 4.0, lng: 4.0),
  ];

  int statusReads = 0;
  int positionReads = 0;

  /// Gate n, creating it if the test is asking ahead of the read.
  Completer<void> gate(int n) {
    while (statusGates.length <= n) {
      statusGates.add(Completer<void>());
    }
    return statusGates[n];
  }

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    final n = statusReads++;
    await gate(n).future;
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const {},
      lifecycle: TrackingLifecycle.active,
    );
  }

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    final n = positionReads++;
    return DeliveryLivePosition(
      jeeberPosition:
          positions[n < positions.length ? n : positions.length - 1],
    );
  }
}

/// Lets the microtask/event queue drain without introducing wall-clock waits.
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('MB1 — the dropped push edge is coalesced, not discarded', () {
    test(
        'POSITIVE CONTROL: a push landing inside another push round trip is '
        'healed, and the marker reaches the courier\'s newest position',
        () async {
      final repo = _GatedTrackingRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-DROP-EDGE',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);

      // --- screen open: status read 0, position read 0 -> marker at (1,1).
      repo.gate(0).complete();
      await _settle();
      expect(repo.statusReads, 1, reason: 'screen open reads the row once');
      expect(repo.positionReads, 1);
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 1.0, lng: 1.0));

      // --- push A: enters _refreshFromPush, takes the single-flight latch and
      //     blocks on gate 1.
      bus.add(null);
      await _settle();
      expect(repo.statusReads, 2, reason: 'push A started a read');
      expect(repo.positionReads, 1,
          reason: 'push A is still inside its status round trip');

      // --- push B lands INSIDE push A's round trip. This is the edge that the
      //     pre-fix code dropped on the floor.
      bus.add(null);
      await _settle();
      expect(repo.statusReads, 2,
          reason: 'still single-flighted: B must not start a second read now');

      // --- release push A. Its position read consumes (2,2).
      repo.gate(1).complete();
      await _settle();
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 2.0, lng: 2.0));

      // --- and now the coalesced trailing edge for push B must drain, all by
      //     itself, with no clock and no further external event.
      repo.gate(2).complete();
      await _settle();

      expect(repo.statusReads, 3,
          reason: 'the deferred push B edge was replayed, not discarded');
      expect(repo.positionReads, 3);
      expect(
        cubit.state.trackingInfo?.jeeberPosition,
        const GpsPoint(lat: 3.0, lng: 3.0),
        reason:
            'PRE-FIX this is stuck at (2,2) forever: push B was dropped and no '
            'cadence exists to heal it. That frozen marker IS the bug.',
      );
    });

    test(
        'POSITIVE CONTROL: two causes contending for ONE position read are '
        'serialised and the loser is coalesced, not dropped (the 0ad2752 case, '
        'at the position latch)', () async {
      final repo = _GatedTrackingRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-POS-LATCH',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);

      // Screen open completes first, which is what ARMS the push bus.
      repo.gate(0).complete();
      await _settle();
      expect(repo.statusReads, 1);
      expect(repo.positionReads, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

      // `retry()` is NOT covered by `_statusReadInFlight` — deliberately, it is
      // a user action. So a push landing inside a retry round trip really does
      // produce two concurrent `_readLivePosition` calls. Without the latch the
      // two network reads race and the OLDER snapshot can emit last, walking the
      // marker backwards.
      cubit.retry();
      await _settle();
      bus.add(null);
      await _settle();
      expect(repo.statusReads, 3, reason: 'retry and push both started a read');

      repo.gate(1).complete();
      repo.gate(2).complete();
      await _settle();

      expect(repo.positionReads, 3,
          reason:
              'one read served the winner, the loser was coalesced onto the '
              'trailing edge and replayed — neither was dropped');
      expect(
        cubit.state.trackingInfo?.jeeberPosition,
        const GpsPoint(lat: 3.0, lng: 3.0),
        reason:
            'the marker ends on the NEWEST snapshot served. Un-latched, a stale '
            'read can land after a fresher one and walk the marker backwards.',
      );
    });

    test('NO NEW CADENCE: coalescing arms zero timers', () {
      fakeAsync((async) {
        final repo = _GatedTrackingRepository();
        final bus = StreamController<void>.broadcast();

        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-NO-CADENCE',
          refreshSignals: bus.stream,
        );

        repo.gate(0).complete();
        async.flushMicrotasks();
        bus.add(null);
        async.flushMicrotasks();
        bus.add(null);
        async.flushMicrotasks();
        repo.gate(1).complete();
        repo.gate(2).complete();
        async.flushMicrotasks();

        expect(async.periodicTimerCount, 0,
            reason: 'the coalesce is a trailing edge, never a cadence');
        expect(async.nonPeriodicTimerCount, 0);

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });
  });
}
