import 'dart:async';
import 'package:fake_async/fake_async.dart';
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

  LiveTrackingCubit cubit0() => LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        refreshSignals: const Stream<void>.empty(),
      );

  test('emits loading → ready on successful fetch', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenAnswer((_) async => _info(TrackingStage.inTransit));

    final cubit = cubit0();
    // Wait for the initial fetch to complete.
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.ready);
    expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
    await cubit.close();
  });

  test('emits error when no prior info and fetch fails', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenThrow(const LiveTrackingException(LiveTrackingErrorKind.network));

    final cubit = cubit0();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.error);
    await cubit.close();
  });

  test(
      'S9: a 404 (delivery not found) emits a distinct error state with a '
      'title, never crashes', () async {
    // A genuine 404 — e.g. tracking opened with a request id instead of the
    // server delivery id, or the accept-minted delivery not yet propagated.
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenThrow(const LiveTrackingException(LiveTrackingErrorKind.notFound));

    final cubit = cubit0();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.error);
    // Distinct from the generic server/network error: it carries a heading and
    // a calmer "not found yet" message rather than "Server error".
    expect(cubit.state.errorTitle, 'Delivery not found');
    expect(cubit.state.errorMessage, isNot(contains('Server error')));
    expect(cubit.state.errorMessage, contains("can't find this delivery"));
    await cubit.close();
  });

  test('S9: a generic server error carries no errorTitle', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenThrow(const LiveTrackingException(LiveTrackingErrorKind.server));

    final cubit = cubit0();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.mode, LiveTrackingViewMode.error);
    expect(cubit.state.errorTitle, isNull);
    expect(cubit.state.errorMessage, 'Server error. Please try again.');
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

    final cubit = cubit0();
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

    final cubit = cubit0();
    await Future<void>.delayed(Duration.zero);

    cubit.retry();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.pendingEvent, LiveTrackingEvent.jeeberAtDoor);
    expect(cubit.state.isAtDoor, isTrue);
    await cubit.close();
  });

  // JEBV4-218 / Q-061 (pilot fidelity) — INVERTED by b02 wave C / N7.
  //
  // This test used to LOCK a 5-second default polling cadence ("a re-fetch fires
  // at each 5s tick — never sooner"). The owner mandate retires long polling, so
  // the ratified interval it protected is gone and the guard is inverted: with NO
  // refresh stream wired at all, the DEFAULT cubit must read exactly ONCE, on
  // construction, and never again from the passage of time.
  //
  // Keeping the old form would have been the most expensive kind of green test —
  // it would have failed for the right reason and been "fixed" by restoring the
  // poll.
  test('JEBV4-218 inverted: no default cadence — construction reads once and '
      'time alone never reads again', () {
    fakeAsync((async) {
      var calls = 0;
      when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async {
        calls++;
        return _info(TrackingStage.inTransit);
      });

      // NO refreshSignals argument at all — the production default.
      final cubit =
          LiveTrackingCubit(repository: repo, deliveryId: 'DLV-770001');

      // Initial fetch on construction.
      async.flushMicrotasks();
      expect(calls, 1);

      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();
      expect(calls, 1,
          reason: 'ten minutes on an ACTIVE (inTransit) delivery must produce '
              'zero additional reads — an active row is exactly the case the '
              'old 5s cadence covered, so this is the real control');
      expect(async.periodicTimerCount, isZero,
          reason: 'no periodic timer may survive anywhere in this cubit');

      cubit.close();
      async.flushMicrotasks();
    });
  });

  test('no event emitted when stage does not change', () async {
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenAnswer((_) async => _info(TrackingStage.inTransit));

    final cubit = cubit0();
    await Future<void>.delayed(Duration.zero);

    cubit.retry();
    await Future<void>.delayed(Duration.zero);

    // Same stage → no event
    expect(cubit.state.pendingEvent, LiveTrackingEvent.none);
    await cubit.close();
  });
}
