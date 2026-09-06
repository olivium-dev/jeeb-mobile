import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/entities/availability_status.dart';
import '../domain/services/availability_gateway.dart';

enum AvailabilityLoadPhase { initial, loading, ready, loadError, notRegistered }

class AvailabilityViewState extends Equatable {
  const AvailabilityViewState({
    this.loadPhase = AvailabilityLoadPhase.initial,
    this.status = AvailabilityStatus.initial,
    this.isToggleInFlight = false,
    this.toggleError = false,
    this.warningVisible = false,
    this.locationOutcome = GoOnlineLocationOutcome.notApplicable,
    this.loadError,
    this.toggleFailure,
  });

  final AvailabilityLoadPhase loadPhase;

  final AvailabilityStatus status;

  final bool isToggleInFlight;

  final bool toggleError;

  final bool warningVisible;

  final GoOnlineLocationOutcome locationOutcome;

  /// The classified cold-read failure behind [AvailabilityLoadPhase.loadError].
  final AppFailure? loadError;

  /// The classified toggle failure; [toggleError] stays its boolean twin.
  final AppFailure? toggleFailure;

  AvailabilityViewState copyWith({
    AvailabilityLoadPhase? loadPhase,
    AvailabilityStatus? status,
    bool? isToggleInFlight,
    bool? toggleError,
    bool? warningVisible,
    GoOnlineLocationOutcome? locationOutcome,
    Object? loadError = _sentinel,
    Object? toggleFailure = _sentinel,
  }) {
    return AvailabilityViewState(
      loadPhase: loadPhase ?? this.loadPhase,
      status: status ?? this.status,
      isToggleInFlight: isToggleInFlight ?? this.isToggleInFlight,
      toggleError: toggleError ?? this.toggleError,
      warningVisible: warningVisible ?? this.warningVisible,
      locationOutcome: locationOutcome ?? this.locationOutcome,
      loadError: identical(loadError, _sentinel)
          ? this.loadError
          : loadError as AppFailure?,
      toggleFailure: identical(toggleFailure, _sentinel)
          ? this.toggleFailure
          : toggleFailure as AppFailure?,
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
        loadError,
        toggleFailure,
      ];
}

const Object _sentinel = Object();
