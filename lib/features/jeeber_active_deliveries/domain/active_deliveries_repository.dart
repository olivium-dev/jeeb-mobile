import 'active_delivery_summary.dart';

/// Domain contract for the jeeber's active-deliveries list (iter6 real-flow
/// blocker fix). Backed by the gateway `GET /v1/deliveries?role=jeeber`
/// (`JeebOrdersListController.ListDeliveries`), which scopes to the bearer
/// jeeber's assigned deliveries.
abstract class ActiveDeliveriesRepository {
  /// List the calling jeeber's active (not-yet-Done) accepted deliveries, most
  /// recent first. Returns an empty list on any transport error (the surface
  /// shows its empty state rather than an error banner — the dashboard owns
  /// connectivity surfacing). Never throws.
  Future<List<ActiveDeliverySummary>> listActive();
}
