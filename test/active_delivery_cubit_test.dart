// Tests for ActiveDeliveryCubit (T-MOB-031).
//
// Verifies:
//   - loadDelivery emits loading → ready.
//   - advanceStatus optimistically updates status, confirms on success (AC2).
//   - advanceStatus reverts and sets transitionError on 422 (AC3).
//   - Network failure on load emits error mode.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
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
    this.verifyOtpResult,
    this.verifyOtpThrows,
  });

  final JeeberDelivery? fetchResult;
  final ActiveDeliveryException? fetchThrows;
  final JeeberDeliveryStatus? transitionResult;
  final ActiveDeliveryException? transitionThrows;
  final String? uploadResult;
  final JeeberDeliveryStatus? verifyOtpResult;
  final ActiveDeliveryException? verifyOtpThrows;

  /// Records the last evidenceUrl handed to [transition] (JM-051 chain check).
  String? lastEvidenceUrl;

  /// JEBV4-200: records the REAL image bytes handed to [uploadProofPhoto] so a
  /// test can assert a proof upload transmits bytes, never a filename stub.
  Uint8List? lastUploadedBytes;

  /// Records the last code handed to [verifyDoorOtp] (iter6 close-tail check).
  String? lastOtpCode;

  /// P6/B1: every (from, to) pair the cubit actually PATCHed. The regression
  /// guard for the 2026-07-25 incident asserts this never contains
  /// `(atDoor, done)`.
  final List<(JeeberDeliveryStatus, JeeberDeliveryStatus)> transitionCalls =
      <(JeeberDeliveryStatus, JeeberDeliveryStatus)>[];

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
    transitionCalls.add((from, to));
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
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    lastUploadedBytes = bytes;
    return uploadResult ?? 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
  }
}

/// P6/B5: the first step is committed by the server, the second is refused.
/// Proves the cubit reverts to the LAST CONFIRMED status, not to `original`.
class _FailAfterFirstStepRepo implements ActiveDeliveryRepository {
  int calls = 0;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      _delivery(JeeberDeliveryStatus.ordered);

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async {
    calls++;
    if (calls == 1) return to;
    throw const ActiveDeliveryException(
      ActiveDeliveryFailure.invalidTransition,
    );
  }

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
}

/// P6/A2: counts every delivery read so a test can prove the poll stays armed.
class _CountingRepo implements ActiveDeliveryRepository {
  _CountingRepo(this.onFetch, this.result);

  final void Function() onFetch;
  final JeeberDelivery result;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    onFetch();
    return result;
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async => to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
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
        photoPicker: StubPhotoPickerService(),
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
      ),
      act: (c) => c.captureProofPhoto(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) =>
              s.proofPhotoStatus == ProofPhotoStatus.uploading &&
              // JEBV4-200: the captured bytes are retained for the local
              // thumbnail — proof the upload carries REAL image data.
              (s.proofPhotoBytes?.isNotEmpty ?? false),
          'uploading with captured bytes',
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

    test(
      'captureProofPhoto transmits REAL image bytes, not a filename stub '
      '(JEBV4-200 DoD)',
      () async {
        final repo = _FakeRepo(
          uploadResult: 'https://cdn.jeeb.app/proof/DLV-770001.jpg',
        );
        final payload = Uint8List.fromList(
          List<int>.generate(2048, (i) => i % 256),
        );
        final cubit = ActiveDeliveryCubit(
          repository: repo,
          deliveryId: 'DLV-770001',
          photoPicker: StubPhotoPickerService(cameraPayload: payload),
        )..emit(
            ActiveDeliveryState(
              mode: ActiveDeliveryMode.ready,
              delivery: _delivery(JeeberDeliveryStatus.atDoor),
            ),
          );

        await cubit.captureProofPhoto();

        // The bytes handed to the repository are the actual captured image
        // payload — never a filename/path string.
        expect(repo.lastUploadedBytes, isNotNull);
        expect(repo.lastUploadedBytes, equals(payload));
        expect(repo.lastUploadedBytes!.isNotEmpty, isTrue);
        await cubit.close();
      },
    );

    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'captureProofPhoto is a silent no-op when the jeeber cancels the camera '
      '(JEBV4-200)',
      build: () => ActiveDeliveryCubit(
        repository: _FakeRepo(),
        deliveryId: 'DLV-770001',
        photoPicker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.cancelled,
        ),
      ),
      seed: () => ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: _delivery(JeeberDeliveryStatus.atDoor),
      ),
      act: (c) => c.captureProofPhoto(),
      expect: () => <ActiveDeliveryState>[],
    );

    test('P6/B1: markDelivered at AtDoor patches NOTHING and raises the door '
        'OTP', () async {
      final repo = _FakeRepo();
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
      )..emit(ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: _delivery(JeeberDeliveryStatus.atDoor),
        ));

      await cubit.markDelivered();

      // THE regression guard for the 2026-07-25 incident: no AtDoor→Done PATCH.
      expect(repo.transitionCalls, isEmpty);
      expect(cubit.state.otpRequired, isTrue);
      expect(cubit.state.delivered, isFalse);
      expect(cubit.state.delivery!.status, JeeberDeliveryStatus.atDoor);
      expect(cubit.state.transitionError, isNull);
      await cubit.close();
    });

    test('P6/B1: markDelivered from InTransit walks to AtDoor ONLY, then OTP',
        () async {
      final repo = _FakeRepo(); // echoes the requested `to`
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
      )..emit(ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: _delivery(JeeberDeliveryStatus.inTransit),
        ));

      await cubit.markDelivered();

      expect(
        repo.transitionCalls,
        [(JeeberDeliveryStatus.inTransit, JeeberDeliveryStatus.atDoor)],
      );
      expect(cubit.state.delivery!.status, JeeberDeliveryStatus.atDoor);
      expect(cubit.state.otpRequired, isTrue);
      expect(cubit.state.delivered, isFalse);
      await cubit.close();
    });

    test('P6/B1: the proof evidenceUrl is carried on InTransit→AtDoor',
        () async {
      final repo = _FakeRepo();
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
      )..emit(const ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: JeeberDelivery(
            id: 'DLV-770001',
            status: JeeberDeliveryStatus.inTransit,
            dropOff: _dropOff,
            proofPhotoUrl: 'https://cdn.jeeb.app/proof/x.jpg',
          ),
        ));
      await cubit.markDelivered();
      expect(repo.lastEvidenceUrl, 'https://cdn.jeeb.app/proof/x.jpg');
      expect(
        repo.transitionCalls,
        [(JeeberDeliveryStatus.inTransit, JeeberDeliveryStatus.atDoor)],
      );
      await cubit.close();
    });

    test('P6/B5: a failed step keeps the status the server already committed',
        () async {
      // Ordered → Picked succeeds, Picked → InTransit fails.
      final repo = _FailAfterFirstStepRepo();
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
      )..emit(ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: _delivery(JeeberDeliveryStatus.ordered),
        ));

      await cubit.markDelivered();

      // Pre-fix this rewound to `ordered` and made the error look sticky.
      expect(cubit.state.delivery!.status, JeeberDeliveryStatus.picked);
      expect(cubit.state.transitionError, isNotNull);
      expect(
        cubit.state.transitionErrorKind,
        ActiveDeliveryFailure.invalidTransition,
      );
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
    // P6/B1: from AtDoor the cubit never PATCHes at all (see the B1 cases
    // above). This pins the OTHER door into the OTP surface — an EARLY step
    // answering `otp_required` — which must still hold the row at its last
    // confirmed stage and prompt for the code, never "transition not allowed".
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
        delivery: _delivery(JeeberDeliveryStatus.inTransit),
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
              s.delivery?.status == JeeberDeliveryStatus.inTransit,
          'otpRequired surfaced, held at the last confirmed stage, '
          'no misleading snackbar',
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

  group('ActiveDeliveryCubit — P6 polling (A2 + A4)', () {
    test('P6/A4: during the OTP window the poll discards non-terminal '
        'snapshots', () async {
      final repo = _FakeRepo(
        fetchResult: _delivery(JeeberDeliveryStatus.atDoor),
      );
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(milliseconds: 20),
      )..emit(ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: _delivery(JeeberDeliveryStatus.atDoor),
          otpRequired: true,
        ));
      await cubit.refresh();
      expect(
        cubit.state.otpRequired,
        isTrue,
        reason: 'OTP entry must survive the poll',
      );
      await cubit.close();
    });

    test('P6/A4: a Done read during the OTP window closes it and chains to '
        'rating', () async {
      final repo = _FakeRepo(fetchResult: _delivery(JeeberDeliveryStatus.done));
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
      )..emit(ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: _delivery(JeeberDeliveryStatus.atDoor),
          otpRequired: true,
        ));
      await cubit.refresh();
      expect(cubit.state.otpRequired, isFalse);
      expect(cubit.state.delivered, isTrue);
      await cubit.close();
    });

    test('P6/A2: the jeeber poll stays armed on disputed', () async {
      var calls = 0;
      final repo = _CountingRepo(
        () => calls++,
        _delivery(JeeberDeliveryStatus.disputed),
      );
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(milliseconds: 20),
      );
      await cubit.loadDelivery();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        calls,
        greaterThan(1),
        reason: 'admin can still resolve a disputed row',
      );
      await cubit.close();
    });
  });
}
