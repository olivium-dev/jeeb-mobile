import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

/// b02 wave C — N7. The customer live-tracking screen ran ONE 5s poll serving
/// TWO different data needs, and that conflation is why it was a poll at all:
///
///  * STATUS transitions are EVENTS. A `type=delivery` push already carries
///    them, to `req.ClientId` among the recipients
///    (`Controllers/DeliveriesController.cs:1296-1300` →
///    `Notifications/DeliveryStatusPushNotifier.cs:211`). That axis is now the
///    push bus below, and it retires `GET /v1/deliveries/{id}`.
///  * The courier POSITION rides `GET /deliveries/{id}/tracking`, read on the
///    SAME events. It used to ride an SSE stream on a `geo` alias route;
///    jeeb-gateway #333 (`b6fe888`) deleted that route (guard
///    `Sse_Alias_Route_Is_Gone`), the customer 404ed on it for four days, and
///    the marker never rendered — the courier-marker P0. → `LivePositionSource`.
///
/// Also preserved: this cubit deliberately NEVER reads `GET /otp` — on the live
/// gateway that endpoint TRIGGERS AN SMS, so polling it would text the recipient
/// every few seconds. The hand-over code comes from local persistence only.
class _FakeTrackingRepository
    implements LiveTrackingRepository, LivePositionSource {
  _FakeTrackingRepository({
    required this.stages,
    this.lifecycle = TrackingLifecycle.active,
  });

  final TrackingLifecycle lifecycle;

  /// Consumed one per `fetchDeliveryStatus`; the last value repeats.
  List<TrackingStage> stages;
  int statusReads = 0;

  /// Every position read this repo served, so a test can assert the count is
  /// driven by EVENTS and never by a clock.
  int positionReads = 0;

  /// Handed back on the next position read; set by a test to move the courier.
  DeliveryLivePosition? nextPosition;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    final stage =
        stages[statusReads < stages.length ? statusReads : stages.length - 1];
    statusReads++;
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: stage,
      stageTimestamps: const {},
      lifecycle: lifecycle,
    );
  }

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    positionReads++;
    return nextPosition;
  }
}

void main() {
  group('N7 status axis — push, not poll', () {
    test('a delivery push re-reads the status exactly once', () async {
      final repo =
          _FakeTrackingRepository(stages: [TrackingStage.picked, TrackingStage.inTransit]);
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(repo.statusReads, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.statusReads, 2, reason: 'one push → one status read');
      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
    });

    test('no push ⇒ no status read after 60 virtual seconds', () {
      fakeAsync((async) {
        final repo = _FakeTrackingRepository(stages: [TrackingStage.inTransit]);
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-N7',
          refreshSignals: const Stream<void>.empty(),
        );
        async.flushMicrotasks();
        expect(repo.statusReads, 1);

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(repo.statusReads, 1,
            reason: 'the 5s LifecyclePoller must be GONE');
        cubit.close();
      });
    });

    test('a delivered push still fires the receipt auto-advance', () async {
      final repo = _FakeTrackingRepository(
          stages: [TrackingStage.atDoor, TrackingStage.delivered]);
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(
        cubit.state.pendingEvent,
        LiveTrackingEvent.deliveredAutoAdvance,
        reason: 'JM-032 AC2: the delivered transition is what auto-advances to '
            'the receipt prompt. If the push does not drive the status read, '
            'this one-shot event never fires and the customer is stranded on a '
            'stale stepper with NO visible error.',
      );
      expect(cubit.debugPushRefreshWired, isFalse,
          reason: 'a delivered row is terminal — stop listening');
    });

    test('a terminal (cancelled) row retires the subscription', () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.ordered],
        lifecycle: TrackingLifecycle.cancelled,
      );
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.debugPushRefreshWired, isFalse);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.statusReads, 1, reason: 'a dead row takes no further reads');
    });
  });

  group('position axis — event-driven snapshot, not poll', () {
    test('reads the position on mount and again on each push', () async {
      final repo = _FakeTrackingRepository(
          stages: [TrackingStage.inTransit, TrackingStage.inTransit])
        ..nextPosition = const DeliveryLivePosition(
          jeeberPosition: GpsPoint(lat: 33.1, lng: 35.1),
          polyline: [GpsPoint(lat: 33.1, lng: 35.1)],
        );
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(repo.positionReads, 1, reason: 'the mount event reads once');
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.1);

      // The jeeber has moved; the next event picks it up.
      repo.nextPosition = const DeliveryLivePosition(
        jeeberPosition: GpsPoint(lat: 33.2, lng: 35.2),
      );
      bus.add(null);
      await pumpEventQueue();

      expect(repo.positionReads, 2, reason: 'one push → one position read');
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.2,
          reason: 'the marker MOVES when an event brings a newer fix');
    });

    test('no event ⇒ no position read after 60 virtual seconds', () {
      // The regression this file's status half already pins, now pinned for the
      // POSITION half too. It is not hypothetical: before this change the dead
      // SSE stream re-armed itself forever on a now-deleted backoff constant
      // (2 / 5 / 15 / 30 s, then saturating), so a screen sitting untouched
      // issued a request every 30 s — an "ERROR-RECOVERY" timer that had
      // silently become a permanent poll because the route it retried could
      // never succeed, and whose only reset site sat inside a frame handler a
      // dead route could never reach.
      fakeAsync((async) {
        final repo = _FakeTrackingRepository(stages: [TrackingStage.inTransit])
          ..nextPosition = const DeliveryLivePosition(
            jeeberPosition: GpsPoint(lat: 33.1, lng: 35.1),
          );
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-N7',
          refreshSignals: const Stream<void>.empty(),
        );
        async.flushMicrotasks();
        expect(repo.positionReads, 1);

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(repo.positionReads, 1,
            reason: 'no clock may drive the position axis');
        cubit.close();
      });
    });

    test('a position merge never re-fires the delivered/at-door navigation',
        () async {
      final repo = _FakeTrackingRepository(stages: [TrackingStage.atDoor])
        ..nextPosition = const DeliveryLivePosition(
          jeeberPosition: GpsPoint(lat: 33.3, lng: 35.3),
        );
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.3);
      expect(cubit.state.pendingEvent, LiveTrackingEvent.none,
          reason: 'the position merge carries NO pendingEvent (copyWith resets '
              'it), so a moving marker can never re-fire the at-door or '
              'delivered navigation — the pre-existing _overlayLivePosition '
              'invariant, preserved on the snapshot path');
    });

    test('a terminal row never reads a position', () async {
      final repo = _FakeTrackingRepository(stages: [TrackingStage.delivered]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      expect(repo.positionReads, 0,
          reason: 'there is no moving jeeber to plot on a completed trip');
    });

    test('reaching a terminal status stops reading the position', () async {
      final repo = _FakeTrackingRepository(
          stages: [TrackingStage.inTransit, TrackingStage.delivered]);
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      expect(repo.positionReads, 1);

      bus.add(null);
      await pumpEventQueue();
      expect(repo.positionReads, 1,
          reason: 'the delivered read is terminal — no position goes with it');
    });
  });
}
