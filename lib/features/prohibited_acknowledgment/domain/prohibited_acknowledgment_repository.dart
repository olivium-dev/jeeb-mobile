import 'prohibited_item.dart';

/// Prohibited-items acknowledgment repository contract.
/// Dio implementation calls GET /prohibited-items and POST /prohibited-items/acknowledge.
abstract class ProhibitedAcknowledgmentRepository {
  /// Fetch current prohibited-items catalog.
  Future<List<ProhibitedItem>> fetchItems();

  /// Record user acknowledgment on server.
  Future<void> acknowledge();

  /// Returns true if acknowledged in session (SharedPreferences key).
  Future<bool> hasAcknowledged();

  /// Persist acknowledgment locally so dialog doesn't show again.
  Future<void> saveLocalAcknowledgment();
}
