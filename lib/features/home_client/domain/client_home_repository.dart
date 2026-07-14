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
    this.rateLimited = false,
    this.retryAfter,
    List<ClientHomeRequest>? activeRequests,
  }) : _activeRequestsOverride = activeRequests;

  final List<ClientHomeRequest> inProgress;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
  final List<RecentDeliverySummary> recentDeliveries;

  /// F3 (offers-polling storm): `true` when at least one of the home reads was
  /// throttled with HTTP 429 during this load. The snapshot still carries
  /// whatever partial/cached data DID come back — a 429 must degrade the home
  /// tab gracefully, never fail it. The cubit keeps the already-rendered data
  /// and backs the poll off; it must NEVER surface the full-screen connection
  /// error on a 429.
  final bool rateLimited;

  /// Server-advertised `Retry-After` (when [rateLimited]), parsed from the 429
  /// response. The cubit uses it to back the poll off for at least this long so
  /// the client stops hammering the throttled gateway. `null` when the header
  /// was absent/unparseable — the cubit then falls back to its poll cadence.
  final Duration? retryAfter;

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
