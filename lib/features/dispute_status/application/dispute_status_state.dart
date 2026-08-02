import 'package:equatable/equatable.dart';

import '../domain/dispute_status_repository.dart';

enum DisputeStatusViewStatus {
  initial,

  loading,

  loaded,

  failed,
}

class DisputeStatusState extends Equatable {
  const DisputeStatusState({
    this.status = DisputeStatusViewStatus.initial,
    this.dispute,
    this.error,
  });

  final DisputeStatusViewStatus status;

  final DisputeStatus? dispute;

  final DisputeStatusFailure? error;

  bool get isResolved => dispute?.isResolved ?? false;

  DisputeStatusState copyWith({
    DisputeStatusViewStatus? status,
    DisputeStatus? dispute,
    DisputeStatusFailure? error,
    bool clearError = false,
  }) {
    return DisputeStatusState(
      status: status ?? this.status,
      dispute: dispute ?? this.dispute,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, dispute, error];
}
