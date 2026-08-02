import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/application/delivery_status_cubit.dart';
import 'package:jeeb_mobile/features/delivery_status/application/delivery_status_state.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_address.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_snapshot.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_status_gateway.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_tier.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';

/// Sentinel used so test helpers can distinguish "omitted" (use default)
/// from "explicit null" (suppress the field).
const _unset = Object();

DeliverySnapshot _snapshot({
  String id = 'd-1',
  DeliveryStage stage = DeliveryStage.matched,
  DeliveryLifecycle lifecycle = DeliveryLifecycle.active,
  Map<DeliveryStage, DateTime>? stageTimestamps,
  Object? jeeber = _unset,
  int? etaMinutes,
}) {
  return DeliverySnapshot(
    id: id,
    stage: stage,
    lifecycle: lifecycle,
    stageTimestamps: stageTimestamps ??
        <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
        },
    pickup: const DeliveryAddress(label: 'Pickup'),
    dropoff: const DeliveryAddress(label: 'Dropoff'),
    tier: DeliveryTier.scooter,
    jeeber: identical(jeeber, _unset)
        ? const JeeberSummary(
            displayName: 'Karim H.',
            vehicleLabel: 'Scooter',
            phoneE164: '+96171000000',
          )
        : jeeber as JeeberSummary?,
    etaMinutes: etaMinutes,
  );
}

class _NullStreamGateway implements DeliveryStatusGateway {
  _NullStreamGateway();

  static const cancelOutcome = CancellationOutcome.success;
  final StreamController<DeliverySnapshot> _ctrl =
      StreamController<DeliverySnapshot>.broadcast();

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) => _ctrl.stream;

  void emit(DeliverySnapshot s) => _ctrl.add(s);
  void errorOut(Object e) => _ctrl.addError(e);
  void closeStream() => _ctrl.close();

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async => cancelOutcome;
}

void main() {
  group('snapshot helpers', () {
    test('canCancel only before pickup', () {
      expect(_snapshot(stage: DeliveryStage.matched).canCancel, isTrue);
      expect(_snapshot(stage: DeliveryStage.pickedUp).canCancel, isFalse);
      expect(_snapshot(stage: DeliveryStage.inTransit).canCancel, isFalse);
      expect(
        _snapshot(
          stage: DeliveryStage.matched,
          lifecycle: DeliveryLifecycle.cancelled,
        ).canCancel,
        isFalse,
        reason: 'cancelled lifecycle hides the cancel CTA',
      );
    });

    test('isEtaVisible only while in transit with a real number', () {
      expect(
        _snapshot(stage: DeliveryStage.inTransit, etaMinutes: 5).isEtaVisible,
        isTrue,
      );
      expect(
        _snapshot(stage: DeliveryStage.inTransit).isEtaVisible,
        isFalse,
        reason: 'eta null while in transit hides the badge',
      );
      expect(
        _snapshot(stage: DeliveryStage.pickedUp, etaMinutes: 5).isEtaVisible,
        isFalse,
        reason: 'gateway lies about eta pre-transit',
      );
    });

    test('canContactJeeber requires a non-empty number and active lifecycle',
        () {
      expect(_snapshot().canContactJeeber, isTrue);
      expect(
        _snapshot(jeeber: null).canContactJeeber,
        isFalse,
      );
      expect(
        _snapshot(
          jeeber: const JeeberSummary(
            displayName: 'A',
            vehicleLabel: 'B',
            phoneE164: '',
          ),
        ).canContactJeeber,
        isFalse,
      );
      expect(
        _snapshot(lifecycle: DeliveryLifecycle.completed).canContactJeeber,
        isFalse,
      );
    });

    test('stage ordering helpers', () {
      expect(DeliveryStage.matched.isBefore(DeliveryStage.pickedUp), isTrue);
      expect(
        DeliveryStage.pickedUp.isAtOrBefore(DeliveryStage.pickedUp),
        isTrue,
      );
      expect(DeliveryStage.delivered.isBefore(DeliveryStage.matched), isFalse);
    });
  });

  group('DeliveryStatusCubit subscription', () {
    blocTest<DeliveryStatusCubit, DeliveryStatusState>(
      'emits ready with the first snapshot from the gateway',
      build: () => DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(seed: _snapshot()),
      ),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        predicate<DeliveryStatusState>(
          (s) =>
              s.mode == DeliveryStatusViewMode.ready &&
              s.snapshot != null &&
              s.snapshot!.stage == DeliveryStage.matched,
        ),
      ],
    );

    blocTest<DeliveryStatusCubit, DeliveryStatusState>(
      're-emits as the gateway pushes new snapshots',
      build: () {
        final gw = _NullStreamGateway();
        // Push after subscription via the cubit's listener wiring.
        scheduleMicrotask(() {
          gw.emit(_snapshot(stage: DeliveryStage.matched));
          gw.emit(_snapshot(stage: DeliveryStage.pickedUp));
          gw.emit(_snapshot(stage: DeliveryStage.inTransit, etaMinutes: 3));
        });
        return DeliveryStatusCubit(deliveryId: 'd-1', gateway: gw);
      },
      wait: const Duration(milliseconds: 1),
      verify: (cubit) {
        expect(cubit.state.mode, DeliveryStatusViewMode.ready);
        expect(cubit.state.snapshot!.stage, DeliveryStage.inTransit);
        expect(cubit.state.snapshot!.isEtaVisible, isTrue);
      },
    );

    blocTest<DeliveryStatusCubit, DeliveryStatusState>(
      'flips to error when the stream errors',
      build: () {
        final gw = _NullStreamGateway();
        scheduleMicrotask(() => gw.errorOut(StateError('boom')));
        return DeliveryStatusCubit(deliveryId: 'd-1', gateway: gw);
      },
      wait: const Duration(milliseconds: 1),
      verify: (cubit) {
        expect(cubit.state.mode, DeliveryStatusViewMode.error);
        expect(cubit.state.error, DeliveryStatusError.streamLost);
      },
    );

    blocTest<DeliveryStatusCubit, DeliveryStatusState>(
      'treats a premature stream close while in-flight as a transport error',
      build: () {
        final gw = _NullStreamGateway();
        scheduleMicrotask(() {
          gw.emit(_snapshot(stage: DeliveryStage.inTransit, etaMinutes: 5));
          gw.closeStream();
        });
        return DeliveryStatusCubit(deliveryId: 'd-1', gateway: gw);
      },
      wait: const Duration(milliseconds: 1),
      verify: (cubit) {
        expect(cubit.state.mode, DeliveryStatusViewMode.error);
        expect(cubit.state.error, DeliveryStatusError.streamLost);
      },
    );

    blocTest<DeliveryStatusCubit, DeliveryStatusState>(
      'leaves stream-close on a terminal snapshot in ready mode',
      build: () {
        final gw = _NullStreamGateway();
        scheduleMicrotask(() {
          gw.emit(_snapshot(
            stage: DeliveryStage.delivered,
            lifecycle: DeliveryLifecycle.completed,
          ));
          gw.closeStream();
        });
        return DeliveryStatusCubit(deliveryId: 'd-1', gateway: gw);
      },
      wait: const Duration(milliseconds: 1),
      verify: (cubit) {
        expect(cubit.state.mode, DeliveryStatusViewMode.ready);
        expect(cubit.state.snapshot!.lifecycle, DeliveryLifecycle.completed);
      },
    );

    test('retry flips mode back to loading and re-subscribes', () async {
      final gw = _NullStreamGateway();
      final cubit = DeliveryStatusCubit(deliveryId: 'd-1', gateway: gw);
      gw.errorOut(StateError('first failure'));
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(cubit.state.mode, DeliveryStatusViewMode.error);
      cubit.retry();
      expect(cubit.state.mode, DeliveryStatusViewMode.loading);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });
  });

  group('cancel', () {
    test('rejects with cancelTooLate when the snapshot disallows cancel',
        () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(
          seed: _snapshot(stage: DeliveryStage.pickedUp),
        ),
      );
      // Let the seed snapshot land on the cubit's state before we cancel.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(cubit.state.snapshot!.canCancel, isFalse);
      await cubit.cancel();
      expect(cubit.state.error, DeliveryStatusError.cancelTooLate);
      expect(cubit.state.isCancelling, isFalse);
      await cubit.close();
    });

    test('flips isCancelling true during the gateway call and clears it after',
        () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(
          seed: _snapshot(stage: DeliveryStage.matched),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      // Capture all subsequent emits.
      final emits = <DeliveryStatusState>[];
      final sub = cubit.stream.listen(emits.add);
      await cubit.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await sub.cancel();
      await cubit.close();
      // Should have at least two emits — one with isCancelling true, then
      expect(emits.length, greaterThanOrEqualTo(2));
      expect(emits.first.isCancelling, isTrue);
      expect(emits[1].isCancelling, isFalse);
    });

    test('surfaces cancelTooLate when the gateway returns tooLate', () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(
          seed: _snapshot(stage: DeliveryStage.matched),
          cancelOutcome: CancellationOutcome.tooLate,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await cubit.cancel();
      expect(cubit.state.error, DeliveryStatusError.cancelTooLate);
      expect(cubit.state.isCancelling, isFalse);
      await cubit.close();
    });

    test('surfaces cancelNetwork when the gateway returns networkError',
        () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(
          seed: _snapshot(stage: DeliveryStage.matched),
          cancelOutcome: CancellationOutcome.networkError,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await cubit.cancel();
      expect(cubit.state.error, DeliveryStatusError.cancelNetwork);
      expect(cubit.state.isCancelling, isFalse);
      await cubit.close();
    });
  });

  group('requestContactNumber', () {
    test('returns the phone number when contact is available', () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(seed: _snapshot()),
      );
      // Let the first snapshot land before asking for the contact.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(cubit.requestContactNumber(), '+96171000000');
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('emits contactUnavailable when contact is gated', () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(seed: _snapshot(jeeber: null)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(cubit.requestContactNumber(), isNull);
      expect(cubit.state.error, DeliveryStatusError.contactUnavailable);
      await cubit.close();
    });
  });

  group('acknowledgeError', () {
    test('clears a pending one-shot error', () async {
      final cubit = DeliveryStatusCubit(
        deliveryId: 'd-1',
        gateway: InMemoryDeliveryStatusGateway(seed: _snapshot(jeeber: null)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      cubit.requestContactNumber();
      expect(cubit.state.error, DeliveryStatusError.contactUnavailable);
      cubit.acknowledgeError();
      expect(cubit.state.error, isNull);
      await cubit.close();
    });
  });
}
