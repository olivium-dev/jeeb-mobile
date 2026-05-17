import 'package:equatable/equatable.dart';

import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

enum ClientHomeStatus { initial, loading, ready, failed }

class ClientHomeState extends Equatable {
  const ClientHomeState({
    this.status = ClientHomeStatus.initial,
    this.greetingName,
    this.activeRequests = const [],
    this.recentDeliveries = const [],
  });

  /// Coarse load phase the screen renders off.
  final ClientHomeStatus status;

  /// First name (or fallback) shown in the greeting line.
  /// `null` if the user has no name on file — the screen shows a generic
  /// "Welcome" string instead.
  final String? greetingName;

  /// Active delivery requests, newest first. Empty when the user has none.
  final List<ClientHomeRequest> activeRequests;

  /// Recent completed deliveries for the "Order again" strip. The home tab
  /// shows at most one — the cubit caps this on emit.
  final List<RecentDeliverySummary> recentDeliveries;

  bool get isEmpty => activeRequests.isEmpty;

  ClientHomeState copyWith({
    ClientHomeStatus? status,
    Object? greetingName = _sentinel,
    List<ClientHomeRequest>? activeRequests,
    List<RecentDeliverySummary>? recentDeliveries,
  }) {
    return ClientHomeState(
      status: status ?? this.status,
      greetingName: identical(greetingName, _sentinel)
          ? this.greetingName
          : greetingName as String?,
      activeRequests: activeRequests ?? this.activeRequests,
      recentDeliveries: recentDeliveries ?? this.recentDeliveries,
    );
  }

  @override
  List<Object?> get props => [
        status,
        greetingName,
        activeRequests,
        recentDeliveries,
      ];
}

const Object _sentinel = Object();
