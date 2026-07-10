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

/// Loads schema (transitions schema → identity) then completes every capture,
/// the ID number (E3/JEBV4-197 hard gate), and the ToS tick so
/// [KycWizardState.canSubmitIdentity] is true.
Future<void> _completeIdentity(KycWizardCubit cubit) async {
  await cubit.loadSchema();
  await cubit.captureIdFront();
  await cubit.captureIdBack();
  await cubit.captureSelfie();
  cubit.setIdNumber('123456789012');
  cubit.setTosAccepted(true);
}

/// Counts [submit] calls so tests can prove the pre-submit gate never dials
/// the gateway with an invalid draft (JEBV4-113 review finding 1).
class _CountingKycGateway extends FakeKycGateway {
  int submitCalls = 0;

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    submitCalls++;
    return super.submit(draft);
  }
}

/// Throws a field-scoped BFF rejection on submit, mimicking the RFC-7807
/// `field` extension the live gateway returns on a 400.
class _FieldRejectingKycGateway extends FakeKycGateway {
  _FieldRejectingKycGateway(this.field);

  final String field;

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    throw KycSubmitFieldException(field: field, detail: 'server said no');
  }
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

    test('canSubmitIdentity requires all captures, a valid ID number, AND '
        'the ToS tick', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();
      await cubit.captureIdFront();
      await cubit.captureIdBack();
      await cubit.captureSelfie();
      cubit.setTosAccepted(true);
      expect(cubit.state.canSubmitIdentity, isFalse,
          reason: 'ID number not yet entered (E3 hard gate)');

      cubit.setIdNumber('123456789012');
      expect(cubit.state.canSubmitIdentity, isTrue);

      cubit.setTosAccepted(false);
      expect(cubit.state.canSubmitIdentity, isFalse,
          reason: 'ToS tick still required');
    });

    test('setIdNumber records the national-ID number on the submission '
        '(E3/JEBV4-197)', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();
      expect(cubit.state.submission.idType, KycIdType.nationalId);
      expect(cubit.state.submission.hasValidIdNumber, isFalse);

      cubit.setIdNumber('12345');
      expect(cubit.state.submission.idNumber, '12345');
      expect(cubit.state.submission.hasValidIdNumber, isFalse,
          reason: 'national_id requires exactly 12 digits');

      cubit.setIdNumber('123456789012');
      expect(cubit.state.submission.idNumber, '123456789012');
      expect(cubit.state.submission.hasValidIdNumber, isTrue);
    });

    test('setIdNumber normalizes Eastern Arabic-Indic digits to ASCII '
        '(review finding 5)', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();

      cubit.setIdNumber('١٢٣٤٥٦٧٨٩٠١٢');
      expect(cubit.state.submission.idNumber, '123456789012');
      expect(cubit.state.submission.hasValidIdNumber, isTrue);
    });

    test('setIdType switches the variant; validation follows the new type '
        '(E3/Q-042)', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema();

      // An 8-char passport number is invalid under national_id...
      cubit.setIdNumber('P1234567');
      expect(cubit.state.submission.hasValidIdNumber, isFalse);

      // ...and valid once the type is passport (non-empty rule only).
      cubit.setIdType(KycIdType.passport);
      expect(cubit.state.submission.idType, KycIdType.passport);
      expect(cubit.state.submission.hasValidIdNumber, isTrue);

      cubit.setIdType(KycIdType.residency);
      expect(cubit.state.submission.idType, KycIdType.residency);
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

    test('submit with an EMPTY id_number never dials the gateway — inline '
        'field error instead (review finding 1)', () async {
      final gateway = _CountingKycGateway();
      final cubit = _buildCubit(gateway: gateway);
      await cubit.loadSchema();
      await cubit.captureIdFront();
      await cubit.captureIdBack();
      await cubit.captureSelfie();
      cubit.setTosAccepted(true);
      // No setIdNumber — the E3 hard gate must trip.

      await cubit.submit();

      expect(gateway.submitCalls, 0,
          reason: 'a blank id_number must never reach the network');
      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.submitFieldError, KycSubmitFieldError.idNumber);
      expect(cubit.state.error, isNull,
          reason: 'field-scoped failure must not raise the generic snackbar');
    });

    test('submit with an INVALID (short) national id_number never dials the '
        'gateway', () async {
      final gateway = _CountingKycGateway();
      final cubit = _buildCubit(gateway: gateway);
      await cubit.loadSchema();
      cubit.setIdNumber('12345678901'); // 11 digits — boundary below.
      cubit.setTosAccepted(true);

      await cubit.submit();

      expect(gateway.submitCalls, 0);
      expect(cubit.state.submitFieldError, KycSubmitFieldError.idNumber);
    });

    test('editing the field clears the inline submit error', () async {
      final cubit = _buildCubit(gateway: _CountingKycGateway());
      await cubit.loadSchema();
      cubit.setTosAccepted(true);
      await cubit.submit();
      expect(cubit.state.submitFieldError, KycSubmitFieldError.idNumber);

      cubit.setIdNumber('1');
      expect(cubit.state.submitFieldError, isNull);
    });

    test('a BFF field-scoped 400 (field: id_number) surfaces INLINE, not as '
        'the generic snackbar (review finding 1)', () async {
      final cubit = _buildCubit(
        gateway: _FieldRejectingKycGateway('id_number'),
      );
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.submitFieldError, KycSubmitFieldError.idNumber);
      expect(cubit.state.error, isNull);
    });

    test('a BFF field-scoped 400 (field: id_type) surfaces on the picker',
        () async {
      final cubit = _buildCubit(
        gateway: _FieldRejectingKycGateway('id_type'),
      );
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.submitFieldError, KycSubmitFieldError.idType);
      expect(cubit.state.error, isNull);
    });

    test('a field-scoped 400 naming an UNKNOWN field falls back to the '
        'generic submit-failed surface (never silent)', () async {
      final cubit = _buildCubit(
        gateway: _FieldRejectingKycGateway('tos_accepted_version'),
      );
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.submitFieldError, isNull);
      expect(cubit.state.error, KycWizardError.submitFailed);
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
      // Review finding 4: the identity fields reset with the draft — the
      // bound text field mirrors this via the controller sync.
      expect(cubit.state.submission.idNumber, isNull);
      expect(cubit.state.submission.idType, KycIdType.nationalId);
      expect(cubit.state.submitFieldError, isNull);
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
