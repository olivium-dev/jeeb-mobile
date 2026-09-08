// F11: the four toggles mutated in-memory state only — nothing persisted, so
// every one of them was forgotten on the next launch.
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/data/shared_prefs_notification_preferences_store.dart';
import 'package:jeeb_mobile/features/settings/domain/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/settings_fakes.dart';

class _FakeStore implements SettingsNotificationPrefsStore {
  _FakeStore({this.writeFails = false});

  NotificationPreferences? seed;
  final bool writeFails;
  int writes = 0;

  @override
  Future<NotificationPreferences?> read() async => seed;

  @override
  Future<void> write(NotificationPreferences preferences) async {
    writes++;
    if (writeFails) throw const ServerFailure(status: 500);
    seed = preferences;
  }
}

SettingsCubit _cubit(SettingsNotificationPrefsStore store) => SettingsCubit(
      profileRepository: InMemoryProfileRepository(),
      accountService: const FakeAccountService(),
      notificationStore: store,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('setNotification writes through and load() reads it back', () async {
    final store = _FakeStore();
    final cubit = _cubit(store);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setNotification(NotificationCategory.offers, false);

    expect(store.writes, 1);
    expect(store.seed!.offers, isFalse);

    final second = _cubit(store);
    addTearDown(second.close);
    await second.load();

    expect(second.state.notifications.offers, isFalse);
  });

  test('a throwing store reverts the toggle and says so', () async {
    final store = _FakeStore(writeFails: true);
    final cubit = _cubit(store);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setNotification(NotificationCategory.chat, false);

    expect(cubit.state.notifications.chat, isTrue);
    expect(cubit.state.banner, SettingsBanner.notificationSaveFailed);
  });

  test('with NO store the cubit degrades to the pre-F11 in-memory toggle',
      () async {
    final cubit = SettingsCubit(
      profileRepository: InMemoryProfileRepository(),
      accountService: const FakeAccountService(),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setNotification(NotificationCategory.status, false);

    expect(cubit.state.notifications.status, isFalse);
    expect(cubit.state.banner, SettingsBanner.none);
  });

  test('SharedPrefsNotificationPreferencesStore round-trips the four keys',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsNotificationPreferencesStore(prefs);

    expect(await store.read(), isNull, reason: 'nothing written yet');

    await store.write(
      const NotificationPreferences(
        offers: false,
        chat: true,
        status: false,
        ratingReminders: true,
      ),
    );

    final read = await store.read();
    expect(read!.offers, isFalse);
    expect(read.chat, isTrue);
    expect(read.status, isFalse);
    expect(read.ratingReminders, isTrue);
  });
}
