import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_prefs_model.dart';

/// Local SharedPreferences cache for notification preferences.
///
/// Used as a fallback when the gateway is unreachable. The cubit does not read
/// from this store directly — it always fetches from the gateway on mount.
/// This store is kept for backward compatibility and potential offline fallback.
class NotificationPrefsStore {
  NotificationPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyOffers = 'notif_prefs_offers';
  static const _keyChat = 'notif_prefs_chat';
  static const _keyStatusChanges = 'notif_prefs_status_changes';
  static const _keyRatingReminders = 'notif_prefs_rating_reminders';

  NotificationPrefs load() {
    return NotificationPrefs(
      preferences: NotificationTopicPrefs(
        offers: _prefs.getBool(_keyOffers) ?? true,
        chat: _prefs.getBool(_keyChat) ?? true,
        statusChanges: _prefs.getBool(_keyStatusChanges) ?? true,
        ratingReminders: _prefs.getBool(_keyRatingReminders) ?? true,
      ),
    );
  }

  Future<void> save(NotificationPrefs prefs) async {
    final p = prefs.preferences;
    await Future.wait([
      _prefs.setBool(_keyOffers, p.offers),
      _prefs.setBool(_keyChat, p.chat),
      _prefs.setBool(_keyStatusChanges, p.statusChanges),
      _prefs.setBool(_keyRatingReminders, p.ratingReminders),
    ]);
  }
}
