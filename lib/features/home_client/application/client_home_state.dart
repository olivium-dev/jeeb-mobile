import 'package:equatable/equatable.dart';

import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

enum ClientHomeStatus { initial, loading, ready, failed }

enum ClientHomeTab { inProgress, pendingRequests, replies }

class ClientHomeState extends Equatable {
  const ClientHomeState({
    this.status = ClientHomeStatus.initial,
    this.greetingName,
    this.inProgress = const [],
    this.pending = const [],
    this.replies = const [],
    this.recentDeliveries = const [],
  });

  final ClientHomeStatus status;

  final String? greetingName;

  final List<ClientHomeRequest> inProgress;

  final List<ClientHomeRequest> pending;

  final List<ClientHomeRequest> replies;

  final List<RecentDeliverySummary> recentDeliveries;

  List<ClientHomeRequest> get activeRequests => inProgress;

  bool get isInProgressEmpty => inProgress.isEmpty;
  bool get isPendingEmpty => pending.isEmpty;
  bool get isRepliesEmpty => replies.isEmpty;

  List<ClientHomeRequest> listFor(ClientHomeTab tab) {
    switch (tab) {
      case ClientHomeTab.inProgress:
        return inProgress;
      case ClientHomeTab.pendingRequests:
        return pending;
      case ClientHomeTab.replies:
        return replies;
    }
  }

  bool get isEmpty => isInProgressEmpty;

  ClientHomeState copyWith({
    ClientHomeStatus? status,
    Object? greetingName = _sentinel,
    List<ClientHomeRequest>? inProgress,
    List<ClientHomeRequest>? pending,
    List<ClientHomeRequest>? replies,
    List<RecentDeliverySummary>? recentDeliveries,
  }) {
    return ClientHomeState(
      status: status ?? this.status,
      greetingName: identical(greetingName, _sentinel)
          ? this.greetingName
          : greetingName as String?,
      inProgress: inProgress ?? this.inProgress,
      pending: pending ?? this.pending,
      replies: replies ?? this.replies,
      recentDeliveries: recentDeliveries ?? this.recentDeliveries,
    );
  }

  @override
  List<Object?> get props => [
        status,
        greetingName,
        inProgress,
        pending,
        replies,
        recentDeliveries,
      ];
}

const Object _sentinel = Object();
