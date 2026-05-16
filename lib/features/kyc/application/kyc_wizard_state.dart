import 'package:equatable/equatable.dart';

import '../domain/kyc_submission.dart';

/// Which step the wizard is currently showing. The wizard host renders a
/// different child per step; the cubit is the single source of truth for
/// transitions.
enum KycWizardStep { id, selfie, vehicle, submitting, status }

/// Which capture slot the cubit is currently filling. Surfaced so the view
/// can disable the other capture buttons while a pick is in flight.
enum KycCaptureSlot { idFront, idBack, selfie }

/// Transient error surfaces produced by the wizard cubit. One-shot — the view
/// renders the corresponding copy and calls [KycWizardCubit.acknowledgeError]
/// so the same error isn't replayed on the next rebuild.
enum KycWizardError {
  pickCancelled,
  permissionDenied,
  unavailable,
  compressionFailed,
  vehicleRegistrationRequired,
  submitFailed,
}

class KycWizardState extends Equatable {
  const KycWizardState({
    this.step = KycWizardStep.id,
    this.submission = const KycSubmission(status: KycStatus.notSubmitted),
    this.capturing,
    this.error,
    this.isLoadingStatus = false,
  });

  /// Total step count for the progress indicator. Submitting/status are not
  /// counted — the progress bar is full once review is reached.
  static const int totalCaptureSteps = 3;

  final KycWizardStep step;
  final KycSubmission submission;

  /// Non-null while a camera capture is in flight. Lets the UI disable buttons
  /// and surface a spinner without racing concurrent captures.
  final KycCaptureSlot? capturing;

  final KycWizardError? error;

  /// True while [KycWizardCubit.loadStatus] is in flight (status screen cold
  /// load). Distinct from [capturing] so the wizard view doesn't confuse a
  /// camera pick with a status refresh.
  final bool isLoadingStatus;

  bool get isCapturing => capturing != null;

  /// Number of capture steps the user has finished — drives the progress bar.
  int get completedCaptureSteps {
    switch (step) {
      case KycWizardStep.id:
        // Both sides required to count step 1 as complete.
        return submission.hasIdFront && submission.hasIdBack ? 1 : 0;
      case KycWizardStep.selfie:
        return 1;
      case KycWizardStep.vehicle:
        return 2;
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
    KycCaptureSlot? capturing,
    bool clearCapturing = false,
    KycWizardError? error,
    bool clearError = false,
    bool? isLoadingStatus,
  }) {
    return KycWizardState(
      step: step ?? this.step,
      submission: submission ?? this.submission,
      capturing: clearCapturing ? null : (capturing ?? this.capturing),
      error: clearError ? null : (error ?? this.error),
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
    );
  }

  @override
  List<Object?> get props => [
        step,
        submission,
        capturing,
        error,
        isLoadingStatus,
      ];
}
