import 'package:equatable/equatable.dart';

import '../domain/entities/availability_status.dart';
import '../domain/services/availability_gateway.dart';

enum AvailabilityLoadPhase { initial, loading, ready, loadError }

class AvailabilityViewState extends Equatable {
  const AvailabilityViewState({
    this.loadPhase = AvailabilityLoadPhase.initial,
    this.status = AvailabilityStatus.initial,
    this.isToggleInFlight = false,
    this.toggleError = false,
    this.warningVisible = false,
    this.locationOutcome = GoOnlineLocationOutcome.notApplicable,
  });

  final AvailabilityLoadPhase loadPhase;

  final AvailabilityStatus status;

  final bool isToggleInFlight;

  final bool toggleError;

  final bool warningVisible;

  final GoOnlineLocationOutcome locationOutcome;

  AvailabilityViewState copyWith({
    AvailabilityLoadPhase? loadPhase,
    AvailabilityStatus? status,
    bool? isToggleInFlight,
    bool? toggleError,
    bool? warningVisible,
    GoOnlineLocationOutcome? locationOutcome,
  }) {
    return AvailabilityViewState(
      loadPhase: loadPhase ?? this.loadPhase,
      status: status ?? this.status,
      isToggleInFlight: isToggleInFlight ?? this.isToggleInFlight,
      toggleError: toggleError ?? this.toggleError,
      warningVisible: warningVisible ?? this.warningVisible,
      locationOutcome: locationOutcome ?? this.locationOutcome,
    );
  }

  @override
  List<Object?> get props => [
        loadPhase,
        status,
        isToggleInFlight,
        toggleError,
        warningVisible,
        locationOutcome,
      ];
}
