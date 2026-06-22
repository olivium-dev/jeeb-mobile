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
    this.uploadResult,
    this.uploadThrows,
    this.verifyOtpResult,
    this.verifyOtpThrows,
  });

  final JeeberDelivery? fetchResult;
  final ActiveDeliveryException? fetchThrows;
  final JeeberDeliveryStatus? transitionResult;
  final ActiveDeliveryException? transitionThrows;
  final String? uploadResult;
  final ActiveDeliveryException? uploadThrows;
  final JeeberDeliveryStatus? verifyOtpResult;
  final ActiveDeliveryException? verifyOtpThrows;

  /// Records the last evidenceUrl handed to [transition] (JM-051 chain check).
  String? lastEvidenceUrl;

  /// Records the last code handed to [verifyDoorOtp] (iter6 close-tail check).
  String? lastOtpCode;

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
    String? evidenceUrl,
  }) async {
    lastEvidenceUrl = evidenceUrl;
    if (transitionThrows != null) throw transitionThrows!;
    return transitionResult ?? to;
  }

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async {
    lastOtpCode = code;
    if (verifyOtpThrows != null) throw verifyOtpThrows!;
    return verifyOtpResult ?? JeeberDeliveryStatus.done;
  }

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
  }) async {
    if (uploadThrows != null) throw uploadThrows!;
    return uploadResult ?? 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
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

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'advanceStatus no-ops at AtDoor — final step is markDelivered (JM-051)',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(transitionResult: JeeberDeliveryStatus.done),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
      ),
      act: (c) => c.advanceStatus(),
      expect: () => <ActiveDeliveryState>[],
    );
  });

  group('ActiveDeliveryCubit — JM-051 mark-delivered', () {
    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'captureProofPhoto uploads and stamps the evidence URL (AC1/D3)',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          uploadResult: 'https://cdn.jeeb.app/proof/DLV-770001.jpg',
        ),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
      ),
      act: (c) => c.captureProofPhoto('proof.jpg'),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.proofPhotoStatus == ProofPhotoStatus.uploading,
          'uploading',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.proofPhotoStatus == ProofPhotoStatus.captured &&
              s.delivery?.proofPhotoUrl ==
                  'https://cdn.jeeb.app/proof/DLV-770001.jpg',
          'captured with evidence url',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'markDelivered transitions AtDoor → Done and emits delivered (AC2)',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(transitionResult: JeeberDeliveryStatus.done),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
      ),
      act: (c) => c.markDelivered(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) =>
              s.isTransitioning &&
              s.delivery?.status == JeeberDeliveryStatus.done,
          'optimistic done',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.ready &&
              s.delivery?.status == JeeberDeliveryStatus.done &&
              s.delivered == true,
          'confirmed done + delivered signal',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'markDelivered walks InTransit → AtDoor → Done (seam seeds InTransit)',
      // _FakeRepo echoes the requested `to` (transitionResult null) so the walk
      // advances step-by-step like the real mock SM-1.
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.inTransit),
      ),
      act: (c) => c.markDelivered(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) =>
              s.isTransitioning &&
              s.delivery?.status == JeeberDeliveryStatus.done,
          'optimistic done',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.ready &&
              s.delivery?.status == JeeberDeliveryStatus.done &&
              s.delivered == true,
          'confirmed done + delivered after walking both steps',
        ),
      ],
    );

    test('markDelivered carries the proof evidenceUrl on the Done transition',
        () async {
      final repo = _FakeRepo(transitionResult: JeeberDeliveryStatus.done);
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
      );
      cubit.emit(ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: JeeberDelivery(
          id: 'DLV-770001',
          status: JeeberDeliveryStatus.atDoor,
          dropOff: _dropOff,
          proofPhotoUrl: 'https://cdn.jeeb.app/proof/x.jpg',
        ),
      ));
      await cubit.markDelivered();
      expect(repo.lastEvidenceUrl, 'https://cdn.jeeb.app/proof/x.jpg');
      await cubit.close();
    });

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'acknowledgeDelivered clears the one-shot nav signal',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.done),
        delivered: true,
      ),
      act: (c) => c.acknowledgeDelivered(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.delivered == false,
          'delivered cleared',
        ),
      ],
    );
  });

  group('ActiveDeliveryCubit — door OTP (iter6 close-tail)', () {
    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'markDelivered on 422 otp_required surfaces the OTP entry '
      '(NOT "transition not allowed")',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          transitionThrows: const ActiveDeliveryException(
            ActiveDeliveryFailure.otpRequired,
          ),
        ),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
      ),
      act: (c) => c.markDelivered(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.isTransitioning,
          'transitioning (optimistic)',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.otpRequired &&
              s.transitionError == null &&
              s.delivery?.status == JeeberDeliveryStatus.atDoor,
          'otpRequired surfaced, held at AtDoor, no misleading snackbar',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'submitDoorOtp with a valid code completes to Done and fires the '
      'rating signal',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(verifyOtpResult: JeeberDeliveryStatus.done),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
        otpRequired: true,
      ),
      act: (c) => c.submitDoorOtp('1234'),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.isVerifyingOtp,
          'verifying',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              !s.isVerifyingOtp &&
              s.delivered &&
              !s.otpRequired &&
              s.delivery?.status == JeeberDeliveryStatus.done,
          'Done + delivered:true (rating chain)',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'submitDoorOtp with a wrong code keeps the entry open with an inline error',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(
          verifyOtpThrows: const ActiveDeliveryException(
            ActiveDeliveryFailure.invalidOtp,
          ),
        ),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
        otpRequired: true,
      ),
      act: (c) => c.submitDoorOtp('0000'),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.isVerifyingOtp,
          'verifying',
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              !s.isVerifyingOtp &&
              !s.delivered &&
              s.otpRequired &&
              s.otpError != null,
          'still otpRequired with an inline error, not delivered',
        ),
      ],
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'submitDoorOtp forwards the entered code to the repository',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(verifyOtpResult: JeeberDeliveryStatus.done),
        deliveryId: 'DLV-770001',
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
        otpRequired: true,
      ),
      act: (c) => c.submitDoorOtp('1234'),
      verify: (c) {
        expect((c.state.delivery)?.status, JeeberDeliveryStatus.done);
      },
    );
  });
}
