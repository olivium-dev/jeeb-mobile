import 'package:equatable/equatable.dart';

import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';

enum RequestFeedStatus { initial, loading, ready, error }

enum RequestActionStatus { idle, accepting, declining }

class RequestActionEffect extends Equatable {
  const RequestActionEffect({
    required this.requestId,
    required this.outcome,
  });

  final String requestId;
  final RequestActionOutcome outcome;

  @override
  List<Object?> get props => [requestId, outcome];
}

class RequestFeedState extends Equatable {
  const RequestFeedState({
    this.status = RequestFeedStatus.initial,
    this.transport = FeedTransport.webSocket,
    this.requests = const [],
    this.expiredIds = const {},
    this.actionStatuses = const {},
    this.lastEffect,
    this.errorMessageKey,
  });

  final RequestFeedStatus status;

  final FeedTransport transport;

  final List<DeliveryRequest> requests;

  final Set<String> expiredIds;

  final Map<String, RequestActionStatus> actionStatuses;

  final RequestActionEffect? lastEffect;

  final String? errorMessageKey;

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
    Object? errorMessageKey = _sentinel,
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
      errorMessageKey: identical(errorMessageKey, _sentinel)
          ? this.errorMessageKey
          : errorMessageKey as String?,
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
        errorMessageKey,
      ];
}

const Object _sentinel = Object();
