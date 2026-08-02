import 'package:equatable/equatable.dart';

import '../domain/cancel_request_repository.dart';

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
