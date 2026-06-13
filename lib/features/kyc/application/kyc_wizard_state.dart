import 'package:equatable/equatable.dart';

import '../domain/kyc_contract_template.dart';
import '../domain/kyc_form_schema.dart';
import '../domain/kyc_submission.dart';

/// Which step the wizard is currently showing.
///
/// Steps in order:
///   schema → id → selfie → vehicle → tos → submitting → status
///
/// [schema] is the loading state while fetching the form schema from the server.
/// [tos] shows the ToS contract + signature pad before final submit.
enum KycWizardStep {
  schema,
  id,
  selfie,
  vehicle,
  tos,
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
  vehicleRegistrationRequired,
  submitFailed,
  schemaLoadFailed,
  contractLoadFailed,
  signFailed,
  fileTooLarge,
  fileTypeNotAllowed,
}

class KycWizardState extends Equatable {
  const KycWizardState({
    this.step = KycWizardStep.schema,
    this.submission = const KycSubmission(status: KycStatus.notSubmitted),
    this.formSchema,
    this.contractTemplate,
    this.tosAcceptedVersion,
    this.capturing,
    this.error,
    this.isLoadingStatus = false,
  });

  /// Total capture steps (ID + selfie + vehicle) for the progress indicator.
  static const int totalCaptureSteps = 3;

  final KycWizardStep step;
  final KycSubmission submission;

  /// Loaded schema — null until the gateway returns it.
  final KycFormSchema? formSchema;

  /// Loaded ToS contract template — null until the ToS step loads it.
  final KycContractTemplate? contractTemplate;

  /// ToS version accepted by the user (populated after signing).
  final String? tosAcceptedVersion;

  /// Non-null while a camera capture is in flight.
  final KycCaptureSlot? capturing;

  final KycWizardError? error;

  /// True while [KycWizardCubit.loadStatus] is in flight.
  final bool isLoadingStatus;

  bool get isCapturing => capturing != null;
  bool get hasSignedTos => tosAcceptedVersion != null;

  int get completedCaptureSteps {
    switch (step) {
      case KycWizardStep.schema:
        return 0;
      case KycWizardStep.id:
        return submission.hasIdFront && submission.hasIdBack ? 1 : 0;
      case KycWizardStep.selfie:
        return 1;
      case KycWizardStep.vehicle:
        return 2;
      case KycWizardStep.tos:
      case KycWizardStep.submitting:
      case KycWizardStep.status:
        return totalCaptureSteps;
    }
  }

  bool get canAdvanceFromId =>
      submission.hasIdFront && submission.hasIdBack && !isCapturing;
  bool get canAdvanceFromSelfie => submission.hasSelfie && !isCapturing;
  bool get canAdvanceFromVehicle =>
      submission.vehicleType != null &&
      submission.vehicleRegistration.trim().isNotEmpty &&
      !isCapturing;

  KycWizardState copyWith({
    KycWizardStep? step,
    KycSubmission? submission,
    KycFormSchema? formSchema,
    KycContractTemplate? contractTemplate,
    String? tosAcceptedVersion,
    bool clearTosVersion = false,
    KycCaptureSlot? capturing,
    bool clearCapturing = false,
    KycWizardError? error,
    bool clearError = false,
    bool? isLoadingStatus,
  }) {
    return KycWizardState(
      step: step ?? this.step,
      submission: submission ?? this.submission,
      formSchema: formSchema ?? this.formSchema,
      contractTemplate: contractTemplate ?? this.contractTemplate,
      tosAcceptedVersion: clearTosVersion
          ? null
          : (tosAcceptedVersion ?? this.tosAcceptedVersion),
      capturing: clearCapturing ? null : (capturing ?? this.capturing),
      error: clearError ? null : (error ?? this.error),
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
    );
  }

  @override
  List<Object?> get props => [
        step,
        submission,
        formSchema,
        contractTemplate,
        tosAcceptedVersion,
        capturing,
        error,
        isLoadingStatus,
      ];
}
