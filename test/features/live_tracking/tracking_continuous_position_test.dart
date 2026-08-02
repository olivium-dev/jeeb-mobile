import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

/// Continuous courier position — the CUBIT half.
/// ## The two claims, and they pull in opposite directions

const _id = 'DLV-GLIDE';

DeliveryTrackingInfo _row({
  TrackingStage stage = TrackingStage.inTransit,
  TrackingLifecycle lifecycle = TrackingLifecycle.active,
}) =>
    DeliveryTrackingInfo(
      deliveryId: _id,
      currentStage: stage,
      stageTimestamps: const {},
      lifecycle: lifecycle,
    );

class _Repo implements LiveTrackingRepository, LivePositionSource {
  _Repo({this.stage = TrackingStage.inTransit, this.snapshot});

  TrackingStage stage;
  DeliveryLivePosition? snapshot;
  int statusReads = 0;
  int positionReads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    statusReads++;
    return _row(stage: stage);
  }

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    positionReads++;
    return snapshot;
  }
}

/// A channel under the test's control. Not a stand-in for the socket — the
/// socket has its own file — but for the ARRIVAL of frames, which is the only
/// thing the cubit can see.
class _FakeChannel implements CourierPositionChannel {
  _FakeChannel({this.failWith, this.returnsNull = false});

  /// When set, `open()` throws this instead of answering.
  Object? failWith;

  /// When true, `open()` answers null — the "cannot subscribe" degrade.
  bool returnsNull;

  int opens = 0;
  final List<String> openedFor = <String>[];
  bool cancelled = false;

  late final StreamController<CourierPositionFix> _controller =
      StreamController<CourierPositionFix>(onCancel: () => cancelled = true);

  void emit(double lat, double lng) =>
      _controller.add(CourierPositionFix(lat: lat, lng: lng));

  void die() => unawaited(_controller.close());

  void blowUp() => _controller.addError(StateError('socket died'));

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async {
    opens++;
    openedFor.add(deliveryId);
    final boom = failWith;
    if (boom != null) throw boom;
    if (returnsNull) return null;
    return _controller.stream;
  }
}

/// Captures `Diag.event` records, same harness as
/// `tracking_diag_instrument_test.dart`.
class _DiagCapture {
  final List<Map<String, Object?>> records = <Map<String, Object?>>[];

  void install() {
    Diag.enabledOverride = true;
    Diag.sink = (line) {
      final json = line.substring(line.indexOf('{'));
      records.add(jsonDecode(json) as Map<String, Object?>);
    };
  }

  void restore() => Diag.resetForTest();

  List<Map<String, Object?>> named(String name) => records
      .where((r) => r['t'] == 'evt' && r['name'] == name)
      .map((r) => (r['data'] as Map).cast<String, Object?>())
      .toList();
}

void main() {
  group('1. WITH a channel — the marker moves without anyone asking', () {
    test('three arrived fixes move the snapshot three times', () async {
      final repo = _Repo();
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      // Baseline: the four-trigger read happened once and produced nothing,
      expect(repo.positionReads, 1);
      expect(cubit.state.trackingInfo?.jeeberPosition, isNull);

      final seen = <GpsPoint>[];
      final sub = cubit.stream.listen((s) {
        final p = s.trackingInfo?.jeeberPosition;
        if (p != null && (seen.isEmpty || seen.last != p)) seen.add(p);
      });

      channel.emit(33.10, 35.10);
      await pumpEventQueue();
      channel.emit(33.20, 35.20);
      await pumpEventQueue();
      channel.emit(33.30, 35.30);
      await pumpEventQueue();

      expect(cubit.debugStreamedPositionCount, 3);
      expect(seen.map((p) => p.lat), [33.10, 33.20, 33.30],
          reason: 'THE feature: three distinct positions reached the map');
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.30);
      // And it did NOT cost three more gateway reads.
      expect(repo.positionReads, 1);
      expect(repo.statusReads, 1);

      await sub.cancel();
      await cubit.close();
    });

    test('a pushed fix is LIVE — markerIsLive stays true, so the map draws it',
        () async {
      final repo = _Repo();
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      channel.emit(33.5, 35.5);
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.positionStale, isFalse);
      expect(cubit.state.trackingInfo?.markerIsLive, isTrue,
          reason: 'the gateway publishes this frame at ingest, so its age is '
              'one WebSocket hop — a stale verdict here would be a lie that '
              'blanks a correct marker');
      await cubit.close();
    });

    test('the arrival keeps the stage AND the polyline the snapshot read '
        'brought', () async {
      const a = GpsPoint(lat: 1, lng: 2);
      const b = GpsPoint(lat: 3, lng: 4);
      final repo = _Repo(
        snapshot: const DeliveryLivePosition(
          jeeberPosition: a,
          polyline: [a, b],
        ),
      );
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();
      expect(cubit.state.trackingInfo?.polyline, hasLength(2));

      channel.emit(9.9, 9.9);
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 9.9);
      expect(cubit.state.trackingInfo?.polyline, hasLength(2),
          reason: 'a fix carries no route; merging one must not erase the '
              'route the snapshot did carry');
      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
      await cubit.close();
    });

    test('every arrival leaves a breadcrumb, on its OWN event name', () async {
      final diag = _DiagCapture()..install();
      addTearDown(diag.restore);

      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: _Repo(),
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      channel.emit(33.11, 35.22);
      await pumpEventQueue();

      final streamed = diag.named(kTrackingStreamPositionEvent);
      expect(streamed, hasLength(1));
      expect(streamed.single['lat'], closeTo(33.11, 1e-9));
      expect(streamed.single['lng'], closeTo(35.22, 1e-9));
      expect(streamed.single['applied'], isTrue);
      expect(streamed.single['n'], 1);

      // THE separation that matters: the READ instrument still counts exactly
      expect(diag.named(kTrackingPositionEvent), hasLength(1));
      await cubit.close();
    });
  });

  group('2. WITHOUT one — or with a broken one — nothing changes', () {
    test('NEGATIVE CONTROL: positionChannel null → no arrivals, no leg, and '
        'the same reads as today', () async {
      final repo = _Repo();
      final cubit = LiveTrackingCubit(repository: repo, deliveryId: _id);
      await pumpEventQueue();

      expect(cubit.debugStreamedPositionCount, 0);
      expect(cubit.debugPositionStreamLegArmed, isFalse);
      expect(repo.statusReads, 1);
      expect(repo.positionReads, 1);
      expect(cubit.state.mode, LiveTrackingViewMode.ready);
      await cubit.close();
    });

    test('open() returning null degrades silently', () async {
      final repo = _Repo();
      final channel = _FakeChannel(returnsNull: true);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      expect(channel.opens, 1);
      expect(cubit.debugPositionStreamLegArmed, isFalse);
      expect(cubit.state.mode, LiveTrackingViewMode.ready,
          reason: 'the stepper and summary are fine; only the glide is absent');
      await cubit.close();
    });

    test('open() THROWING degrades silently too — the doc comment says it '
        'returns null, but a devtool double is not bound by a doc comment',
        () async {
      final repo = _Repo();
      final channel = _FakeChannel(failWith: StateError('boom'));
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      expect(cubit.state.mode, LiveTrackingViewMode.ready);
      expect(cubit.debugStreamedPositionCount, 0);
      await cubit.close();
    });

    test('a socket that DIES mid-delivery leaves the last marker and the four '
        'triggers still working', () async {
      final repo = _Repo();
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      channel.emit(33.4, 35.4);
      await pumpEventQueue();
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.4);

      channel.die();
      await pumpEventQueue();

      expect(cubit.debugPositionStreamLegArmed, isFalse);
      expect(cubit.state.trackingInfo?.jeeberPosition?.lat, 33.4,
          reason: 'a dead transport must not blank a marker it already drew');

      // The resume backstop still reads.
      await cubit.refreshNow();
      await pumpEventQueue();
      expect(repo.statusReads, 2);
      expect(repo.positionReads, 2);
      await cubit.close();
    });

    test('a socket that ERRORS is handled like one that died', () async {
      final repo = _Repo();
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      channel.blowUp();
      await pumpEventQueue();

      expect(cubit.debugPositionStreamLegArmed, isFalse);
      expect(cubit.state.mode, LiveTrackingViewMode.ready);
      await cubit.close();
    });
  });

  group('3. no cadence — the property this whole line of work exists to keep',
      () {
    test('a cubit WITH a channel arms zero timers, periodic or otherwise', () {
      fakeAsync((async) {
        final channel = _FakeChannel();
        final cubit = LiveTrackingCubit(
          repository: _Repo(),
          deliveryId: _id,
          positionChannel: channel,
        );
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));

        expect(async.periodicTimerCount, 0);
        expect(async.pendingTimers, isEmpty);
        // And five idle minutes produced no extra gateway reads.
        expect(cubit.debugPositionReadCount, 0);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('ARM-ONCE: repeated resumes never re-open the channel', () async {
      final repo = _Repo();
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();
      expect(channel.opens, 1);

      await cubit.refreshNow();
      await pumpEventQueue();
      await cubit.refreshNow();
      await pumpEventQueue();
      cubit.retry();
      await pumpEventQueue();

      expect(channel.opens, 1,
          reason: 'one descriptor GET per screen entry — a re-open per resume '
              'would be a poll wearing a lifecycle hook');
      expect(repo.statusReads, greaterThan(1),
          reason: 'POSITIVE CONTROL: the resumes really did happen');
      await cubit.close();
    });

    test('a channel that cannot open costs exactly ONE attempt, not one per '
        'resume', () async {
      final channel = _FakeChannel(returnsNull: true);
      final cubit = LiveTrackingCubit(
        repository: _Repo(),
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();
      await cubit.refreshNow();
      await pumpEventQueue();
      await cubit.refreshNow();
      await pumpEventQueue();

      expect(channel.opens, 1);
      await cubit.close();
    });
  });

  group('4. lifecycle', () {
    test('closing the cubit CANCELS the leg — which is what closes the socket',
        () async {
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: _Repo(),
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();
      expect(cubit.debugPositionStreamLegArmed, isTrue);
      expect(channel.cancelled, isFalse);

      await cubit.close();
      await pumpEventQueue();

      expect(channel.cancelled, isTrue,
          reason: 'an uncancelled leg is an open WebSocket per screen entry');
    });

    test('a TERMINAL row never opens a channel at all', () async {
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: _Repo(stage: TrackingStage.delivered),
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();

      expect(channel.opens, 0,
          reason: 'a delivered row never moves again (FM-4)');
      await cubit.close();
    });

    test('a delivered transition retires the leg', () async {
      final repo = _Repo();
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();
      expect(cubit.debugPositionStreamLegArmed, isTrue);

      repo.stage = TrackingStage.delivered;
      await cubit.refreshNow();
      await pumpEventQueue();

      expect(cubit.debugPositionStreamLegArmed, isFalse);
      expect(channel.cancelled, isTrue);
      await cubit.close();
    });

    test('a fix arriving after delivery cannot re-fire the auto-advance',
        () async {
      final repo = _Repo(stage: TrackingStage.delivered);
      final channel = _FakeChannel();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        positionChannel: channel,
      );
      await pumpEventQueue();
      expect(cubit.state.pendingEvent, LiveTrackingEvent.deliveredAutoAdvance);

      channel.emit(1, 1);
      await pumpEventQueue();

      expect(cubit.debugStreamedPositionCount, 0,
          reason: 'a terminal row takes nothing from the subscription');
      await cubit.close();
    });
  });
}
