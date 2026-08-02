import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_prefs_model.dart';

/// Local SharedPreferences cache for notification category preferences.
/// Offline fallback only — the cubit does not read this on the happy path; it
/// always fetches from the gateway on mount (JM-058). Kept (and migrated to the
class NotificationPrefsStore {
  NotificationPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyOffers = 'notif_prefs_offers';
  static const _keyOrderStatus = 'notif_prefs_order_status';
  static const _keyWallet = 'notif_prefs_wallet';
  static const _keyMarketing = 'notif_prefs_marketing';

  NotificationCategoryPrefs load() {
    return NotificationCategoryPrefs(
      offers: _prefs.getBool(_keyOffers) ?? true,
      orderStatus: _prefs.getBool(_keyOrderStatus) ?? true,
      wallet: _prefs.getBool(_keyWallet) ?? true,
      marketing: _prefs.getBool(_keyMarketing) ?? false,
    );
  }

  Future<void> save(NotificationCategoryPrefs categories) async {
    await Future.wait([
      _prefs.setBool(_keyOffers, categories.offers),
      _prefs.setBool(_keyOrderStatus, categories.orderStatus),
      _prefs.setBool(_keyWallet, categories.wallet),
      _prefs.setBool(_keyMarketing, categories.marketing),
    ]);
  }
}
