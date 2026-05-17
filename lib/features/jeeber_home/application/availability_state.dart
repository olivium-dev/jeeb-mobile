import 'package:equatable/equatable.dart';

import '../domain/entities/availability_status.dart';

/// Cold-start phase the cubit is in. Drives whether the screen shows the
/// shimmer, the toggle, or an error retry.
enum AvailabilityLoadPhase { initial, loading, ready, loadError }

/// View-model bundle the cubit emits for every state change. Equatable
/// so bloc_test can compare frame-by-frame.
class AvailabilityViewState extends Equatable {
  const AvailabilityViewState({
    this.loadPhase = AvailabilityLoadPhase.initial,
    this.status = AvailabilityStatus.initial,
    this.isToggleInFlight = false,
    this.toggleError = false,
    this.warningVisible = false,
  });

  /// Where the cubit is in its cold-start fetch.
  final AvailabilityLoadPhase loadPhase;

  /// Last known availability snapshot (echoed from the gateway).
  final AvailabilityStatus status;

  /// `true` while a `PUT /api/availability/toggle` is in-flight. UI
  /// disables the switch and shows the transitioning subtitle.
  final bool isToggleInFlight;

  /// `true` if the last toggle attempt failed. Cleared on the next
  /// successful toggle.
  final bool toggleError;

  /// `true` once the inactivity ticker observes that the Jeeber has been
  /// online for >= 7h30 without activity. Stays true until either the
  /// 8h auto-offline fires or the Jeeber taps to extend.
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
