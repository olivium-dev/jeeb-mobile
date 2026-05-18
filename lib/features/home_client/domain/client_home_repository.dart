import 'client_home_request.dart';
import 'recent_delivery_summary.dart';

/// Read-side snapshot the home tab needs in one shot.
///
/// Split per Figma tab so the screen can switch lists on chip selection
/// without re-fetching:
///   - [inProgress] — active deliveries currently moving (the `In Progress`
///     chip / `_v1/delivery/active` endpoint).
///   - [pending] — requests the sender has submitted that have **no** offers
///     yet (the `Pending Requests` chip / `GET /v1/requests?status=pending`).
///   - [replies] — requests that have collected at least one offer and are
///     awaiting acceptance (the `Replies` chip /
///     `GET /v1/requests?status=offers-received`).
///   - [recentDeliveries] — the "Order again" strip (capped at one entry).
///
/// [activeRequests] is kept as an alias for [inProgress] so older callers /
/// tests that still read `activeRequests` keep compiling.
class ClientHomeSnapshot {
  const ClientHomeSnapshot({
    this.inProgress = const [],
    this.pending = const [],
    this.replies = const [],
    this.recentDeliveries = const [],
    List<ClientHomeRequest>? activeRequests,
  }) : _activeRequestsOverride = activeRequests;

  final List<ClientHomeRequest> inProgress;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
  final List<RecentDeliverySummary> recentDeliveries;
  final List<ClientHomeRequest>? _activeRequestsOverride;

  /// Backward-compat alias — older callers used a single list. Returns the
  /// override if explicitly supplied (legacy tests), otherwise [inProgress].
  List<ClientHomeRequest> get activeRequests =>
      _activeRequestsOverride ?? inProgress;
}

/// jeeb-gateway contract for the client home tab.
///
/// The real implementation calls:
///   - `GET /v1/delivery/active` for the In Progress list, and
///   - `GET /v1/requests?status=pending` + `GET /v1/requests?status=offers-received`
///     for Pending Requests and Replies respectively.
///
/// T-mobile-037 ships with an in-memory fake so the screen is testable
/// without the network.
abstract class ClientHomeRepository {
  Future<ClientHomeSnapshot> loadSnapshot();
}
