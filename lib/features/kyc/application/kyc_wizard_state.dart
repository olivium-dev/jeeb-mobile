import 'package:equatable/equatable.dart';

import '../domain/kyc_contract_template.dart';
import '../domain/kyc_form_schema.dart';
import '../domain/kyc_submission.dart';

/// Which step the wizard is currently showing.
enum KycWizardStep {
  schema,
  identity,
  submitting,
  status,
}

enum KycCaptureSlot { idFront, idBack, selfie }

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

  submitValidationFailed,
}

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

  final KycFormSchema? formSchema;

  final KycContractTemplate? contractTemplate;

  final String? tosAcceptedVersion;

  final bool tosAccepted;

  final KycCaptureSlot? capturing;

  final KycWizardError? error;

  final KycSubmitFieldError? submitFieldError;

  final bool isLoadingStatus;

  /// One-shot flag set true when a FRESH submit succeeds, so the presentation
  /// layer can navigate to `onboarding-funding` (JM-040 → JM-041) exactly once
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
