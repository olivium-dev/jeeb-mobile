import 'package:equatable/equatable.dart';

import '../domain/delivery_snapshot.dart';

/// High-level UI mode the screen renders for. `loading` is the cold-load
/// state before the first snapshot lands; `ready` is the normal pipeline;
/// `error` is the stream-closed/transport-failed catch-all.
enum DeliveryStatusViewMode { loading, ready, error }

/// One-shot transient surfaces — toasts, banner errors. The view renders the
/// corresponding copy then calls [DeliveryStatusCubit.acknowledgeError] so
/// the same surface isn't replayed on the next rebuild.
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

  /// Latest snapshot from the gateway. Null while [mode] is `loading` and
  /// possibly stale once [mode] flips to `error`.
  final DeliverySnapshot? snapshot;

  /// True between the user tapping Cancel and the gateway response landing.
  /// Surfaced so the button can show a spinner and ignore duplicate taps.
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
