import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';

const _id = 'synthetic-terminal-delivery';

DeliveryTrackingInfo _status(String value) =>
    DeliveryTrackingInfo.fromDeliveryJson(_id, {'id': _id, 'status': value});

class _PendingRepository implements LiveTrackingRepository, LivePositionSource {
  final statuses = <Completer<DeliveryTrackingInfo>>[];
  final positions = <Completer<DeliveryLivePosition?>>[];

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) {
    final result = Completer<DeliveryTrackingInfo>();
    statuses.add(result);
    return result.future;
  }

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) {
    final result = Completer<DeliveryLivePosition?>();
    positions.add(result);
    return result.future;
  }
}

class _CodeStore implements HandoverCodeStore {
  final result = Completer<String?>();
  int reads = 0;

  @override
  Future<String?> read({required String deliveryId}) {
    reads++;
    return result.future;
  }

  @override
  Future<void> save({required String deliveryId, required String code}) async =>
      fail('tracking must not write a code');

  @override
  Future<void> clear({required String deliveryId}) async =>
      fail('this fix only clears the in-memory tracking state');
}

void main() {
  for (final status in ['Done', 'Cancelled', 'expired']) {
    test(
      '$status clears already hydrated code and rejects terminal retry',
      () async {
        final repository = _PendingRepository();
        final store = _CodeStore()..result.complete('1234');
        final cubit = LiveTrackingCubit(
          repository: repository,
          deliveryId: _id,
          handoverCodeStore: store,
        );
        addTearDown(cubit.close);
        await pumpEventQueue();
        expect(cubit.state.handoverCode, isNotNull);
        repository.statuses.single.complete(_status(status));
        await pumpEventQueue();
        expect(cubit.state.handoverCode, isNull);
        expect(cubit.state.mode, LiveTrackingViewMode.ready);
        final terminalState = cubit.state;

        cubit.retry();
        await cubit.refreshNow();
        await cubit.retryPositionStream();
        await pumpEventQueue();
        expect(cubit.state, terminalState);
        expect(repository.statuses, hasLength(1));
        expect(repository.positions, isEmpty);
        expect(store.reads, 1);
      },
    );

    test(
      '$status ignores code hydration that completes after status',
      () async {
        final repository = _PendingRepository();
        final store = _CodeStore();
        final cubit = LiveTrackingCubit(
          repository: repository,
          deliveryId: _id,
          handoverCodeStore: store,
        );
        addTearDown(cubit.close);
        repository.statuses.single.complete(_status(status));
        await pumpEventQueue();
        final terminalState = cubit.state;
        expect(terminalState.handoverCode, isNull);

        store.result.complete('1234');
        await pumpEventQueue();
        expect(
          cubit.state,
          terminalState,
          reason: 'late hydration must not clear the receipt event either',
        );
        expect(cubit.state.handoverCode, isNull);
        expect(cubit.debugPushRefreshWired, isFalse);
        expect(cubit.debugPositionStreamLegArmed, isFalse);
      },
    );
  }

  for (final lateResult in ['active', 'delivery-error', 'unexpected-error']) {
    test('Done rejects an older status completion: $lateResult', () async {
      final repository = _PendingRepository();
      final cubit = LiveTrackingCubit(repository: repository, deliveryId: _id);
      addTearDown(cubit.close);
      // The initial read and a resume/retry can overlap. The newer read
      // observes Done while the older request is still on the wire.
      final refresh = cubit.refreshNow();
      expect(repository.statuses, hasLength(2));
      repository.statuses.last.complete(_status('Done'));
      await refresh;
      final terminalState = cubit.state;
      expect(
        terminalState.pendingEvent,
        LiveTrackingEvent.deliveredAutoAdvance,
      );

      switch (lateResult) {
        case 'active':
          repository.statuses.first.complete(_status('InTransit'));
        case 'delivery-error':
          repository.statuses.first.completeError(
            const LiveTrackingException(LiveTrackingErrorKind.network),
          );
        case 'unexpected-error':
          repository.statuses.first.completeError(StateError('synthetic'));
      }
      await pumpEventQueue();
      expect(cubit.state, terminalState);
      expect(repository.positions, isEmpty);
      expect(cubit.debugPushRefreshWired, isFalse);
    });
  }

  for (final lateResult in ['position', 'missing', 'error']) {
    test('active → Done ignores outstanding position $lateResult', () async {
      final repository = _PendingRepository();
      final store = _CodeStore()..result.complete('1234');
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _id,
        handoverCodeStore: store,
      );
      addTearDown(cubit.close);
      repository.statuses.single.complete(_status('InTransit'));
      await pumpEventQueue();
      expect(repository.positions, hasLength(1));
      expect(cubit.state.handoverCode, isNotNull);

      final refresh = cubit.refreshNow();
      repository.statuses.last.complete(_status('Done'));
      await refresh;
      final terminalState = cubit.state;
      expect(terminalState.trackingInfo!.isDelivered, isTrue);
      expect(terminalState.handoverCode, isNull);
      expect(
        terminalState.pendingEvent,
        LiveTrackingEvent.deliveredAutoAdvance,
      );

      switch (lateResult) {
        case 'position':
          repository.positions.single.complete(
            const DeliveryLivePosition(
              jeeberPosition: GpsPoint(lat: 1, lng: 2),
              polyline: [GpsPoint(lat: 1, lng: 2)],
              status: PositionFreshness.live,
            ),
          );
        case 'missing':
          repository.positions.single.complete(null);
        case 'error':
          repository.positions.single.completeError(StateError('synthetic'));
      }
      await pumpEventQueue();
      expect(cubit.state, terminalState);
      expect(cubit.state.trackingInfo!.jeeberPosition, isNull);
      expect(cubit.state.trackingInfo!.polyline, isEmpty);
      expect(cubit.debugPositionReadCount, 0);
      expect(cubit.debugPushRefreshWired, isFalse);
      expect(cubit.debugPositionStreamLegArmed, isFalse);
    });
  }
}
