import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

class _Repository implements LiveTrackingRepository {
  TrackingStage stage = TrackingStage.inTransit;
  int reads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    reads++;
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: stage,
      stageTimestamps: const {},
    );
  }
}

class _PendingChannel implements CourierPositionChannel {
  final attempts = <Completer<Stream<CourierPositionFix>?>>[];

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) {
    final attempt = Completer<Stream<CourierPositionFix>?>();
    attempts.add(attempt);
    return attempt.future;
  }
}

class _CancellableChannel
    implements CourierPositionChannel, CancellableCourierPositionChannel {
  final result = Completer<CourierPositionOpenResult>();
  int cancels = 0;

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) =>
      throw StateError('the cancellable port must be used');

  @override
  CourierPositionOpenAttempt openAttempt({required String deliveryId}) =>
      CourierPositionOpenAttempt(
        result: result.future,
        cancel: () async {
          cancels++;
          result.complete(
            const CourierPositionOpenResult.failed(
              CourierPositionOpenFailure.transport,
            ),
          );
        },
      );
}

void main() {
  test(
    'failure -> explicit retry coalesces concurrent taps/resume and applies frames',
    () async {
      final repository = _Repository();
      final channel = _PendingChannel();
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: 'DLV-1',
        positionChannel: channel,
      );
      await pumpEventQueue();
      channel.attempts.single.complete(null);
      await pumpEventQueue();
      expect(cubit.state.streamUnavailable, isTrue);
      final retry = cubit.retryPositionStream();
      await pumpEventQueue();
      await cubit.retryPositionStream();
      await cubit.refreshNow();
      await pumpEventQueue();
      expect(channel.attempts, hasLength(2));
      expect(cubit.state.streamConnecting, isTrue);
      var cancels = 0;
      final positions = StreamController<CourierPositionFix>(
        onCancel: () => cancels++,
      );
      channel.attempts.last.complete(positions.stream);
      await retry;
      expect(cubit.state.streamUnavailable, isFalse);
      expect(cubit.state.streamFailure, isNull);
      expect(cubit.state.streamConnecting, isFalse);
      final reads = repository.reads;
      for (var i = 1; i <= 3; i++) {
        positions.add(CourierPositionFix(lat: i.toDouble(), lng: 2));
        await pumpEventQueue();
      }
      expect(cubit.state.trackingInfo!.jeeberPosition!.lat, 3);
      expect(cubit.state.trackingInfo!.markerIsLive, isTrue);
      expect(cubit.debugStreamedPositionCount, 3);
      expect(
        repository.reads,
        reads,
        reason: 'incoming frames never trigger HTTP polling',
      );
      await cubit.retryPositionStream();
      expect(
        channel.attempts,
        hasLength(2),
        reason: 'do not replace a healthy subscription',
      );
      await cubit.close();
      expect(cancels, 1);
      await positions.close();
    },
  );

  test('failed opens schedule no timer or background retry', () {
    fakeAsync((async) {
      final channel = _PendingChannel();
      final cubit = LiveTrackingCubit(
        repository: _Repository(),
        deliveryId: 'DLV-1',
        positionChannel: channel,
      );
      async.flushMicrotasks();
      channel.attempts.single.complete(null);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 10));
      expect(channel.attempts, hasLength(1));
      expect(async.pendingTimers, isEmpty);
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  for (final terminal in [false, true]) {
    test(
      '${terminal ? 'terminal status' : 'screen close'} discards a late legacy open',
      () async {
        final repository = _Repository();
        final channel = _PendingChannel();
        final cubit = LiveTrackingCubit(
          repository: repository,
          deliveryId: 'DLV-1',
          positionChannel: channel,
        );
        await pumpEventQueue();
        if (terminal) {
          repository.stage = TrackingStage.delivered;
          await cubit.refreshNow();
        } else {
          await cubit.close();
        }
        var cancelled = false;
        final positions = StreamController<CourierPositionFix>(
          onCancel: () => cancelled = true,
        );
        channel.attempts.single.complete(positions.stream);
        await pumpEventQueue();
        expect(cancelled, isTrue);
        expect(cubit.debugPositionStreamLegArmed, isFalse);
        expect(cubit.debugStreamedPositionCount, 0);
        await cubit.retryPositionStream();
        expect(channel.attempts, hasLength(1));
        await cubit.close();
        await positions.close();
      },
    );

    test(
      '${terminal ? 'terminal status' : 'screen close'} cancels a pending owned attempt',
      () async {
        final repository = _Repository();
        final channel = _CancellableChannel();
        final cubit = LiveTrackingCubit(
          repository: repository,
          deliveryId: 'DLV-1',
          positionChannel: channel,
        );
        await pumpEventQueue();
        if (terminal) {
          repository.stage = TrackingStage.delivered;
          await cubit.refreshNow();
          await pumpEventQueue();
        } else {
          await cubit.close();
        }
        expect(channel.cancels, 1);
        expect(cubit.debugPositionStreamLegArmed, isFalse);
        await cubit.close();
        expect(channel.cancels, 1);
      },
    );
  }

  test('a channel-only drop is visible and resume reopens once', () async {
    final channel = _PendingChannel();
    final cubit = LiveTrackingCubit(
      repository: _Repository(),
      deliveryId: 'DLV-1',
      positionChannel: channel,
    );
    await pumpEventQueue();
    final positions = StreamController<CourierPositionFix>();
    channel.attempts.single.complete(positions.stream);
    await pumpEventQueue();
    await positions.close();
    await pumpEventQueue();
    expect(cubit.state.streamUnavailable, isTrue);
    expect(cubit.debugPositionStreamLegArmed, isFalse);
    await cubit.refreshNow();
    await pumpEventQueue();
    expect(channel.attempts, hasLength(2));
    final recovered = StreamController<CourierPositionFix>();
    channel.attempts.last.complete(recovered.stream);
    await pumpEventQueue();
    expect(cubit.state.streamUnavailable, isFalse);
    await cubit.close();
    await recovered.close();
  });
}
