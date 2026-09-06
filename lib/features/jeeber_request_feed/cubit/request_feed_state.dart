import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';

enum RequestFeedStatus { initial, loading, ready, error }

enum RequestActionStatus { idle, accepting, declining }

class RequestActionEffect extends Equatable {
  const RequestActionEffect({
    required this.requestId,
    required this.action,
    required this.outcome,
    this.failure,
  });

  final String requestId;

  /// Which act produced this effect. Without it a Retry cannot tell an accept
  /// from a decline, and a failed decline would be retried as an ACCEPT.
  final RequestActionStatus action;

  final RequestActionOutcome outcome;

  /// The classified accept/decline failure, so the snack can speak the kind
  /// without widening [RequestActionOutcome] (R3).
  final AppFailure? failure;

  @override
  List<Object?> get props => [requestId, action, outcome, failure];
}

class RequestFeedState extends Equatable {
  const RequestFeedState({
    this.status = RequestFeedStatus.initial,
    this.transport = FeedTransport.webSocket,
    this.requests = const [],
    this.expiredIds = const {},
    this.actionStatuses = const {},
    this.lastEffect,
    this.error,
    this.refreshError,
  });

  final RequestFeedStatus status;

  final FeedTransport transport;

  final List<DeliveryRequest> requests;

  final Set<String> expiredIds;

  final Map<String, RequestActionStatus> actionStatuses;

  final RequestActionEffect? lastEffect;

  /// Cold failure: the read failed with no rows to keep.
  final AppFailure? error;

  /// Warm failure: rows are on screen and a refresh failed.
  final AppFailure? refreshError;

  RequestActionStatus actionStatusFor(String id) =>
      actionStatuses[id] ?? RequestActionStatus.idle;

  bool isExpired(String id) => expiredIds.contains(id);

  RequestFeedState copyWith({
    RequestFeedStatus? status,
    FeedTransport? transport,
    List<DeliveryRequest>? requests,
    Set<String>? expiredIds,
    Map<String, RequestActionStatus>? actionStatuses,
    Object? lastEffect = _sentinel,
    Object? error = _sentinel,
    Object? refreshError = _sentinel,
  }) {
    return RequestFeedState(
      status: status ?? this.status,
      transport: transport ?? this.transport,
      requests: requests ?? this.requests,
      expiredIds: expiredIds ?? this.expiredIds,
      actionStatuses: actionStatuses ?? this.actionStatuses,
      lastEffect: identical(lastEffect, _sentinel)
          ? this.lastEffect
          : lastEffect as RequestActionEffect?,
      error: identical(error, _sentinel) ? this.error : error as AppFailure?,
      refreshError: identical(refreshError, _sentinel)
          ? this.refreshError
          : refreshError as AppFailure?,
    );
  }

  @override
  List<Object?> get props => [
        status,
        transport,
        requests,
        expiredIds,
        actionStatuses,
        lastEffect,
        error,
        refreshError,
      ];
}

const Object _sentinel = Object();
