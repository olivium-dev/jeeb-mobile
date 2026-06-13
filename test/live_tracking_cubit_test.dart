import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

class _MockRepo extends Mock implements LiveTrackingRepository {}

DeliveryTrackingInfo _info(TrackingStage stage) => DeliveryTrackingInfo(
      deliveryId: 'DLV-770001',
      currentStage: stage,
      stageTimestamps: const {},
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  LiveTrackingCubit _cubit() => LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(days: 1), // disable auto-poll in tests
      );

  test('emits loading → ready on successful fetch', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenAnswer((_) async => _info(TrackingStage.inTransit));

    final cubit = _cubit();
    // Wait for the initial fetch to complete.
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.ready);
    expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
    await cubit.close();
  });

  test('emits error when no prior info and fetch fails', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenThrow(const LiveTrackingException(LiveTrackingErrorKind.network));

    final cubit = _cubit();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.error);
    await cubit.close();
  });

  test('emits jeeberOnTheWay event on inTransit transition', () async {
    var callCount = 0;
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenAnswer((_) async {
      callCount++;
      return callCount == 1
          ? _info(TrackingStage.ordered)
          : _info(TrackingStage.inTransit);
    });

    final cubit = _cubit();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.pendingEvent, LiveTrackingEvent.none);

    cubit.retry();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.pendingEvent, LiveTrackingEvent.jeeberOnTheWay);
    await cubit.close();
  });

  test('emits jeeberAtDoor event on atDoor transition', () async {
    var callCount = 0;
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenAnswer((_) async {
      callCount++;
      return callCount == 1
          ? _info(TrackingStage.inTransit)
          : _info(TrackingStage.atDoor);
    });

    final cubit = _cubit();
    await Future<void>.delayed(Duration.zero);

    cubit.retry();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.pendingEvent, LiveTrackingEvent.jeeberAtDoor);
    expect(cubit.state.isAtDoor, isTrue);
    await cubit.close();
  });

  test('no event emitted when stage does not change', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenAnswer((_) async => _info(TrackingStage.inTransit));

    final cubit = _cubit();
    await Future<void>.delayed(Duration.zero);

    cubit.retry();
    await Future<void>.delayed(Duration.zero);

    // Same stage → no event
    expect(cubit.state.pendingEvent, LiveTrackingEvent.none);
    await cubit.close();
  });
}
