import 'prohibited_item.dart';

/// Prohibited-items acknowledgment repository contract.
/// Dio implementation calls GET /prohibited-items and POST /prohibited-items/acknowledge.
abstract class ProhibitedAcknowledgmentRepository {
  /// Fetch current prohibited-items catalog.
  Future<List<ProhibitedItem>> fetchItems();

  /// Record user acknowledgment on server.
  Future<void> acknowledge();

  /// Whether the last successfully fetched catalog is acknowledged by the
  /// current server session. Call fetchItems before consulting this value.
  Future<bool> hasAcknowledged();

  /// Finish local housekeeping after a successful server acknowledgment.
  /// Local storage must not authorize acknowledgment for another user/version.
  Future<void> saveLocalAcknowledgment();
}
