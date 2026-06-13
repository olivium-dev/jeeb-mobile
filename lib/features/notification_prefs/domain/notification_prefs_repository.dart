import 'notification_prefs_model.dart';

/// Remote contract for syncing notification preferences with the gateway.
///
/// Endpoints (useMockPrefixes=false, Mockoon :3055):
///   GET  /users/me/notification-preferences  → [NotificationPrefs]
///   PATCH /users/me/notification-preferences → [NotificationPrefs]
abstract class NotificationPrefsRepository {
  /// Fetches the user's current preferences from the gateway.
  Future<NotificationPrefs> fetch();

  /// PATCHes updated topic preferences to the gateway.
  ///
  /// Passing `otp:false` or `systemCritical:false` → 400 from the gateway.
  Future<NotificationPrefs> patch(NotificationTopicPrefs prefs);
}
