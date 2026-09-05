import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/shared_prefs_notification_preferences_store.dart';
import 'domain/notification_preferences.dart';

/// Stage 2 calls this from `injection_container.dart` (R2: this WP never edits
/// that file). Until then the screen falls back to in-memory toggles.
void registerSettingsDependencies(GetIt getIt) {
  if (getIt.isRegistered<SettingsNotificationPrefsStore>()) return;
  getIt.registerLazySingleton<SettingsNotificationPrefsStore>(
    () => SharedPrefsNotificationPreferencesStore(getIt<SharedPreferences>()),
  );
}
