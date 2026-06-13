// Tests for ActiveDeliveryCubit (T-MOB-031).
//
// Verifies:
//   - loadDelivery emits loading → ready.
//   - advanceStatus optimistically updates status, confirms on success (AC2).
//   - advanceStatus reverts and sets transitionError on 422 (AC3).
//   - Network failure on load emits error mode.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';

const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

JeeberDelivery _delivery(JeeberDeliveryStatus status) => JeeberDelivery(
      id: 'DLV-770001',
      status: status,
      dropOff: _dropOff,
    );

class _FakeRepo implements ActiveDeliveryRepository {
  _FakeRepo({
    this.fetchResult,
    this.fetchThrows,
    this.transitionResult,
    this.transitionThrows,
  });

  final JeeberDelivery? fetchResult;
  final ActiveDeliveryException? fetchThrows;
  final JeeberDeliveryStatus? transitionResult;
  final ActiveDeliveryException? transitionThrows;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    if (fetchThrows != null) throw fetchThrows!;
    return fetchResult ?? _delivery(JeeberDeliveryStatus.ordered);
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  }) async {
    if (transitionThrows != null) throw transitionThrows!;
    return transitionResult ?? to;
  }
}

void main() {
  group('ActiveDeliveryCubit — load', () {
    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'loadDelivery emits loading → ready',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          fetchResult: _delivery(JeeberDeliveryStatus.ordered),
        ),
        deliveryId: 'DLV-770001',
      ),
      act: (c) => c.loadDelivery(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.mode == ActiveDeliveryMode.loading,
          'loading',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.ready &&
              s.delivery?.status == JeeberDeliveryStatus.ordered,
          'ready with ordered status',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'network error on load emits error mode',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          fetchThrows: const ActiveDeliveryException(
            ActiveDeliveryFailure.network,
          ),
        ),
        deliveryId: 'DLV-770001',
      ),
      act: (c) => c.loadDelivery(),
      expect: () => [
        predicate<ActiveDeliveryState>((s) => s.mode == ActiveDeliveryMode.loading),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.error &&
              s.errorMessage != null,
          'error with message',
        ),
      ],
    );
  });

  group('ActiveDeliveryCubit — advanceStatus', () {
    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'advance from ordered → picked confirms on server success (AC2)',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          fetchResult: _delivery(JeeberDeliveryStatus.ordered),
          transitionResult: JeeberDeliveryStatus.picked,
        ),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.ordered),
      ),
      act: (c) => c.advanceStatus(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) =>
              s.isTransitioning &&
              s.delivery?.status == JeeberDeliveryStatus.picked,
          'optimistic picked',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.ready &&
              s.delivery?.status == JeeberDeliveryStatus.picked,
          'confirmed picked',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'invalid transition reverts and sets transitionError (AC3)',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          fetchResult: _delivery(JeeberDeliveryStatus.ordered),
          transitionThrows: const ActiveDeliveryException(
            ActiveDeliveryFailure.invalidTransition,
          ),
        ),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.ordered),
      ),
      act: (c) => c.advanceStatus(),
      expect: () => [
        predicate<ActiveDeliveryState>((s) => s.isTransitioning),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.ready &&
              s.delivery?.status == JeeberDeliveryStatus.ordered &&
              s.transitionError != null,
          'reverted with transitionError',
        ),
      ],
    );
  });
}
