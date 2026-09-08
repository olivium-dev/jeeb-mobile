import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_preferences.dart';

/// SharedPreferences-backed [SettingsNotificationPrefsStore]. Mirrors the shape
/// of `notification_prefs/data/notification_prefs_store.dart`.
class SharedPrefsNotificationPreferencesStore
    implements SettingsNotificationPrefsStore {
  const SharedPrefsNotificationPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const String offersKey = 'settings_notif_offers';
  static const String chatKey = 'settings_notif_chat';
  static const String statusKey = 'settings_notif_status';
  static const String ratingKey = 'settings_notif_rating';

  @override
  Future<NotificationPreferences?> read() async {
    final bool? offers = _prefs.getBool(offersKey);
    final bool? chat = _prefs.getBool(chatKey);
    final bool? status = _prefs.getBool(statusKey);
    final bool? rating = _prefs.getBool(ratingKey);
    if (offers == null && chat == null && status == null && rating == null) {
      return null;
    }
    return NotificationPreferences(
      offers: offers ?? true,
      chat: chat ?? true,
      status: status ?? true,
      ratingReminders: rating ?? true,
    );
  }

  @override
  Future<void> write(NotificationPreferences preferences) async {
    await _prefs.setBool(offersKey, preferences.offers);
    await _prefs.setBool(chatKey, preferences.chat);
    await _prefs.setBool(statusKey, preferences.status);
    await _prefs.setBool(ratingKey, preferences.ratingReminders);
  }
}
