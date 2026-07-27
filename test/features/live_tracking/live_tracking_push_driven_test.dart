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
///  * The courier POSITION is a STREAM. No push carries it; the gateway serves
///    it as SSE at `GET /v1/geo/jeeb/stream/{id}`. That axis is now
///    `LivePositionStreamSource`, and it retires
///    `GET /deliveries/{id}/tracking`.
///
/// Also preserved: this cubit deliberately NEVER reads `GET /otp` — on the live
/// gateway that endpoint TRIGGERS AN SMS, so polling it would text the recipient
/// every few seconds. The hand-over code comes from local persistence only.
class _FakeTrackingRepository
    implements LiveTrackingRepository, LivePositionStreamSource {
  _FakeTrackingRepository({
    required this.stages,
    this.lifecycle = TrackingLifecycle.active,
  });

  final TrackingLifecycle lifecycle;

  /// Consumed one per `fetchDeliveryStatus`; the last value repeats.
  List<TrackingStage> stages;
  int statusReads = 0;

  /// Every position stream this repo handed out, so a test can assert the
  /// SSE connection was opened once and released on terminal.
  final List<StreamController<DeliveryLivePosition>> positionStreams = [];

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
  Stream<DeliveryLivePosition> watchLivePosition({
    required String deliveryId,
  }) {
    final c = StreamController<DeliveryLivePosition>();
    positionStreams.add(c);
    return c.stream;
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

  group('N7 position axis — SSE stream, not poll', () {
    test('opens exactly ONE position stream and applies each frame', () async {
      final repo = _FakeTrackingRepository(stages: [TrackingStage.inTransit]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      expect(repo.positionStreams, hasLength(1),
          reason: 'ONE held SSE connection for the trip — not one read per tick');

      repo.positionStreams.single.add(const DeliveryLivePosition(
        jeeberPosition: GpsPoint(lat: 33.1, lng: 35.1),
        polyline: [GpsPoint(lat: 33.1, lng: 35.1)],
      ));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.1);

      repo.positionStreams.single.add(const DeliveryLivePosition(
        jeeberPosition: GpsPoint(lat: 33.2, lng: 35.2),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.2,
          reason: 'the marker MOVES on a server-pushed frame, with no read');
      expect(repo.statusReads, 1,
          reason: 'a position frame must not trigger a status read');
    });

    test('a position frame never re-fires the delivered/at-door navigation',
        () async {
      final repo = _FakeTrackingRepository(stages: [TrackingStage.atDoor]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.pendingEvent, LiveTrackingEvent.jeeberAtDoor,
          reason: 'the STATUS read is what raises the at-door card');

      repo.positionStreams.single.add(const DeliveryLivePosition(
        jeeberPosition: GpsPoint(lat: 33.3, lng: 35.3),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.3);
      expect(cubit.state.pendingEvent, LiveTrackingEvent.none,
          reason: 'the position merge carries NO pendingEvent (copyWith resets '
              'it), so a moving marker can never re-fire the at-door or '
              'delivered navigation — the pre-existing _overlayLivePosition '
              'invariant, preserved on the stream path');
    });

    test('a terminal row never opens a position stream', () async {
      final repo = _FakeTrackingRepository(stages: [TrackingStage.delivered]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionStreams, isEmpty,
          reason: 'there is no moving jeeber to plot on a completed trip');
    });

    test('reaching a terminal status releases the position stream', () async {
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
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionStreams.single.hasListener, isTrue);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionStreams.single.hasListener, isFalse,
          reason: 'leaving the SSE socket open after delivery keeps the gateway '
              'writing into a connection nobody reads');
    });
  });
}
