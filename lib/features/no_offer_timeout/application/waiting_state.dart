import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

enum WaitingScreenStatus { initial, loading, loaded, failed }

class WaitingState extends Equatable {
  const WaitingState({
    this.status = WaitingScreenStatus.initial,
    this.request,
    this.now,
    this.error,
    this.appFailure,
    this.refreshError,
    this.offerCountUnavailable = false,
  });

  final WaitingScreenStatus status;

  final WaitingRequest? request;

  final DateTime? now;

  final WaitingFailure? error;

  /// The classified failure behind [error].
  final AppFailure? appFailure;

  /// A background refresh that failed while the request is on screen.
  final AppFailure? refreshError;

  /// The offer probe could not be read; the count line says so, never `0`.
  final bool offerCountUnavailable;

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
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool? offerCountUnavailable,
    bool clearError = false,
    bool clearRefreshError = false,
  }) => WaitingState(
    status: status ?? this.status,
    request: request ?? this.request,
    now: now ?? this.now,
    error: clearError ? error : (error ?? this.error),
    appFailure: clearError ? appFailure : (appFailure ?? this.appFailure),
    refreshError:
        clearRefreshError ? refreshError : (refreshError ?? this.refreshError),
    offerCountUnavailable: offerCountUnavailable ?? this.offerCountUnavailable,
  );

  @override
  List<Object?> get props => [
    status,
    request,
    now,
    error,
    appFailure,
    refreshError,
    offerCountUnavailable,
  ];
}
