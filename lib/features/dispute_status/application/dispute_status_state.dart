import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/dispute_status_repository.dart';

enum DisputeStatusViewStatus { initial, loading, loaded, failed }

class DisputeStatusState extends Equatable {
  const DisputeStatusState({
    this.status = DisputeStatusViewStatus.initial,
    this.dispute,
    this.error,
    this.failure,
    this.refreshError,
  });

  final DisputeStatusViewStatus status;

  final DisputeStatus? dispute;

  final DisputeStatusFailure? error;

  /// The classified cold-read failure.
  final AppFailure? failure;

  /// A refresh that failed over rows already on screen.
  final AppFailure? refreshError;

  bool get isResolved => dispute?.isResolved ?? false;

  DisputeStatusState copyWith({
    DisputeStatusViewStatus? status,
    DisputeStatus? dispute,
    DisputeStatusFailure? error,
    AppFailure? failure,
    AppFailure? refreshError,
    bool clearError = false,
    bool clearFailure = false,
    bool clearRefreshError = false,
  }) {
    return DisputeStatusState(
      status: status ?? this.status,
      dispute: dispute ?? this.dispute,
      error: clearError ? null : (error ?? this.error),
      failure: (clearError || clearFailure) ? null : (failure ?? this.failure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => [status, dispute, error, failure, refreshError];
}
