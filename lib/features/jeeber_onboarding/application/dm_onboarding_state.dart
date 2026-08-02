import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

enum DmOnboardingStep {
  photo,
  address,
  serviceArea;

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

enum DmOnboardingError { photoPickFailed, submitFailed }

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

  final DmOnboardingHomeBase? homeBase;

  final bool isSubmitting;
  final bool isSubmitted;

  final bool coverageReady;

  final DmOnboardingError? error;

  bool get hasPhoto => photo != null;

  bool get hasHomeBase => homeBase != null;

  int get completedSteps => isSubmitted ? totalSteps : step.index;

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
