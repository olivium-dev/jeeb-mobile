import 'notification_prefs_model.dart';

/// Typed failure surfaced to the cubit (never a raw `DioException` — guardrail §4).
enum NotificationPrefsFailure { network, unknown }

/// Thrown by [NotificationPrefsRepository] implementations; the cubit maps
/// [failure] to localized copy.
class NotificationPrefsRepositoryException implements Exception {
  const NotificationPrefsRepositoryException(this.failure, [this.message]);

  final NotificationPrefsFailure failure;
  final String? message;

  @override
  String toString() =>
      'NotificationPrefsRepositoryException($failure, $message)';
}

/// Remote contract for syncing notification preferences with the gateway.
///
/// JM-058 / D64. Gateway-contract path (the [MockGatewayClient] interceptor
/// rewrites `/v1/notifications` → `/notification-service/v1/notifications`):
///   GET  /v1/notifications/preferences  → [NotificationPrefs]
///   PUT  /v1/notifications/preferences  → [NotificationPrefs]
///
/// Categories = offers / order-status / wallet / marketing; the transactional
/// class is locked (never sent in the toggle map). Push is the only channel the
/// app exposes (R2 push-only note).
abstract class NotificationPrefsRepository {
  /// Fetches the user's current preferences from the gateway.
  Future<NotificationPrefs> fetch();

  /// PUTs the full updated category map to the gateway and returns the
  /// server-confirmed snapshot. The transactional class is never included.
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories);
}
