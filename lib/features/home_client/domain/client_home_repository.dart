import 'client_home_request.dart';
import 'recent_delivery_summary.dart';

class ClientHomeSnapshot {
  const ClientHomeSnapshot({
    this.inProgress = const [],
    this.pending = const [],
    this.replies = const [],
    this.recentDeliveries = const [],
    this.rateLimited = false,
    this.retryAfter,
    List<ClientHomeRequest>? activeRequests,
  }) : _activeRequestsOverride = activeRequests;

  final List<ClientHomeRequest> inProgress;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
  final List<RecentDeliverySummary> recentDeliveries;

  final bool rateLimited;

  final Duration? retryAfter;

  final List<ClientHomeRequest>? _activeRequestsOverride;

  List<ClientHomeRequest> get activeRequests =>
      _activeRequestsOverride ?? inProgress;
}

abstract class ClientHomeRepository {
  Future<ClientHomeSnapshot> loadSnapshot();
}
