import 'package:equatable/equatable.dart';

import '../domain/dispute_status_repository.dart';

/// Top-level UI status for dispute-status (JM-065) — the canonical 4-state
/// machine (40_GUARDRAILS_ARCH §2.1 / §3). There is no `empty` sub-state here:
/// a dispute either loads (content) or fails (a missing dispute is a `failed`
/// with [DisputeStatusFailure.notFound], not an empty list).
enum DisputeStatusViewStatus {
  /// Cold load — nothing fetched yet.
  initial,

  /// First fetch is on the wire.
  loading,

  /// The dispute loaded.
  loaded,

  /// The cold load failed (network / 404 / auth / unknown).
  failed,
}

/// Immutable state for the dispute-status screen.
///
/// [dispute] is the loaded snapshot (null until [DisputeStatusViewStatus.loaded]).
/// [error] is a typed [DisputeStatusFailure] from the last load/refresh —
/// never a raw exception or string (40_GUARDRAILS_ARCH §2.1).
class DisputeStatusState extends Equatable {
  const DisputeStatusState({
    this.status = DisputeStatusViewStatus.initial,
    this.dispute,
    this.error,
  });

  final DisputeStatusViewStatus status;

  /// The loaded dispute snapshot (null until loaded).
  final DisputeStatus? dispute;

  /// One-shot typed error from the last load / refresh.
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
