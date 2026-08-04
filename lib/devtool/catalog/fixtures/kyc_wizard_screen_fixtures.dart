// Designed states for `KycWizardScreen` (JM-040 `kyc-identity` + JM-042

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../../features/kyc/application/kyc_wizard_state.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/photo_attachment/domain/photo_attachment.dart';

/// [FakeKycGateway] with the two knobs a still frame needs.
/// The base fake answers every call immediately, which is right for the Screen
/// Catalog (a designer taps things and expects them to work) and wrong for two
class KycWizardScreenPreviewGateway extends FakeKycGateway {
  KycWizardScreenPreviewGateway({
    super.decision,
    super.rejectionReason,
    super.initial,
    this.statusReads,
    this.schemaStalls = false,
    this.schemaFails = false,
  });

  /// How many `GET /v1/kyc/status` reads resolve before the gateway goes
  /// silent, or `null` for "always answers" (the catalog's setting).
  final int? statusReads;

  /// When true, `fetchFormSchema` never resolves — the wizard's cold-start
  /// `schema` step, held at its spinner.
  final bool schemaStalls;

  /// When true, `fetchFormSchema` throws, which is the only route to
  /// [KycWizardError.schemaLoadFailed].
  final bool schemaFails;

  int _statusReadCount = 0;

  @override
  Future<KycSubmission> fetchStatus() {
    final int? cap = statusReads;
    _statusReadCount++;
    if (cap != null && _statusReadCount > cap) {
      return Completer<KycSubmission>().future;
    }
    return super.fetchStatus();
  }

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) {
    if (schemaStalls) return Completer<KycFormSchema>().future;
    if (schemaFails) {
      return Future<KycFormSchema>.error(
        StateError('KYC form schema unavailable (designed state)'),
      );
    }
    return super.fetchFormSchema(variant: variant);
  }
}

/// The designed states of `KycWizardScreen`, as seeded cubit states plus the
/// two cubits that are described by a real load instead.
class KycWizardScreenPreviewFixtures {
  const KycWizardScreenPreviewFixtures._();

  /// A contract-valid national ID (`^\d{12}$`, the shape the live BFF
  /// enforces). This is the value that makes `kyc_submit_cta` live.
  static const String nationalIdNumber = '123456789012';

  /// A passport number at the field's full 24-character cap — the widest single
  /// line of user content this screen can hold.
  static const String passportNumber = 'AB1234567890123456789012';

  /// A 120 × 76 landscape PNG in the ISO/IEC 7810 ID-1 proportion the alignment
  /// guide teaches — a navy header band, a portrait box and three text lines —
  static const String _idCardPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAHgAAABMCAIAAAAp7eQ+AAAAv0lEQVR42u3boQ2AMBRF0a7C'
      'JkzDDGg2wKDRGBIGYB4EqhMwAa75QDnJdXXH9KVJU9N2CighAA1aoEGDpgAatECDBk0BNGiB'
      'Bg1aEdDHmRUQaNCgBRo06LuDaV6LBxo0aNCgQYMG/Sx0P4zVBxo0aNCgQYM27+xo0KBBgwYN'
      'GjTowtDLtlcfaNCgQYMGbXWABg0aNGjQoEF763hDoEGDBv13aJchaNCgQYMGDRq0L8qgBRo0'
      'aIEGLdCgQQv0p7oAE7AkXoytNNIAAAAASUVORK5CYII=';

  /// A 60 × 76 portrait PNG — a face and shoulders on a warm ground — so the
  /// selfie tile is visibly a DIFFERENT capture from the two ID tiles rather
  static const String _selfiePngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAADwAAABMCAIAAAC+vEPkAAAA8UlEQVR42u3XsRHCMBBE0auK'
      'WiiIGqiFaggJSWgAZpx4MJItaaU77D9z8d8XSvZ6Pv7uDDRo0KBBgw6Ovt+uqYuIznDldBvG'
      'FdJtvLjdbS7iRrd5iVvc5iiudh8GLRTXuY+Blosr3KBjojuJS92gQYMGDRq0M5q3B2h+LjHQ'
      'p/Plc0LxFOyIngZ6oIvclWiVex7sgp4PSNzLoBi9HGh0p4Ij0HXuTE2GzmyU0rekBOgtM6v6'
      '0shotOSa0C7iVffu0I7ivBu0O9pdnHGD9kUHEafcoB3RocQ/3aBB7x0dULx0gwYNGrQAHVb8'
      '5QYNGnQA9BuWuuxNxw9fDgAAAABJRU5ErkJggg==';

  /// The two fixture payloads, decoded once. Both are far under the 2 MB
  /// ceiling, so `HalvingPhotoCompressor` returns them UNCHANGED — a capture
  static final Uint8List idCardBytes = base64Decode(_idCardPngBase64);
  static final Uint8List selfieBytes = base64Decode(_selfiePngBase64);

  static PhotoAttachment _photo(String slot, Uint8List bytes) =>
      PhotoAttachment(
        id: 'kyc-wizard-preview-$slot',
        bytes: bytes,
        // A real capture arrives an order of magnitude larger and is compressed
        originalSizeBytes: bytes.length * 8,
        source: PhotoSource.camera,
      );

  /// One identity-step state, described by what the jeeber has done so far.
  /// Defaults describe a cold entry: nothing captured, nothing typed, ToS
  static KycWizardState identityState({
    KycIdType idType = KycIdType.nationalId,
    String? idNumber,
    bool govIdCaptured = false,
    bool? idFrontCaptured,
    bool? idBackCaptured,
    bool selfieCaptured = false,
    bool tosAccepted = false,
    KycSubmitFieldError? submitFieldError,
  }) {
    // Per-side overrides exist for R23's own frame: front done, back live,
    // selfie locked. `govIdCaptured` remains the both-sides shorthand.
    final front = idFrontCaptured ?? govIdCaptured;
    final back = idBackCaptured ?? govIdCaptured;
    return KycWizardState(
      step: KycWizardStep.identity,
      tosAccepted: tosAccepted,
      submitFieldError: submitFieldError,
      submission: KycSubmission(
        status: KycStatus.notSubmitted,
        idType: idType,
        idNumber: idNumber,
        idFront: front ? _photo('id-front', idCardBytes) : null,
        idBack: back ? _photo('id-back', idCardBytes) : null,
        selfie: selfieCaptured ? _photo('selfie', selfieBytes) : null,
      ),
    );
  }

  /// The wizard parked on the submit spinner — `POST /v1/kyc/submit` is in
  /// flight and `KycSubmittingView` owns the body.
  static const KycWizardState submittingState = KycWizardState(
    step: KycWizardStep.submitting,
  );

  /// The `schema` step AFTER `KycWizardCubit.loadSchema` caught a failure.
  /// Seeded rather than produced by a failing load on purpose: the host screen
  static const KycWizardState schemaLoadFailedState = KycWizardState(
    step: KycWizardStep.schema,
    error: KycWizardError.schemaLoadFailed,
  );

  /// M4: the status view's own `isLoadingStatus` branch, which no other state
  /// reaches — `statusCubit` resolves its read before the first frame.
  static const KycWizardState statusLoadingState = KycWizardState(
    step: KycWizardStep.status,
    isLoadingStatus: true,
  );

  /// M4: one capture tile mid-compress, the only route to its trailing
  /// in-line wait mark.
  static KycWizardState captureProcessingState({
    KycCaptureSlot slot = KycCaptureSlot.idBack,
  }) =>
      identityState(idFrontCaptured: true, tosAccepted: true)
          .copyWith(capturing: slot);

  /// A real [KycWizardCubit] parked on [seed], with every production transition
  /// still live.
  static KycWizardCubit seededCubit(
    KycWizardState seed, {
    KycGateway? gateway,
  }) {
    return _SeededKycWizardCubit(
      seed,
      gateway ?? KycWizardScreenPreviewGateway(),
    );
  }

  /// The cold-start STATUS path: a cubit hydrated by the real
  /// `KycWizardCubit.loadStatus()` against a canned decision, exactly as
  static KycWizardCubit statusCubit({
    KycStatus status = KycStatus.notSubmitted,
    KycRejectionReason? rejectionReason,
    List<KycResubmitStep> resubmitSteps = const <KycResubmitStep>[],
    int? statusReads,
  }) {
    final KycWizardCubit cubit = KycWizardCubit(
      pickerService: StubPhotoPickerService(cameraPayload: idCardBytes),
      gateway: KycWizardScreenPreviewGateway(
        initial: KycSubmission(
          status: status,
          rejectionReason: rejectionReason,
          resubmitSteps: resubmitSteps,
        ),
        statusReads: statusReads,
      ),
    );
    unawaited(cubit.loadStatus());
    return cubit;
  }

  /// The cold-start SCHEMA path, held at the moment `GET
  /// /v1/kyc/jeeb/form-schema` has been asked for and has not answered.
  static KycWizardCubit schemaLoadingCubit() {
    final KycWizardCubit cubit = KycWizardCubit(
      pickerService: StubPhotoPickerService(cameraPayload: idCardBytes),
      gateway: KycWizardScreenPreviewGateway(schemaStalls: true),
    );
    unawaited(cubit.loadSchema());
    return cubit;
  }
}

/// The real cubit over inert collaborators, parked on `seed`.
/// Emitting once from the constructor is the whole implementation, and it is
/// the only way to put a captured [PhotoAttachment], a submit-scoped field
class _SeededKycWizardCubit extends KycWizardCubit {
  _SeededKycWizardCubit(KycWizardState seed, KycGateway gateway)
      : super(
          // Canned bytes, so a capture tapped in the catalog fills with the ID
          pickerService: StubPhotoPickerService(
            cameraPayload: KycWizardScreenPreviewFixtures.idCardBytes,
          ),
          gateway: gateway,
        ) {
    emit(seed);
  }
}
