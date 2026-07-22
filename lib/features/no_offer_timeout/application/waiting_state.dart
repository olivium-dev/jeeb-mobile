import 'package:equatable/equatable.dart';

import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

/// Cold-load lifecycle of the waiting screen.
enum WaitingScreenStatus { initial, loading, loaded, failed }

class WaitingState extends Equatable {
  const WaitingState({
    this.status = WaitingScreenStatus.initial,
    this.request,
    this.now,
    this.error,
  });

  final WaitingScreenStatus status;

  /// Latest snapshot; null before the first load resolves.
  final WaitingRequest? request;

  /// The cubit's injected "now", advanced each clock tick so the countdown
  /// rebuilds deterministically (tests fast-forward via [WaitingCubit.tick]).
  final DateTime? now;

  final WaitingFailure? error;

  bool get isLoading =>
      status == WaitingScreenStatus.loading ||
      status == WaitingScreenStatus.initial;

  /// True once the broadcast window has fully elapsed with zero offers in —
  /// the ONLY signal that drives the softened "No offers yet" state. Clock-aware
  /// (uses [remaining], which is derived from the injected [now]) and decoupled
  /// from [WaitingRequest.notifiedCount], which the gateway never populates
  /// (jeebers pull `GET /v1/jeebers/me/feed`; there is no push-notify counter).
  bool get isNoOffersYet =>
      request != null &&
      !isTerminal &&
      !hasOffers &&
      remaining == Duration.zero;

  /// True once at least one offer has arrived — drives the review-offers CTA.
  bool get hasOffers => !isTerminal && (request?.hasOffers ?? false);

  /// True when the server says this request has left the waiting flow.
  bool get isTerminal => request?.phase.isTerminal ?? false;

  /// Remaining time until the broadcast deadline, clamped at zero. Returns
  /// [Duration.zero] when there is no snapshot/deadline yet so the countdown
  /// label can render a stable "0:00".
  Duration get remaining {
    if (isTerminal) return Duration.zero;
    final deadline = request?.broadcastExpiresAt;
    final clock = now;
    if (deadline == null || clock == null) return Duration.zero;
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
