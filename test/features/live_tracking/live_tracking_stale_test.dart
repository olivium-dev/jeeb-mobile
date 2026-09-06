// OFF-09 / UX-09 / UX-11 — a post-first-load failure was silent, and a null
// position read was indistinguishable from "no news".

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

DeliveryTrackingInfo _info() => const DeliveryTrackingInfo(
      deliveryId: 'DLV-1',
      currentStage: TrackingStage.inTransit,
      stageTimestamps: <TrackingStage, DateTime>{},
      requestId: 'REQ-1',
    );

/// Succeeds on the first read and fails afterwards — the warm-failure lane.
class _WarmFailingRepository implements LiveTrackingRepository {
  int reads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    reads++;
    if (reads == 1) return _info();
    throw const LiveTrackingException(LiveTrackingErrorKind.network);
  }
}

/// Reads fine, but every position read comes back null.
class _SilentPositionRepository
    implements LiveTrackingRepository, LivePositionSource {
  int positionReads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => _info();

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    positionReads++;
    return null;
  }
}

void main() {
  test('a warm failure keeps the rows and surfaces refreshError', () async {
    final repo = _WarmFailingRepository();
    final cubit = LiveTrackingCubit(repository: repo, deliveryId: 'DLV-1');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.ready);
    expect(cubit.state.refreshError, isNull);
    expect(cubit.state.lastSuccessAt, isNotNull);

    await cubit.refreshNow();

    // The rows stay: refresh NEVER flips back to loading or error.
    expect(cubit.state.mode, LiveTrackingViewMode.ready);
    expect(cubit.state.trackingInfo, isNotNull);
    expect(cubit.state.refreshError, isA<NetworkFailure>());

    cubit.acknowledgeRefreshError();
    expect(cubit.state.refreshError, isNull);
    await cubit.close();
  });

  test('a cold failure still owns the error rung', () async {
    final cubit = LiveTrackingCubit(
      repository: _AlwaysFailingRepository(),
      deliveryId: 'DLV-1',
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.error);
    expect(cubit.state.failure, isA<NetworkFailure>());
    await cubit.close();
  });

  test('three consecutive null position reads synthesise a LOST fix',
      () async {
    final repo = _SilentPositionRepository();
    final cubit = LiveTrackingCubit(repository: repo, deliveryId: 'DLV-1');
    await Future<void>.delayed(Duration.zero);

    // One read landed with the cold load; drive two more.
    await cubit.refreshNow();
    await cubit.refreshNow();

    expect(repo.positionReads, greaterThanOrEqualTo(3));
    expect(
      cubit.state.trackingInfo?.positionStatus,
      PositionFreshness.lost,
      reason: 'a frozen pin must stop claiming to be live',
    );
    await cubit.close();
  });
}

class _AlwaysFailingRepository implements LiveTrackingRepository {
  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => throw const LiveTrackingException(LiveTrackingErrorKind.network);
}
