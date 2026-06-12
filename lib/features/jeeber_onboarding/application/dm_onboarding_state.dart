import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

/// The three steps of the delivery-man onboarding wizard, in order. Mirrors
/// the Figma flow: photo (56591:5323) → address (56591:4109) → service area
/// (56591:5337). The progress bar fills `index + 1 / values.length`.
enum DmOnboardingStep {
  photo,
  address,
  serviceArea;

  /// Resolves a step from a slug (used by the deep-link / dev-seam `step`
  /// query param). Unknown/empty slugs fall back to [photo].
  static DmOnboardingStep fromSlug(String? slug) {
    switch (slug) {
      case 'address':
        return DmOnboardingStep.address;
      case 'service-area':
        return DmOnboardingStep.serviceArea;
      default:
        return DmOnboardingStep.photo;
    }
  }
}

/// Transient, one-shot error surfaces produced by the cubit. The view renders
/// the matching copy then calls [acknowledgeError] so it isn't replayed.
enum DmOnboardingError { photoPickFailed, submitFailed }

/// Immutable snapshot of the delivery-man onboarding wizard.
///
/// Holds the captured photo, the address-step text fields, the chosen primary
/// location, and the service-area radius. The cubit is the single source of
/// truth for step transitions; the view is a pure function of this state.
class DmOnboardingState extends Equatable {
  const DmOnboardingState({
    this.step = DmOnboardingStep.photo,
    this.photo,
    this.state = '',
    this.country = '',
    this.street = '',
    this.vehicleNumber = '',
    this.address = '',
    this.primaryLocation = '',
    this.distanceKm = defaultDistanceKm,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.error,
  });

  /// Slider bounds for the service-area radius (BR pending — flag F-22-2).
  static const int minDistanceKm = 1;
  static const int maxDistanceKm = 150;
  static const int defaultDistanceKm = 80;

  final DmOnboardingStep step;
  final PhotoAttachment? photo;
  final String state;
  final String country;
  final String street;
  final String vehicleNumber;
  final String address;
  final String primaryLocation;
  final int distanceKm;
  final bool isSubmitting;
  final bool isSubmitted;
  final DmOnboardingError? error;

  bool get hasPhoto => photo != null;
  bool get hasPrimaryLocation => primaryLocation.trim().isNotEmpty;

  /// Number of steps the user has completed — drives the progress bar so the
  /// fill is `(stepIndex) / totalSteps` on entry and reaches full on submit.
  int get completedSteps => isSubmitted ? totalSteps : step.index;

  /// One-based position of the current step for the screen-reader label.
  int get currentStepNumber => step.index + 1;

  static int get totalSteps => DmOnboardingStep.values.length;

  DmOnboardingState copyWith({
    DmOnboardingStep? step,
    PhotoAttachment? photo,
    bool clearPhoto = false,
    String? state,
    String? country,
    String? street,
    String? vehicleNumber,
    String? address,
    String? primaryLocation,
    int? distanceKm,
    bool? isSubmitting,
    bool? isSubmitted,
    DmOnboardingError? error,
    bool clearError = false,
  }) {
    return DmOnboardingState(
      step: step ?? this.step,
      photo: clearPhoto ? null : (photo ?? this.photo),
      state: state ?? this.state,
      country: country ?? this.country,
      street: street ?? this.street,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      address: address ?? this.address,
      primaryLocation: primaryLocation ?? this.primaryLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        step,
        photo,
        state,
        country,
        street,
        vehicleNumber,
        address,
        primaryLocation,
        distanceKm,
        isSubmitting,
        isSubmitted,
        error,
      ];
}
