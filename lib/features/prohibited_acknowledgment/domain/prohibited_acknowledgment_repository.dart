import 'prohibited_item.dart';

/// Repository contract for the prohibited-items acknowledgment flow.
///
/// Implementations:
/// - [DioProhibitedAcknowledgmentRepository] — Dio-backed, calls
///   `GET /prohibited-items` and `POST /prohibited-items/acknowledge` on
///   jeeb-gateway (mock :3055, scenario `s05-order-prohibited-items`).
/// - Fake variant injected in widget tests.
abstract class ProhibitedAcknowledgmentRepository {
  /// Returns the current prohibited-items catalog.
  /// Endpoint: `GET /prohibited-items`
  Future<List<ProhibitedItem>> fetchItems();

  /// Records the user's acknowledgment of the catalog on the server.
  /// Endpoint: `POST /prohibited-items/acknowledge`
  Future<void> acknowledge();

  /// Returns `true` if the user has already acknowledged in this session
  /// (backed by [SharedPreferences] key `app.acknowledged_prohibited`).
  Future<bool> hasAcknowledged();

  /// Persists the acknowledgment locally so the dialog is not shown again.
  Future<void> saveLocalAcknowledgment();
}
