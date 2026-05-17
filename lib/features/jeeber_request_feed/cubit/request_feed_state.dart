import 'package:equatable/equatable.dart';

import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';

/// What the screen layer is rendering at a given moment. The "loading" /
/// "ready" / "error" axis is orthogonal to the "is the feed empty" question;
/// the screen layer combines [status] and `requests.isEmpty` to decide
/// between spinner / list / empty state.
enum RequestFeedStatus { initial, loading, ready, error }

/// Per-request action state. Tracks the in-flight accept/decline call so the
/// card can render a pending look without globally locking the feed.
enum RequestActionStatus { idle, accepting, declining }

/// Last action outcome surfaced to the screen layer so it can flash a
/// snackbar / route the Jeeber into the active-delivery flow on accept.
/// Kept separate from [RequestFeedStatus] because action outcomes are
/// transient: the screen acknowledges them and the cubit clears them on the
/// next emission.
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
    this.actionStatuses = const {},
    this.lastEffect,
    this.errorMessageKey,
  });

  /// High-level status — drives the spinner vs list vs error decision.
  final RequestFeedStatus status;

  /// Realtime transport the repository is currently using. The screen layer
  /// renders a "reconnecting" caption while [FeedTransport.polling].
  final FeedTransport transport;

  /// Active feed, sorted by `expiresAt` ascending so the closest-to-expire
  /// card is at the top. The cubit owns the sort; the screen renders in
  /// list order.
  final List<DeliveryRequest> requests;

  /// Per-request action state — present only for requests with an in-flight
  /// accept/decline call.
  final Map<String, RequestActionStatus> actionStatuses;

  /// Last accept/decline outcome the cubit emitted. Transient: the screen
  /// is expected to acknowledge by ignoring repeated equal values.
  final RequestActionEffect? lastEffect;

  /// ARB key the screen layer should render as the error message. Kept as a
  /// key (not a translated string) so the cubit stays free of l10n context.
  final String? errorMessageKey;

  RequestActionStatus actionStatusFor(String id) =>
      actionStatuses[id] ?? RequestActionStatus.idle;

  RequestFeedState copyWith({
    RequestFeedStatus? status,
    FeedTransport? transport,
    List<DeliveryRequest>? requests,
    Map<String, RequestActionStatus>? actionStatuses,
    Object? lastEffect = _sentinel,
    Object? errorMessageKey = _sentinel,
  }) {
    return RequestFeedState(
      status: status ?? this.status,
      transport: transport ?? this.transport,
      requests: requests ?? this.requests,
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
        actionStatuses,
        lastEffect,
        errorMessageKey,
      ];
}

const Object _sentinel = Object();
