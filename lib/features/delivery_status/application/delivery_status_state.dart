import 'package:equatable/equatable.dart';

import '../domain/delivery_snapshot.dart';

enum DeliveryStatusViewMode { loading, ready, error }

enum DeliveryStatusError {
  cancelTooLate,
  cancelNetwork,
  contactUnavailable,
  streamLost,
}

class DeliveryStatusState extends Equatable {
  const DeliveryStatusState({
    this.mode = DeliveryStatusViewMode.loading,
    this.snapshot,
    this.isCancelling = false,
    this.error,
  });

  /// Which top-level UI to render — covers cold load and stream failure
  /// without coupling those branches to a null [snapshot] check.
  final DeliveryStatusViewMode mode;

  final DeliverySnapshot? snapshot;

  final bool isCancelling;

  /// One-shot UI surface — see [DeliveryStatusError].
  final DeliveryStatusError? error;

  DeliveryStatusState copyWith({
    DeliveryStatusViewMode? mode,
    DeliverySnapshot? snapshot,
    bool? isCancelling,
    DeliveryStatusError? error,
    bool clearError = false,
  }) {
    return DeliveryStatusState(
      mode: mode ?? this.mode,
      snapshot: snapshot ?? this.snapshot,
      isCancelling: isCancelling ?? this.isCancelling,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [mode, snapshot, isCancelling, error];
}
