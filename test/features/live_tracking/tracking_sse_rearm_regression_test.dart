/// b02 — the SSE position stream must RE-ARM after a non-terminal close.
///
/// The 5s `GET /deliveries/{id}/tracking` poll this stream replaced self-healed
/// on the next tick: whatever tore the last request down — a network flap, a
/// proxy idling the connection out, the OS killing the socket on background, a
/// transient 403 on the first arm — the following tick simply asked again. The
/// replacement had NO such property.
///
/// `_positionSubscription` was nulled only inside `_retireWatchers()`, which runs
/// on a terminal row and on `close()` and NEVER on the stream's own `onDone`.
/// `_armWatchers()` guards on `_positionSubscription == null`, so once the stream
/// closed by itself the field stayed non-null forever and nothing — not the
/// resume backstop, not a `type=delivery` push — could ever re-open it. The
/// courier marker froze for the rest of the screen's life.
///
/// These tests were RED before the fix, in this exact shape:
///   * `debugPositionStreamWired` returned TRUE on a dead stream (the debug
///     instrument lied, so the regression could not even be observed);
///   * exactly ONE stream was ever opened where TWO were expected;
///   * a frame published after the flap never reached the state.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

const _id = 'DLV-REARM-1';
const _pos = GpsPoint(lat: 33.9, lng: 35.51);
const _pos2 = GpsPoint(lat: 33.91, lng: 35.52);

/// No backoff at all — the re-arm lands on the next event-loop turn so
/// `pumpEventQueue` observes it.
const _instant = <Duration>[Duration.zero];

DeliveryTrackingInfo _row(String status) => DeliveryTrackingInfo.fromDeliveryJson(
      _id,
      <String, dynamic>{'id': _id, 'status': status},
    );

/// A repo whose position stream can be closed from the test, exactly the way
/// `SseLivePositionStream` closes its controller on EVERY terminal outcome
/// (`shutdown()` → `controller.close()` → the subscriber's `onDone`): a 403, a
/// transport error, a socket the OS tore down, or the server hanging up.
class _FlappingRepo
    implements LiveTrackingRepository, LivePositionStreamSource {
  /// Mutated by the test to complete the delivery mid-flight.
  String status = 'InTransit';
  final List<StreamController<DeliveryLivePosition>> streams = [];
  int statusReads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    statusReads++;
    return _row(status);
  }

  @override
  Stream<DeliveryLivePosition> watchLivePosition({
    required String deliveryId,
  }) {
    final c = StreamController<DeliveryLivePosition>();
    streams.add(c);
    return c.stream;
  }

  /// The live stream dies without the delivery being over.
  Future<void> flap() => streams.last.close();

  void push(GpsPoint p) => streams.last.add(
        DeliveryLivePosition(jeeberPosition: p, polyline: [p]),
      );

  Future<void> disposeAll() async {
    for (final c in streams) {
      if (!c.isClosed) await c.close();
    }
  }
}

void main() {
  group('SSE position stream re-arms after a non-terminal close', () {
    test('a flapped stream is re-opened and the marker resumes moving',
        () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        positionRearmBackoff: _instant,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(repo.streams, hasLength(1), reason: 'first arm');
      expect(cubit.debugPositionStreamWired, isTrue);
      repo.push(_pos);
      await pumpEventQueue();
      expect(cubit.state.trackingInfo?.jeeberPosition, _pos);

      // The flap. Nothing terminal happened — the delivery is still InTransit.
      await repo.flap();
      await pumpEventQueue();

      // 1. The instrument must tell the truth about a dead stream.
      //    RED before the fix: this returned TRUE.
      // 2. A second stream must have been opened.
      //    RED before the fix: `hasLength(1)`.
      expect(repo.streams, hasLength(2), reason: 're-armed after onDone');
      expect(cubit.debugPositionStreamWired, isTrue,
          reason: 'wired again on the NEW stream');
      expect(cubit.debugPositionRearmCount, 1);

      // 3. The marker resumes from the REPLACEMENT stream.
      //    RED before the fix: the position stayed at `_pos` forever.
      repo.push(_pos2);
      await pumpEventQueue();
      expect(cubit.state.trackingInfo?.jeeberPosition, _pos2);
    });

    test('the dead-stream instrument reports false between the close and the '
        're-arm', () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        // Long enough that the re-arm timer cannot fire inside the test.
        positionRearmBackoff: const <Duration>[Duration(minutes: 10)],
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      expect(cubit.debugPositionStreamWired, isTrue);

      await repo.flap();
      await pumpEventQueue();

      // RED before the fix: `debugPositionStreamWired` was
      // `_positionSubscription != null`, and `_positionSubscription` was never
      // nulled on `onDone` — so a dead feed reported as wired.
      expect(cubit.debugPositionStreamWired, isFalse);
      expect(repo.streams, hasLength(1),
          reason: 'backoff not elapsed — no re-arm yet');
    });

    test('refreshNow() really does re-open the position stream (the doc '
        'comment made honest)', () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        // No automatic re-arm inside the test window: the ONLY thing that can
        // re-open the stream here is the resume backstop.
        positionRearmBackoff: const <Duration>[Duration(minutes: 10)],
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      await repo.flap();
      await pumpEventQueue();
      expect(repo.streams, hasLength(1));

      // This is the app-resume path (`live_tracking_screen.dart`).
      await cubit.refreshNow();
      await pumpEventQueue();

      // RED before the fix: the guard `_positionSubscription == null` was false
      // (the field still held the dead subscription), so resume re-read the
      // STATUS and left the position stream shut. `hasLength(1)`.
      expect(repo.streams, hasLength(2));
      repo.push(_pos2);
      await pumpEventQueue();
      expect(cubit.state.trackingInfo?.jeeberPosition, _pos2);
    });

    test('repeated flaps keep re-arming — the poll self-healed every tick and '
        'so must this', () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        positionRearmBackoff: _instant,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      for (var i = 0; i < 3; i++) {
        await repo.flap();
        await pumpEventQueue();
      }
      expect(repo.streams, hasLength(4));
      expect(cubit.debugPositionRearmCount, 3);
    });

    test('a flap does NOT re-arm once the row is terminal', () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        positionRearmBackoff: _instant,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      expect(repo.streams, hasLength(1));

      // The delivery completes; the next status read retires both watchers and
      // the gateway hangs its own socket up.
      repo.status = 'Delivered';
      await cubit.refreshNow();
      await pumpEventQueue();
      await repo.flap();
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.isDelivered, isTrue);
      expect(repo.streams, hasLength(1),
          reason: 'a completed trip must never re-open the socket');
      expect(cubit.debugPositionStreamWired, isFalse);
      expect(cubit.debugPositionRearmCount, 0);
    });

    test('the backoff is honoured — a stream that dies instantly does not spin',
        () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        positionRearmBackoff: const <Duration>[
          Duration(milliseconds: 60),
          Duration(minutes: 10),
        ],
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      await repo.flap();
      await pumpEventQueue();
      // pumpEventQueue burns microtasks/zero-duration timers only, so a 60ms
      // delay has definitively NOT elapsed here.
      expect(repo.streams, hasLength(1), reason: 'waiting out the backoff');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.streams, hasLength(2));

      // Second consecutive failure walks to the next (10 minute) step, so a
      // permanently-rejected stream cannot become a hot loop.
      await repo.flap();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.streams, hasLength(2));
    });

    test('closing the cubit cancels a pending re-arm', () async {
      final repo = _FlappingRepo();
      addTearDown(repo.disposeAll);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
        positionRearmBackoff: const <Duration>[Duration(milliseconds: 40)],
      );
      await pumpEventQueue();
      await repo.flap();
      await pumpEventQueue();
      await cubit.close();

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.streams, hasLength(1),
          reason: 'a closed cubit must not open a socket');
    });
  });
}
