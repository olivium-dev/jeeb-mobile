import 'package:equatable/equatable.dart';

import '../domain/kyc_contract_template.dart';
import '../domain/kyc_form_schema.dart';
import '../domain/kyc_submission.dart';

/// Which step the wizard is currently showing.
///
/// Steps in order:
///   schema → identity → submitting → status
///
/// [schema] is the loading state while fetching the form schema from the server.
/// [identity] is the single capture screen (gov-ID front/back + selfie + ToS
/// acceptance) per the `kyc-identity` blueprint. The Vehicle step was removed
/// under D20 (JM-040): the platform is COD/cash-on-delivery and never collected
/// a vehicle. [submitting] is the in-flight upload; [status] is the terminal
/// pending/approved/rejected view shown when re-entering an already-submitted
/// KYC (the fresh-submit happy path instead chains to onboarding-funding).
enum KycWizardStep {
  schema,
  identity,
  submitting,
  status,
}

/// Which capture slot the cubit is currently filling.
enum KycCaptureSlot { idFront, idBack, selfie }

/// Transient error surfaces produced by the wizard cubit.
enum KycWizardError {
  pickCancelled,
  permissionDenied,
  unavailable,
  compressionFailed,
  submitFailed,
  schemaLoadFailed,
  contractLoadFailed,
  signFailed,
  fileTooLarge,
  fileTypeNotAllowed,

  /// JEBV4-295: a field-scoped BFF 400 whose `field` extension names a field
  /// the client has no inline surface for (unlike `id_number`/`id_type`).
  /// This IS a validation rejection, not a connectivity failure — kept
  /// distinct from [submitFailed] so the surfaced copy never mislabels a
  /// "your submission is invalid" 400 as a "check your connection" toast.
  submitValidationFailed,
}

/// A submit failure scoped to a single identity field, surfaced INLINE on the
/// field itself (never as the generic submit-failed snackbar). Produced either
/// by the client-side pre-submit gate or by the BFF's field-scoped RFC-7807
/// 400 (`field: "id_number"` / `"id_type"`) — JEBV4-113 review finding 1.
enum KycSubmitFieldError { idNumber, idType }

class KycWizardState extends Equatable {
  const KycWizardState({
    this.step = KycWizardStep.schema,
    this.submission = const KycSubmission(status: KycStatus.notSubmitted),
    this.formSchema,
    this.contractTemplate,
    this.tosAcceptedVersion,
    this.tosAccepted = false,
    this.capturing,
    this.error,
    this.submitFieldError,
    this.isLoadingStatus = false,
    this.justSubmitted = false,
  });

  /// Total capture steps (ID + selfie) for the progress indicator. The Vehicle
  /// step was removed under D20 (JM-040), dropping this from 3 → 2.
  static const int totalCaptureSteps = 2;

  final KycWizardStep step;
  final KycSubmission submission;

  /// Loaded schema — null until the gateway returns it.
  final KycFormSchema? formSchema;

  /// Loaded ToS contract template — null until the identity step loads it.
  final KycContractTemplate? contractTemplate;

  /// ToS version accepted by the user (populated after signing).
  final String? tosAcceptedVersion;

  /// Whether the user has ticked the ToS acceptance control on the identity
  /// screen. Gates the submit CTA together with the captured photos.
  final bool tosAccepted;

  /// Non-null while a camera capture is in flight.
  final KycCaptureSlot? capturing;

  final KycWizardError? error;

  /// Field-scoped submit failure rendered inline on the offending identity
  /// field (see [KycSubmitFieldError]). Cleared when the user edits the field.
  final KycSubmitFieldError? submitFieldError;

  /// True while [KycWizardCubit.loadStatus] is in flight.
  final bool isLoadingStatus;

  /// One-shot flag set true when a FRESH submit succeeds, so the presentation
  /// layer can navigate to `onboarding-funding` (JM-040 → JM-041) exactly once
  /// instead of rendering the standalone status view. Re-entries that load an
  /// already-submitted status leave this false.
  final bool justSubmitted;

  bool get isCapturing => capturing != null;
  bool get hasSignedTos => tosAcceptedVersion != null;

  int get completedCaptureSteps {
    switch (step) {
      case KycWizardStep.schema:
        return 0;
      case KycWizardStep.identity:
        final idDone = submission.hasIdFront && submission.hasIdBack;
        final selfieDone = submission.hasSelfie;
        if (idDone && selfieDone) return totalCaptureSteps;
        if (idDone) return 1;
        return 0;
      case KycWizardStep.submitting:
      case KycWizardStep.status:
        return totalCaptureSteps;
    }
  }

  /// Whether the identity screen has everything it needs to submit: both ID
  /// sides, a selfie, a contract-valid ID number (E3/JEBV4-197 — required for
  /// every [KycIdType]), and the ToS acceptance — and no capture in flight.
  bool get canSubmitIdentity =>
      submission.hasIdFront &&
      submission.hasIdBack &&
      submission.hasSelfie &&
      submission.hasValidIdNumber &&
      tosAccepted &&
      !isCapturing;

  KycWizardState copyWith({
    KycWizardStep? step,
    KycSubmission? submission,
    KycFormSchema? formSchema,
    KycContractTemplate? contractTemplate,
    String? tosAcceptedVersion,
    bool clearTosVersion = false,
    bool? tosAccepted,
    KycCaptureSlot? capturing,
    bool clearCapturing = false,
    KycWizardError? error,
    bool clearError = false,
    KycSubmitFieldError? submitFieldError,
    bool clearSubmitFieldError = false,
    bool? isLoadingStatus,
    bool? justSubmitted,
  }) {
    return KycWizardState(
      step: step ?? this.step,
      submission: submission ?? this.submission,
      formSchema: formSchema ?? this.formSchema,
      contractTemplate: contractTemplate ?? this.contractTemplate,
      tosAcceptedVersion: clearTosVersion
          ? null
          : (tosAcceptedVersion ?? this.tosAcceptedVersion),
      tosAccepted: tosAccepted ?? this.tosAccepted,
      capturing: clearCapturing ? null : (capturing ?? this.capturing),
      error: clearError ? null : (error ?? this.error),
      submitFieldError: clearSubmitFieldError
          ? null
          : (submitFieldError ?? this.submitFieldError),
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
      justSubmitted: justSubmitted ?? this.justSubmitted,
    );
  }

  @override
  List<Object?> get props => [
        step,
        submission,
        formSchema,
        contractTemplate,
        tosAcceptedVersion,
        tosAccepted,
        capturing,
        error,
        submitFieldError,
        isLoadingStatus,
        justSubmitted,
      ];
}
