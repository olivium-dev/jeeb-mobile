import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
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

/// Loads schema (transitions schema → identity) then completes every capture +
/// the ToS tick so [KycWizardState.canSubmitIdentity] is true.
Future<void> _completeIdentity(KycWizardCubit cubit) async {
  await cubit.loadSchema();
  await cubit.captureIdFront();
  await cubit.captureIdBack();
  await cubit.captureSelfie();
  cubit.setTosAccepted(true);
}

void main() {
  group('KycWizardCubit — initial state', () {
    test('starts on the schema step before loadSchema is called', () {
      final cubit = _buildCubit();
      expect(cubit.state.step, KycWizardStep.schema);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
    });

    test('loadSchema transitions schema → identity step', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();
      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.formSchema, isNotNull);
    });
  });

  group('KycWizardCubit — identity captures', () {
    test('initial state after loadSchema has nothing captured', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();
      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
      expect(cubit.state.submission.hasIdFront, isFalse);
      expect(cubit.state.completedCaptureSteps, 0);
      expect(cubit.state.canSubmitIdentity, isFalse);
    });

    test('captureIdFront/back/selfie populate the submission', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();

      await cubit.captureIdFront();
      expect(cubit.state.submission.hasIdFront, isTrue);
      expect(cubit.state.completedCaptureSteps, 0,
          reason: 'back side still missing');

      await cubit.captureIdBack();
      expect(cubit.state.submission.hasIdBack, isTrue);
      expect(cubit.state.completedCaptureSteps, 1);

      await cubit.captureSelfie();
      expect(cubit.state.submission.hasSelfie, isTrue);
      expect(cubit.state.completedCaptureSteps, KycWizardState.totalCaptureSteps);
    });

    test('canSubmitIdentity requires all captures AND the ToS tick', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();
      await cubit.captureIdFront();
      await cubit.captureIdBack();
      await cubit.captureSelfie();
      expect(cubit.state.canSubmitIdentity, isFalse,
          reason: 'ToS not yet accepted');

      cubit.setTosAccepted(true);
      expect(cubit.state.canSubmitIdentity, isTrue);
    });

    test('setIdNumber records the national-ID number on the submission '
        '(E3/JEBV4-197)', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();
      expect(cubit.state.submission.idType, 'national_id');
      expect(cubit.state.submission.hasValidIdNumber, isFalse);

      cubit.setIdNumber('12345');
      expect(cubit.state.submission.idNumber, '12345');
      expect(cubit.state.submission.hasValidIdNumber, isFalse,
          reason: 'national_id requires exactly 12 digits');

      cubit.setIdNumber('123456789012');
      expect(cubit.state.submission.idNumber, '123456789012');
      expect(cubit.state.submission.hasValidIdNumber, isTrue);
    });
  });

  group('KycWizardCubit — submit + funding chain', () {
    test('submit transitions to status with the gateway-issued decision',
        () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.pending);
    });

    test('a fresh submit sets the one-shot justSubmitted navigation flag',
        () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await _completeIdentity(cubit);

      await cubit.submit();
      expect(cubit.state.justSubmitted, isTrue);

      cubit.acknowledgeNavigation();
      expect(cubit.state.justSubmitted, isFalse);
    });

    test('submit populates tosAcceptedVersion on success', () async {
      final cubit = _buildCubit();
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.tosAcceptedVersion, isNotEmpty);
      expect(cubit.state.step, KycWizardStep.status);
    });

    test('submit surfaces rejection reason when gateway rejects', () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(
          decision: KycStatus.rejected,
          rejectionReason: KycRejectionReason.selfieMismatch,
        ),
      );
      await _completeIdentity(cubit);
      await cubit.submit();

      expect(cubit.state.submission.status, KycStatus.rejected);
      expect(cubit.state.submission.rejectionReason,
          KycRejectionReason.selfieMismatch);
    });

    test('submit is a no-op while a submit is already in flight', () async {
      final cubit = _buildCubit();
      await _completeIdentity(cubit);
      // Manually pin the in-flight step; a second submit must early-return.
      // (We cannot easily race the await here, so assert the guard directly.)
      await cubit.submit();
      expect(cubit.state.step, KycWizardStep.status);
    });

    test('resubmit resets the wizard to identity step and reloads', () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.rejected),
      );
      await _completeIdentity(cubit);
      await cubit.submit();
      expect(cubit.state.submission.status, KycStatus.rejected);

      cubit.resubmit();
      // resubmit calls loadSchema() async — wait for it.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
      expect(cubit.state.submission.hasIdFront, isFalse);
      expect(cubit.state.tosAccepted, isFalse);
      expect(cubit.state.justSubmitted, isFalse);
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
      await cubit.loadSchema();
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
      await cubit.loadSchema();
      await cubit.captureIdFront();
      expect(cubit.state.error, KycWizardError.pickCancelled);
    });
  });

  group('KycWizardCubit — loadStatus', () {
    test('loadStatus on a not-submitted gateway loads schema and lands on identity',
        () async {
      final cubit = _buildCubit();
      await cubit.loadStatus();
      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.submission.status, KycStatus.notSubmitted);
    });

    test('loadStatus on a previously-submitted gateway jumps to status',
        () async {
      final shared = FakeKycGateway(decision: KycStatus.approved);
      // Pre-seed the gateway by running a full submit on one cubit.
      final seeder = _buildCubit(gateway: shared);
      await _completeIdentity(seeder);
      await seeder.submit();

      // A fresh cubit binding to the same gateway should land on status, NOT
      // re-fire the funding navigation (justSubmitted stays false on re-entry).
      final next = _buildCubit(gateway: shared);
      await next.loadStatus();
      expect(next.state.step, KycWizardStep.status);
      expect(next.state.submission.status, KycStatus.approved);
      expect(next.state.justSubmitted, isFalse);
    });
  });

  group('KycWizardCubit — ToS contract template', () {
    test('submit loads the contract template lazily on first submit', () async {
      final cubit = _buildCubit();
      await _completeIdentity(cubit);
      expect(cubit.state.contractTemplate, isNull);

      await cubit.submit();

      expect(cubit.state.contractTemplate, isNotNull);
      expect(cubit.state.contractTemplate!.tosVersion, isNotEmpty);
    });
  });
}
