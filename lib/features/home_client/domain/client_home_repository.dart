import 'client_home_request.dart';
import 'recent_delivery_summary.dart';

class ClientHomeSnapshot {
  const ClientHomeSnapshot({
    this.inProgress = const [],
    this.pending = const [],
    this.replies = const [],
    this.recentDeliveries = const [],
    this.offerStatusRequests = const [],
    this.rateLimited = false,
    this.loadFailed = false,
    this.retryAfter,
    List<ClientHomeRequest>? activeRequests,
  }) : _activeRequestsOverride = activeRequests;

  final List<ClientHomeRequest> inProgress;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
  final List<RecentDeliverySummary> recentDeliveries;
  final List<ClientHomeRequest> offerStatusRequests;

  final bool rateLimited;

  /// True iff EVERY primary read of this load failed on transport (non-429
  /// [DioException]) and none succeeded — an honest "nothing loaded", not empty.
  final bool loadFailed;

  final Duration? retryAfter;

  final List<ClientHomeRequest>? _activeRequestsOverride;

  List<ClientHomeRequest> get activeRequests =>
      _activeRequestsOverride ?? inProgress;
}

abstract class ClientHomeRepository {
  Future<ClientHomeSnapshot> loadSnapshot();
}
