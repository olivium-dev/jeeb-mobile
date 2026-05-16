import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/domain/vehicle_type.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

Uint8List _bytes(int length, [int fill = 0x42]) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = fill;
  }
  return out;
}

KycWizardCubit _buildCubit({
  PhotoPickerService? picker,
  KycGateway? gateway,
}) {
  final cubit = KycWizardCubit(
    pickerService: picker ??
        StubPhotoPickerService(cameraPayload: _bytes(100 * 1024)),
    gateway: gateway ?? FakeKycGateway(),
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _completeCaptures(KycWizardCubit cubit) async {
  await cubit.captureIdFront();
  await cubit.captureIdBack();
  cubit.goToSelfie();
  await cubit.captureSelfie();
  cubit.goToVehicle();
  cubit.setVehicleType(VehicleType.scooter);
  cubit.setVehicleRegistration('LB 12345');
}

void main() {
  group('KycWizardCubit — wizard transitions', () {
    test('initial state lands on the ID step with nothing captured', () {
      final cubit = _buildCubit();
      expect(cubit.state.step, KycWizardStep.id);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
      expect(cubit.state.submission.hasIdFront, isFalse);
      expect(cubit.state.completedCaptureSteps, 0);
    });

    test('captureIdFront/back populate the submission and advance is gated',
        () async {
      final cubit = _buildCubit();

      await cubit.captureIdFront();
      expect(cubit.state.submission.hasIdFront, isTrue);
      expect(cubit.state.canAdvanceFromId, isFalse,
          reason: 'back side still missing');

      await cubit.captureIdBack();
      expect(cubit.state.submission.hasIdBack, isTrue);
      expect(cubit.state.canAdvanceFromId, isTrue);
      expect(cubit.state.completedCaptureSteps, 1);

      cubit.goToSelfie();
      expect(cubit.state.step, KycWizardStep.selfie);
    });

    test('goToSelfie is a no-op until both ID sides are captured', () async {
      final cubit = _buildCubit();
      cubit.goToSelfie();
      expect(cubit.state.step, KycWizardStep.id);

      await cubit.captureIdFront();
      cubit.goToSelfie();
      expect(cubit.state.step, KycWizardStep.id);
    });

    test('goBack walks vehicle → selfie → id but never past step 1', () async {
      final cubit = _buildCubit();
      await _completeCaptures(cubit);
      // Sitting on vehicle now.
      expect(cubit.state.step, KycWizardStep.vehicle);

      cubit.goBack();
      expect(cubit.state.step, KycWizardStep.selfie);
      cubit.goBack();
      expect(cubit.state.step, KycWizardStep.id);
      cubit.goBack();
      expect(cubit.state.step, KycWizardStep.id);
    });
  });

  group('KycWizardCubit — vehicle step + submit', () {
    test('submit refuses to advance until registration is filled', () async {
      final cubit = _buildCubit();
      await _completeCaptures(cubit);
      cubit.setVehicleRegistration('   ');

      await cubit.submit();
      expect(cubit.state.step, KycWizardStep.vehicle);
      expect(cubit.state.error, KycWizardError.vehicleRegistrationRequired);

      // Typing clears the inline error.
      cubit.setVehicleRegistration('LB-12345');
      expect(cubit.state.error, isNull);
    });

    test('submit transitions to status with the gateway-issued decision',
        () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await _completeCaptures(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.pending);
      expect(cubit.state.submission.submittedAt, isNotNull);
    });

    test('submit surfaces rejection reason when the gateway rejects',
        () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(
          decision: KycStatus.rejected,
          rejectionReason: KycRejectionReason.selfieMismatch,
        ),
      );
      await _completeCaptures(cubit);

      await cubit.submit();

      expect(cubit.state.submission.status, KycStatus.rejected);
      expect(cubit.state.submission.rejectionReason,
          KycRejectionReason.selfieMismatch);
    });

    test('resubmit resets the wizard back to step 1', () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.rejected),
      );
      await _completeCaptures(cubit);
      await cubit.submit();
      expect(cubit.state.submission.status, KycStatus.rejected);

      cubit.resubmit();
      expect(cubit.state.step, KycWizardStep.id);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
      expect(cubit.state.submission.hasIdFront, isFalse);
    });
  });

  group('KycWizardCubit — capture errors', () {
    test('permission denied maps to KycWizardError.permissionDenied',
        () async {
      final cubit = _buildCubit(
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.permissionDenied,
        ),
      );
      await cubit.captureIdFront();
      expect(cubit.state.error, KycWizardError.permissionDenied);
      expect(cubit.state.submission.hasIdFront, isFalse);
    });

    test('cancellation does not produce a snackbar-worthy error', () async {
      final cubit = _buildCubit(
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.cancelled,
        ),
      );
      await cubit.captureIdFront();
      expect(cubit.state.error, KycWizardError.pickCancelled);
    });
  });

  group('KycWizardCubit — loadStatus', () {
    test('loadStatus on a not-submitted gateway lands on step 1', () async {
      final cubit = _buildCubit();
      await cubit.loadStatus();
      expect(cubit.state.step, KycWizardStep.id);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
    });

    test('loadStatus on a previously-submitted gateway jumps to status',
        () async {
      final shared = FakeKycGateway(decision: KycStatus.approved);
      // Pre-seed the gateway by running a full submit on one cubit.
      final seeder = _buildCubit(gateway: shared);
      await _completeCaptures(seeder);
      await seeder.submit();

      // A fresh cubit binding to the same gateway should land on status.
      final next = _buildCubit(gateway: shared);
      await next.loadStatus();
      expect(next.state.step, KycWizardStep.status);
      expect(next.state.submission.status, KycStatus.approved);
    });
  });
}
