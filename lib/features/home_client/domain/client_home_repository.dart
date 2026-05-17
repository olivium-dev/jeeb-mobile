import 'client_home_request.dart';
import 'recent_delivery_summary.dart';

/// Read-side snapshot the home tab needs in one shot.
class ClientHomeSnapshot {
  const ClientHomeSnapshot({
    required this.activeRequests,
    required this.recentDeliveries,
  });

  final List<ClientHomeRequest> activeRequests;
  final List<RecentDeliverySummary> recentDeliveries;
}

/// jeeb-gateway contract for the client home tab.
///
/// The real implementation calls
/// `GET /api/clients/me/home-summary` on `jeeb-gateway`, which fans out
/// to delivery-service for the request list and to the gateway's local DB
/// for "order again" history. T-mobile-037 ships with an in-memory fake
/// so the screen is testable without the network.
abstract class ClientHomeRepository {
  Future<ClientHomeSnapshot> loadSnapshot();
}
