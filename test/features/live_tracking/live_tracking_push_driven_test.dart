import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

/// b02 wave C — N7, re-cut by MB1 W1.1. The customer live-tracking screen ran
/// ONE 5s poll serving TWO different data needs, and that conflation is why it
/// was a poll at all:
///
///  * STATUS transitions are EVENTS. A `type=delivery` push already carries
///    them, to `req.ClientId` among the recipients
///    (`Controllers/DeliveriesController.cs:1296-1300` →
///    `Notifications/DeliveryStatusPushNotifier.cs:211`). That axis is the push
///    bus below, and it retires the `GET /v1/deliveries/{id}` cadence.
///  * The courier POSITION is a SNAPSHOT taken on those same events — ONE
///    `GET /deliveries/{id}/tracking` per open / push / resume / retry, and at
///    no other time.
///
/// **What changed in W1.1, and why.** N7 originally routed the position axis
/// through a streaming capability interface over the gateway's server-sent-
/// events alias under `/v1/geo/`. The gateway DELETED that route
/// (`LocationController.cs:22-31`) 16 h after this consumer landed, so every arm
/// 404'd, every 404 closed the stream, and the re-arm backoff — reset only
/// inside a frame handler that could never run — re-issued the dead GET every
/// 30 s forever behind a permanently frozen marker. The stream stack is gone;
/// the assertions below are re-expressed against the read that still exists.
/// The deleted symbols are named only in
/// `sse_teardown_grep_receipt_test.dart`, which is the guard that keeps them
/// out of everywhere else.
///
/// Also preserved: this cubit deliberately NEVER reads `GET /otp` — on the live
/// gateway that endpoint TRIGGERS AN SMS, so polling it would text the recipient
/// every few seconds. The hand-over code comes from local persistence only.
class _FakeTrackingRepository
    implements LiveTrackingRepository, LivePositionSource {
  _FakeTrackingRepository({
    required this.stages,
    this.lifecycle = TrackingLifecycle.active,
    this.positions = const <DeliveryLivePosition?>[],
  });

  final TrackingLifecycle lifecycle;

  /// Consumed one per `fetchDeliveryStatus`; the last value repeats.
  List<TrackingStage> stages;
  int statusReads = 0;

  /// Consumed one per `fetchLivePosition`; the last value repeats. Empty means
  /// "the gateway has no fix", i.e. every read returns null.
  final List<DeliveryLivePosition?> positions;

  /// Every position read this repo served, so a test can count them exactly.
  /// The cadence claim is a NUMBER here, not a vibe.
  int positionReads = 0;

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
    final index = positionReads;
    positionReads++;
    if (positions.isEmpty) return null;
    return positions[index < positions.length ? index : positions.length - 1];
  }
}

DeliveryLivePosition _fix(double lat, double lng) => DeliveryLivePosition(
      jeeberPosition: GpsPoint(lat: lat, lng: lng),
      polyline: [GpsPoint(lat: lat, lng: lng)],
    );

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

  group('W1.1 position axis — one snapshot read per EVENT, never a cadence', () {
    test('reads once on screen open and applies the fix', () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.inTransit],
        positions: [_fix(33.1, 35.1)],
      );
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      expect(repo.positionReads, 1,
          reason: 'screen open is exactly ONE tracking read');
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.1);
      expect(cubit.debugLastPositionCause, LivePositionReadCause.screenOpen);
      // The stage from the delivery row survives the merge.
      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
    });

    test('a status push MOVES the marker — one push, one position read',
        () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.inTransit],
        positions: [_fix(33.1, 35.1), _fix(33.2, 35.2), _fix(33.3, 35.3)],
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
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.1);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionReads, 2);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.2,
          reason: 'the marker MOVES on the push-driven read — this is the whole '
              'P0 fix: before it, the marker was frozen for the entire trip');
      expect(cubit.debugLastPositionCause, LivePositionReadCause.push);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.3);
      expect(repo.positionReads, 3);
      expect(cubit.debugPositionReadCount, 3);
    });

    test('the resume backstop takes one read, attributed to resume', () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.inTransit],
        positions: [_fix(33.1, 35.1), _fix(33.9, 35.9)],
      );
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionReads, 1);

      await cubit.refreshNow();
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionReads, 2);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.9);
      expect(cubit.debugLastPositionCause, LivePositionReadCause.resume);
    });

    test('NO EVENT ⇒ no position read for 10 virtual minutes', () {
      fakeAsync((async) {
        final repo = _FakeTrackingRepository(
          stages: [TrackingStage.inTransit],
          positions: [_fix(33.1, 35.1)],
        );
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-N7',
          refreshSignals: const Stream<void>.empty(),
        );
        async.flushMicrotasks();
        expect(repo.positionReads, 1);

        async.elapse(const Duration(minutes: 10));
        async.flushMicrotasks();
        expect(repo.positionReads, 1,
            reason: 'W1.1 adds NO cadence. The deleted SSE re-arm re-issued a '
                'dead GET every 30s forever; ten minutes of it would be ~20 '
                'requests. Anything above 1 here is a reintroduced poll.');
        expect(async.periodicTimerCount, isZero);
        expect(async.pendingTimers, isEmpty);
        cubit.close();
      });
    });

    test('an empty snapshot leaves the existing marker alone', () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.inTransit],
        positions: [_fix(33.1, 35.1), null],
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
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.1);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionReads, 2, reason: 'the read was still attempted');
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.1,
          reason: 'a null/empty snapshot must never BLANK a marker the screen '
              'already has (the pre-first-fix case)');
    });

    test('a position read never re-fires the delivered/at-door navigation',
        () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.atDoor],
        positions: [_fix(33.3, 35.3)],
      );
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.3);
      expect(cubit.state.pendingEvent, LiveTrackingEvent.none,
          reason: 'the position merge carries NO pendingEvent (copyWith resets '
              'it), so a moving marker can never re-fire the at-door or '
              'delivered navigation — the pre-existing _overlayLivePosition '
              'invariant, preserved on the snapshot path');
    });

    test('a terminal row never takes a position read', () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.delivered],
        positions: [_fix(33.4, 35.4)],
      );
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionReads, 0,
          reason: 'there is no moving jeeber to plot on a completed trip');
    });

    test('reaching a terminal status stops position reads', () async {
      final repo = _FakeTrackingRepository(
        stages: [TrackingStage.inTransit, TrackingStage.delivered],
        positions: [_fix(33.1, 35.1)],
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
      expect(repo.positionReads, 1);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.positionReads, 1,
          reason: 'the push read the DELIVERED row, so the position read that '
              'would have followed it must not happen');
    });

    test('a repo with no position capability degrades silently', () async {
      final cubit = LiveTrackingCubit(
        repository: const _StageOnlyRepository(),
        deliveryId: 'DLV-N7',
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
      expect(cubit.state.trackingInfo?.jeeberPosition, isNull);
      expect(cubit.debugPositionReadCount, 0);
    });
  });
}

/// Demo / seam / catalog parity: a repo that implements ONLY the core interface.
class _StageOnlyRepository implements LiveTrackingRepository {
  const _StageOnlyRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      DeliveryTrackingInfo(
        deliveryId: deliveryId,
        currentStage: TrackingStage.inTransit,
        stageTimestamps: const {},
      );
}
