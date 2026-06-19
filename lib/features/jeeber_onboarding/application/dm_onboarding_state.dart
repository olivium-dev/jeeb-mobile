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

/// The chosen home-base point for the service-area step (JM-038 / D51).
///
/// Replaces the removed distance slider: a Jeeber pins a single home base
/// rather than a working radius. `lat`/`lng` are the pinned coordinates;
/// `label` is the human-readable place text surfaced on the selector row. A
/// null home base means none has been pinned yet, so Continue stays disabled.
class DmOnboardingHomeBase extends Equatable {
  const DmOnboardingHomeBase({
    required this.lat,
    required this.lng,
    this.label = '',
  });

  final double lat;
  final double lng;
  final String label;

  @override
  List<Object?> get props => [lat, lng, label];
}

/// Immutable snapshot of the delivery-man onboarding wizard.
///
/// Holds the captured photo, the address-step text fields, and the chosen
/// service-area home base. The cubit is the single source of truth for step
/// transitions; the view is a pure function of this state.
class DmOnboardingState extends Equatable {
  const DmOnboardingState({
    this.step = DmOnboardingStep.photo,
    this.photo,
    this.state = '',
    this.country = '',
    this.street = '',
    this.address = '',
    this.homeBase,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.coverageReady = false,
    this.error,
  });

  final DmOnboardingStep step;
  final PhotoAttachment? photo;
  final String state;
  final String country;
  final String street;
  final String address;

  /// The pinned service-area home base (JM-038, D51). Null until the Jeeber
  /// picks a location via the map-pin screen.
  final DmOnboardingHomeBase? homeBase;

  final bool isSubmitting;
  final bool isSubmitted;

  /// True once the service-area coverage check (find-jeebers against the home
  /// base) has resolved, so the host may chain on to KYC identity (JM-038 AC4).
  final bool coverageReady;

  final DmOnboardingError? error;

  bool get hasPhoto => photo != null;

  /// Whether a home base has been pinned. Drives the service-area Continue gate
  /// (JM-038 AC2 — a home base is required).
  bool get hasHomeBase => homeBase != null;

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
    String? address,
    DmOnboardingHomeBase? homeBase,
    bool clearHomeBase = false,
    bool? isSubmitting,
    bool? isSubmitted,
    bool? coverageReady,
    DmOnboardingError? error,
    bool clearError = false,
  }) {
    return DmOnboardingState(
      step: step ?? this.step,
      photo: clearPhoto ? null : (photo ?? this.photo),
      state: state ?? this.state,
      country: country ?? this.country,
      street: street ?? this.street,
      address: address ?? this.address,
      homeBase: clearHomeBase ? null : (homeBase ?? this.homeBase),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      coverageReady: coverageReady ?? this.coverageReady,
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
        address,
        homeBase,
        isSubmitting,
        isSubmitted,
        coverageReady,
        error,
      ];
}
