// NET-05 — five `return null` sites collapsed into one indistinguishable null,
// so an auth-rejected stream and an absent one read the same.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

class _StaticRepository implements LiveTrackingRepository {
  const _StaticRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => const DeliveryTrackingInfo(
        deliveryId: 'DLV-1',
        currentStage: TrackingStage.inTransit,
        stageTimestamps: <TrackingStage, DateTime>{},
        requestId: 'REQ-1',
      );
}

class _RefusingChannel
    implements CourierPositionChannel, CourierPositionChannelOutcome {
  _RefusingChannel(this.failure);

  final CourierPositionOpenFailure failure;
  int opens = 0;

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      null;

  @override
  Future<CourierPositionOpenResult> openWithOutcome({
    required String deliveryId,
  }) async {
    opens++;
    return CourierPositionOpenResult.failed(failure);
  }
}

/// The legacy shape: `open()` only. The cubit must still cope.
class _LegacyNullChannel implements CourierPositionChannel {
  const _LegacyNullChannel();

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      null;
}

void main() {
  test('every open failure is distinguishable on the state', () async {
    for (final failure in CourierPositionOpenFailure.values) {
      final channel = _RefusingChannel(failure);
      final cubit = LiveTrackingCubit(
        repository: const _StaticRepository(),
        deliveryId: 'DLV-1',
        positionChannel: channel,
      );
      await pumpEventQueue();

      expect(cubit.state.streamUnavailable, isTrue, reason: '$failure');
      expect(cubit.state.streamFailure, failure);
      await cubit.close();
    }
  });

  test('a legacy channel still marks the stream unavailable', () async {
    final cubit = LiveTrackingCubit(
      repository: const _StaticRepository(),
      deliveryId: 'DLV-1',
      positionChannel: const _LegacyNullChannel(),
    );
    await pumpEventQueue();

    expect(cubit.state.streamUnavailable, isTrue);
    expect(
      cubit.state.streamFailure,
      CourierPositionOpenFailure.unavailable,
    );
    await cubit.close();
  });

  test('a resume does NOT re-open a channel that never opened (D14)',
      () async {
    final channel = _RefusingChannel(CourierPositionOpenFailure.transport);
    final cubit = LiveTrackingCubit(
      repository: const _StaticRepository(),
      deliveryId: 'DLV-1',
      positionChannel: channel,
    );
    await pumpEventQueue();
    expect(channel.opens, 1);

    await cubit.refreshNow();
    await pumpEventQueue();
    await cubit.refreshNow();
    await pumpEventQueue();

    expect(
      channel.opens,
      1,
      reason: 'a re-open per resume would be a poll wearing a lifecycle hook',
    );
    await cubit.close();
  });

  test("the user's own Retry re-arms it exactly once", () async {
    final channel = _RefusingChannel(CourierPositionOpenFailure.transport);
    final cubit = LiveTrackingCubit(
      repository: const _StaticRepository(),
      deliveryId: 'DLV-1',
      positionChannel: channel,
    );
    await pumpEventQueue();
    expect(channel.opens, 1);

    cubit.retry();
    await pumpEventQueue();

    expect(channel.opens, 2, reason: 'an explicit act, not a cadence');
    await cubit.close();
  });

  test('a channel that opens leaves streamUnavailable false', () async {
    final controller = StreamController<CourierPositionFix>.broadcast();
    addTearDown(controller.close);
    final cubit = LiveTrackingCubit(
      repository: const _StaticRepository(),
      deliveryId: 'DLV-1',
      positionChannel: _OpeningChannel(controller.stream),
    );
    await pumpEventQueue();

    expect(cubit.state.streamUnavailable, isFalse);
    expect(cubit.state.streamFailure, isNull);
    await cubit.close();
  });
}

class _OpeningChannel
    implements CourierPositionChannel, CourierPositionChannelOutcome {
  const _OpeningChannel(this._positions);

  final Stream<CourierPositionFix> _positions;

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      _positions;

  @override
  Future<CourierPositionOpenResult> openWithOutcome({
    required String deliveryId,
  }) async => CourierPositionOpenResult.opened(_positions);
}
