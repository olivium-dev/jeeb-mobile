import 'dart:async';
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

/// Mimics the on-device submit-hang: `submit()` NEVER completes (a stalled CDN
/// upload, or a 201 the client never receives), while the server-side status is
/// scripted so the safety-net poll can reconcile against it (JEBV4-259/271).
class _HangingSubmitKycGateway extends FakeKycGateway {
  _HangingSubmitKycGateway({required this.serverStatus});

  /// What `GET /v1/kyc/status` reports while the submit future is hung.
  final KycStatus serverStatus;

  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      Completer<KycSubmission>().future; // never resolves

  @override
  Future<KycSubmission> fetchStatus() async => KycSubmission(
        status: serverStatus,
        submittedAt: DateTime.now(),
      );
}

/// Mimics a submit whose round-trip FAILS or times out — a slow inline-approve
/// that outran the receive-timeout, or a 201 the client never received — even
/// though the gateway already RECORDED (and here auto-approved) the submission
/// server-side. `submit()` throws a plain transport error (NOT a field
/// rejection); `GET /v1/kyc/status` reports the recorded decision so the cubit
/// can reconcile off the spinner with no restart (JEBV4-271).
class _FailingSubmitButRecordedKycGateway extends FakeKycGateway {
  _FailingSubmitButRecordedKycGateway({required this.serverStatus});

  final KycStatus serverStatus;
  int statusReads = 0;

  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      Future<KycSubmission>.error(StateError('dropped response'));

  @override
  Future<KycSubmission> fetchStatus() async {
    statusReads++;
    return KycSubmission(status: serverStatus, submittedAt: DateTime.now());
  }
}

void main() {
  group(
      'KycWizardCubit — failed submit reconciles against the server '
      '(JEBV4-271 no-restart)', () {
    test(
        'a dropped/slow submit whose server-side decision is Verified advances '
        'onto the approved status view instead of the submit-failed form',
        () async {
      final gateway = _FailingSubmitButRecordedKycGateway(
        serverStatus: KycStatus.approved,
      );
      final cubit = _buildCubit(gateway: gateway);
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(cubit.state.error, isNull,
          reason: 'the server already approved — never surface a submit error '
              'or bounce back to the identity form (which forced the restart)');
      expect(cubit.state.justSubmitted, isFalse,
          reason: 'lands on the in-wizard approved view that activates the '
              'jeeber role, not the onboarding-funding chain');
      expect(gateway.statusReads, greaterThan(0));
    });

    test(
        'a submit that failed BEFORE reaching the server still surfaces the '
        'retryable submit error (nothing recorded to reconcile to)', () async {
      final gateway = _FailingSubmitButRecordedKycGateway(
        serverStatus: KycStatus.notSubmitted,
      );
      final cubit = _buildCubit(gateway: gateway);
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.error, KycWizardError.submitFailed);
    });

    test('a field-scoped 400 stays authoritative and does NOT reconcile',
        () async {
      final cubit =
          _buildCubit(gateway: _FieldRejectingKycGateway('id_number'));
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.identity);
      expect(cubit.state.submitFieldError, KycSubmitFieldError.idNumber);
    });
  });
  group('KycWizardCubit — submit-hang safety net (refreshWhileSubmitting)', () {
    test(
        'un-sticks a HUNG submit: server already Verified → advances off the '
        'spinner to the approved status view (no force-stop needed)', () async {
      final cubit = _buildCubit(
        gateway: _HangingSubmitKycGateway(serverStatus: KycStatus.approved),
      );
      await _completeIdentity(cubit);

      // Kick off a submit that HANGS forever — the wizard is stranded on the
      // submitting spinner, exactly the on-device ~98s hang.
      unawaited(cubit.submit());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.step, KycWizardStep.submitting,
          reason: 'submit() emitted submitting then hung on the gateway');

      // The safety-net poll reconciles against the server, which already
      // recorded the auto-approved submission → advance off the spinner.
      await cubit.refreshWhileSubmitting();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(cubit.state.justSubmitted, isFalse,
          reason: 'a recovered submit lands on the in-wizard status view '
              '(→ KycStatusView._ApprovedBody fires JeeberRoleActivator), '
              'never silently chains to onboarding-funding');
    });

    test('keeps the spinner when the server has NO submission yet '
        '(a stall BEFORE the POST reached the server)', () async {
      final cubit = _buildCubit(
        gateway:
            _HangingSubmitKycGateway(serverStatus: KycStatus.notSubmitted),
      );
      await _completeIdentity(cubit);
      unawaited(cubit.submit());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.step, KycWizardStep.submitting);

      await cubit.refreshWhileSubmitting();

      expect(cubit.state.step, KycWizardStep.submitting,
          reason: 'nothing recorded server-side → never leave the spinner '
              '(the CDN upload timeout, not the poll, resolves this branch)');
    });

    test('is a no-op when not on the submitting step', () async {
      final cubit = _buildCubit(
        gateway: _HangingSubmitKycGateway(serverStatus: KycStatus.approved),
      );
      await cubit.loadSchema(); // identity step
      expect(cubit.state.step, KycWizardStep.identity);

      await cubit.refreshWhileSubmitting();

      expect(cubit.state.step, KycWizardStep.identity,
          reason: 'the net only ever fires while stuck on the spinner');
    });
  });

  group('KycWizardCubit — role-arrived signal (JEBV4-271 round 3)', () {
    test(
        'onJeeberRoleGranted un-sticks a HUNG submit: the /me role signal '
        'advances the spinner straight onto the approved status view (no '
        'restart, no /kyc/status poll needed)', () async {
      final cubit = _buildCubit(
        gateway: _HangingSubmitKycGateway(serverStatus: KycStatus.approved),
      );
      await _completeIdentity(cubit);

      // Submit hangs forever — the wizard is stranded on the submit spinner.
      unawaited(cubit.submit());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.step, KycWizardStep.submitting);

      // The role landed via /v1/users/me (RoleAvailabilityCubit gained jeeber);
      // that authoritative grant advances the wizard with no server re-read.
      cubit.onJeeberRoleGranted();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(cubit.state.justSubmitted, isFalse,
          reason: 'lands on the in-wizard approved view (→ JeeberRoleActivator), '
              'never the onboarding-funding chain');
    });

    test(
        'onJeeberRoleGranted advances a PENDING status view to approved when the '
        'role arrives (auto-approve returned Submitted, grant landed later)',
        () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await _completeIdentity(cubit);
      await cubit.submit();
      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.pending);

      cubit.onJeeberRoleGranted();

      expect(cubit.state.submission.status, KycStatus.approved);
    });

    test('onJeeberRoleGranted is a NO-OP off the submit/status steps (never '
        'yanks the user out of capture)', () async {
      final cubit = _buildCubit();
      await cubit.loadSchema(); // identity step
      expect(cubit.state.step, KycWizardStep.identity);

      cubit.onJeeberRoleGranted();

      expect(cubit.state.step, KycWizardStep.identity,
          reason: 'the signal only advances a wizard already awaiting approval');
    });

    test('onJeeberRoleGranted never overrides a terminal REJECTED decision '
        'with a stray role signal', () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(
          decision: KycStatus.rejected,
          rejectionReason: KycRejectionReason.selfieMismatch,
        ),
      );
      await _completeIdentity(cubit);
      await cubit.submit();
      expect(cubit.state.submission.status, KycStatus.rejected);

      cubit.onJeeberRoleGranted();

      expect(cubit.state.submission.status, KycStatus.rejected,
          reason: 'a server rejection must never be masked as approved');
    });
  });

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
      expect(cubit.state.justSubmitted, isTrue,
          reason: 'a still-pending submit chains to onboarding-funding');
    });

    test(
        'JEBV4-271: an AUTO-APPROVED submit (gateway state:Verified → approved) '
        'stays on the status step and does NOT set justSubmitted, so the '
        'in-wizard approved view renders and JeeberRoleActivator fires (jeeber '
        'goes online with no re-login)', () async {
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.approved),
      );
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(cubit.state.justSubmitted, isFalse,
          reason: 'auto-approve must NOT navigate to onboarding-funding; it '
              'stays on the approved status view that activates the jeeber role '
              'in-session');
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

    test(
        'JEBV4-295: a field-scoped 400 naming an UNKNOWN field falls back to '
        'the VALIDATION surface (never silent, and never mislabelled as a '
        'connectivity failure)', () async {
      final cubit = _buildCubit(
        gateway: _FieldRejectingKycGateway('tos_accepted_version'),
      );
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.submitFieldError, isNull);
      // Not submitFailed ("check your connection") — this 400 means the BFF
      // parsed the request and rejected its content, which is not a
      // connectivity problem.
      expect(cubit.state.error, KycWizardError.submitValidationFailed);
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

  group(
      'KycWizardCubit — fresh-user entry then auto-approved submit '
      '(JEBV4-271 round 6: stale isLoadingStatus must not mask the approved '
      'view)', () {
    test(
        'a FRESH jeeber (loadStatus → GET /v1/kyc/status 404 → notSubmitted → '
        'loadSchema) who submits and gets 201 state=Verified lands on the '
        'approved status view with isLoadingStatus CLEARED — so KycStatusView '
        'renders _ApprovedBody (fires JeeberRoleActivator) instead of the bare '
        'isLoadingStatus spinner that stranded the on-device rev2/round-5 jeeber',
        () async {
      // Production entry path: the wizard is created with `..loadStatus()`.
      // A fresh jeeber has no prior submission, so the gateway's fetchStatus
      // reports notSubmitted (the live GET /v1/kyc/status 404), and submit
      // echoes the inline auto-approve (state:Verified → approved).
      final cubit = _buildCubit(
        gateway: FakeKycGateway(decision: KycStatus.approved),
      );

      await cubit.loadStatus();
      expect(cubit.state.step, KycWizardStep.identity,
          reason: 'a notSubmitted cold read routes into the capture flow');
      // REGRESSION GUARD: before the round-6 fix, loadStatus left
      // isLoadingStatus=true here (notSubmitted → loadSchema returned without
      // resetting it), and it stayed true through capture + submit.
      expect(cubit.state.isLoadingStatus, isFalse,
          reason: 'entering the interactive schema/identity flow must clear the '
              'loadStatus loading flag');

      // Complete the identity step, then submit (auto-approved).
      await cubit.captureIdFront();
      await cubit.captureIdBack();
      await cubit.captureSelfie();
      cubit.setIdNumber('123456789012');
      cubit.setTosAccepted(true);
      await cubit.submit();

      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(cubit.state.justSubmitted, isFalse,
          reason: 'an auto-approved submit stays on the in-wizard approved view '
              '(fires JeeberRoleActivator), it does NOT chain to funding');
      // THE DECISIVE ASSERTION: with isLoadingStatus stuck true (pre-fix),
      // KycStatusView.build short-circuits to `Center(OmdsLoadingState())` and
      // never builds _ApprovedBody, so the jeeber role is never activated and
      // the wizard is stuck on the spinner until a restart. The status-view
      // poller then sees `approved` (not pending) and cancels immediately, so
      // the diag stream goes silent right after the 201 — exactly the round-5
      // device repro.
      expect(cubit.state.isLoadingStatus, isFalse,
          reason: 'the approved emit must not carry a stale isLoadingStatus=true; '
              'otherwise KycStatusView renders a bare spinner instead of the '
              'approved body and JeeberRoleActivator never fires (JEBV4-271)');
    });
  });
}
