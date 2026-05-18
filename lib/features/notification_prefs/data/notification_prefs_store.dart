import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_prefs_model.dart';

class NotificationPrefsStore {
  NotificationPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPush = 'notification_prefs_push_enabled';
  static const _keySms = 'notification_prefs_sms_enabled';
  static const _keyEmail = 'notification_prefs_email_enabled';
  static const _keyDeliveryUpdates = 'notification_prefs_delivery_updates';
  static const _keyOffers = 'notification_prefs_offers';
  static const _keyPromotions = 'notification_prefs_promotions';

  NotificationPrefs load() {
    return NotificationPrefs(
      pushEnabled: _prefs.getBool(_keyPush) ?? true,
      smsEnabled: _prefs.getBool(_keySms) ?? true,
      emailEnabled: _prefs.getBool(_keyEmail) ?? true,
      deliveryUpdates: _prefs.getBool(_keyDeliveryUpdates) ?? true,
      offers: _prefs.getBool(_keyOffers) ?? true,
      promotions: _prefs.getBool(_keyPromotions) ?? false,
    );
  }

  Future<void> save(NotificationPrefs prefs) async {
    await Future.wait([
      _prefs.setBool(_keyPush, prefs.pushEnabled),
      _prefs.setBool(_keySms, prefs.smsEnabled),
      _prefs.setBool(_keyEmail, prefs.emailEnabled),
      _prefs.setBool(_keyDeliveryUpdates, prefs.deliveryUpdates),
      _prefs.setBool(_keyOffers, prefs.offers),
      _prefs.setBool(_keyPromotions, prefs.promotions),
    ]);
  }
}
