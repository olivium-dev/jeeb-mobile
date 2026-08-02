import 'package:equatable/equatable.dart';

import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

enum WaitingScreenStatus { initial, loading, loaded, failed }

class WaitingState extends Equatable {
  const WaitingState({
    this.status = WaitingScreenStatus.initial,
    this.request,
    this.now,
    this.error,
  });

  final WaitingScreenStatus status;

  final WaitingRequest? request;

  final DateTime? now;

  final WaitingFailure? error;

  bool get isLoading =>
      status == WaitingScreenStatus.loading ||
      status == WaitingScreenStatus.initial;

  bool get isNoOffersYet =>
      request != null &&
      !isTerminal &&
      !hasOffers &&
      remaining == Duration.zero;

  bool get hasOffers => !isTerminal && (request?.hasOffers ?? false);

  bool get isTerminal => request?.phase.isTerminal ?? false;

  Duration? get remaining {
    if (isTerminal) return null;
    final deadline = request?.deadline;
    final clock = now;
    if (deadline == null || clock == null) return null;
    final delta = deadline.difference(clock);
    return delta.isNegative ? Duration.zero : delta;
  }

  WaitingState copyWith({
    WaitingScreenStatus? status,
    WaitingRequest? request,
    DateTime? now,
    WaitingFailure? error,
    bool clearError = false,
  }) => WaitingState(
    status: status ?? this.status,
    request: request ?? this.request,
    now: now ?? this.now,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [status, request, now, error];
}
