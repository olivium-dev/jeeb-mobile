import '../../../core/network/app_failure.dart';
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
    this.retryAfter,
    this.inProgressFailure,
    this.requestsFailure,
    this.recentFailure,
    this.probeFailure,
    List<ClientHomeRequest>? activeRequests,
  }) : _activeRequestsOverride = activeRequests;

  final List<ClientHomeRequest> inProgress;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
  final List<RecentDeliverySummary> recentDeliveries;
  final List<ClientHomeRequest> offerStatusRequests;

  final bool rateLimited;

  /// Per-bucket classified failures: one dead read no longer erases the reads
  /// that succeeded, so a partial load renders rows plus a per-bucket error.
  final AppFailure? inProgressFailure;
  final AppFailure? requestsFailure;
  final AppFailure? recentFailure;

  /// The best-effort offer probe; never blocks a load, but is not swallowed.
  final AppFailure? probeFailure;

  final Duration? retryAfter;

  final List<ClientHomeRequest>? _activeRequestsOverride;

  List<ClientHomeRequest> get activeRequests =>
      _activeRequestsOverride ?? inProgress;

  bool get anyBucketFailed =>
      requestsFailure != null ||
      inProgressFailure != null ||
      recentFailure != null;

  AppFailure? get firstFailure =>
      requestsFailure ?? inProgressFailure ?? recentFailure;

  /// True iff both TAB-BEARING reads failed — an honest "nothing loaded".
  /// `recent` is a supporting rail, never on its own a failed home.
  bool get allPrimaryFailed =>
      requestsFailure != null && inProgressFailure != null;

  /// Legacy alias kept so existing callers and fixtures compile unchanged.
  bool get loadFailed => allPrimaryFailed;
}

abstract class ClientHomeRepository {
  Future<ClientHomeSnapshot> loadSnapshot();
}
