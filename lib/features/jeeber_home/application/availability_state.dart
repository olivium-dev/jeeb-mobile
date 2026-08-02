import 'package:equatable/equatable.dart';

import '../domain/entities/availability_status.dart';

enum AvailabilityLoadPhase { initial, loading, ready, loadError }

class AvailabilityViewState extends Equatable {
  const AvailabilityViewState({
    this.loadPhase = AvailabilityLoadPhase.initial,
    this.status = AvailabilityStatus.initial,
    this.isToggleInFlight = false,
    this.toggleError = false,
    this.warningVisible = false,
  });

  final AvailabilityLoadPhase loadPhase;

  final AvailabilityStatus status;

  final bool isToggleInFlight;

  final bool toggleError;

  final bool warningVisible;

  AvailabilityViewState copyWith({
    AvailabilityLoadPhase? loadPhase,
    AvailabilityStatus? status,
    bool? isToggleInFlight,
    bool? toggleError,
    bool? warningVisible,
  }) {
    return AvailabilityViewState(
      loadPhase: loadPhase ?? this.loadPhase,
      status: status ?? this.status,
      isToggleInFlight: isToggleInFlight ?? this.isToggleInFlight,
      toggleError: toggleError ?? this.toggleError,
      warningVisible: warningVisible ?? this.warningVisible,
    );
  }

  @override
  List<Object?> get props => [
        loadPhase,
        status,
        isToggleInFlight,
        toggleError,
        warningVisible,
      ];
}
