import 'package:equatable/equatable.dart';

import '../domain/cancel_request_repository.dart';

/// Lifecycle of the JM-030 cancel action.
///
/// The sheet starts `idle` (showing the free-before-accept note + the two
/// CTAs). Tapping confirm → `inFlight` (CTAs disabled) → `succeeded` (the
/// sheet's host routes to `customer-orders-home`) or `failed` (transient error;
/// the sheet stays open so the user can retry or keep the request).
enum CancelRequestStatus { idle, inFlight, succeeded, failed }

class CancelRequestState extends Equatable {
  const CancelRequestState({
    this.status = CancelRequestStatus.idle,
    this.error,
  });

  final CancelRequestStatus status;
  final CancelRequestFailure? error;

  bool get isInFlight => status == CancelRequestStatus.inFlight;

  CancelRequestState copyWith({
    CancelRequestStatus? status,
    CancelRequestFailure? error,
    bool clearError = false,
  }) =>
      CancelRequestState(
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, error];
}
