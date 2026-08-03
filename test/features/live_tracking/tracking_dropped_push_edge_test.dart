import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

/// MB1 — THE TRAILING-EDGE DROPPED PUSH.
class _GatedTrackingRepository
    implements LiveTrackingRepository, LivePositionSource {
  /// One gate per status read, opened by the test. A status read that has no
  final List<Completer<void>> statusGates = [];

  /// Consumed one per position read; the courier is at a NEW place each time,
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

      repo.gate(0).complete();
      await _settle();
      expect(repo.statusReads, 1, reason: 'screen open reads the row once');
      expect(repo.positionReads, 1);
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 1.0, lng: 1.0));

      bus.add(null);
      await _settle();
      expect(repo.statusReads, 2, reason: 'push A started a read');
      expect(repo.positionReads, 1,
          reason: 'push A is still inside its status round trip');

      bus.add(null);
      await _settle();
      expect(repo.statusReads, 2,
          reason: 'still single-flighted: B must not start a second read now');

      repo.gate(1).complete();
      await _settle();
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 2.0, lng: 2.0));

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

      repo.gate(0).complete();
      await _settle();
      expect(repo.statusReads, 1);
      expect(repo.positionReads, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

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
