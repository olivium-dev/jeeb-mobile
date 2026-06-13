import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_state.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';

/// Fake [NotificationPrefsRepository] for testing.
class _FakePrefsRepo implements NotificationPrefsRepository {
  _FakePrefsRepo({
    NotificationPrefs? initial,
    bool failPatch = false,
  })  : _stored = initial ??
            const NotificationPrefs(
              preferences: NotificationTopicPrefs(
                offers: true,
                chat: true,
                statusChanges: true,
                ratingReminders: true,
              ),
              alwaysOn: ['otp', 'system_critical'],
            ),
        _failPatch = failPatch;

  NotificationPrefs _stored;
  final bool _failPatch;

  @override
  Future<NotificationPrefs> fetch() async => _stored;

  @override
  Future<NotificationPrefs> patch(NotificationTopicPrefs prefs) async {
    if (_failPatch) throw Exception('network error');
    _stored = _stored.copyWith(preferences: prefs);
    return _stored;
  }
}

NotificationPrefsCubit _buildCubit({
  NotificationPrefs? initial,
  bool failPatch = false,
}) {
  final cubit = NotificationPrefsCubit(
    repository: _FakePrefsRepo(initial: initial, failPatch: failPatch),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('NotificationPrefsCubit — load (T-MOB-026 AC1)', () {
    test('starts in loading state before load() is called', () {
      final cubit = _buildCubit();
      expect(cubit.state, isA<NotificationPrefsLoading>());
    });

    test('load() transitions to loaded with gateway prefs', () async {
      final cubit = _buildCubit();
      await cubit.load();

      final loaded = cubit.state;
      expect(loaded, isA<NotificationPrefsLoaded>());
      final l = loaded as NotificationPrefsLoaded;
      expect(l.prefs.preferences.offers, isTrue);
      expect(l.prefs.alwaysOn, contains('otp'));
    });

    test('load() transitions to error when gateway throws', () async {
      final repo = _FakeRepoThatFailsFetch();
      final cubit = NotificationPrefsCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state, isA<NotificationPrefsError>());
    });
  });

  group('NotificationPrefsCubit — toggleTopic (T-MOB-026 AC1)', () {
    test('toggleTopic optimistically updates UI', () async {
      final cubit = _buildCubit();
      await cubit.load();

      cubit.toggleTopic('offers', false);

      final loaded = cubit.state as NotificationPrefsLoaded;
      expect(loaded.prefs.preferences.offers, isFalse);
    });

    test('toggleTopic schedules a debounced PATCH', () async {
      final cubit = _buildCubit();
      await cubit.load();
      cubit.toggleTopic('chat', false);

      // After debounce completes (500ms), state should reflect server response.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final loaded = cubit.state as NotificationPrefsLoaded;
      expect(loaded.prefs.preferences.chat, isFalse);
    });
  });

  group('NotificationPrefsCubit — revert-on-error (T-MOB-026 AC2)', () {
    test('failed PATCH reverts UI and sets saveError flag', () async {
      final cubit = _buildCubit(failPatch: true);
      await cubit.load();

      final preToggle =
          (cubit.state as NotificationPrefsLoaded).prefs.preferences.offers;

      cubit.toggleTopic('offers', !preToggle);

      // Wait for debounce + patch to complete.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final loaded = cubit.state as NotificationPrefsLoaded;
      // Toggle should be reverted.
      expect(loaded.prefs.preferences.offers, preToggle);
      expect(loaded.saveError, isTrue);
    });

    test('acknowledgeError clears saveError flag', () async {
      final cubit = _buildCubit(failPatch: true);
      await cubit.load();
      cubit.toggleTopic('offers', false);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final beforeAck = cubit.state as NotificationPrefsLoaded;
      expect(beforeAck.saveError, isTrue);

      cubit.acknowledgeError();
      final afterAck = cubit.state as NotificationPrefsLoaded;
      expect(afterAck.saveError, isFalse);
    });
  });

  group('NotificationPrefsCubit — alwaysOn (T-MOB-026 AC3)', () {
    test('alwaysOn topics are reflected in loaded prefs', () async {
      final cubit = _buildCubit(
        initial: const NotificationPrefs(
          preferences: NotificationTopicPrefs(),
          alwaysOn: ['otp', 'system_critical'],
        ),
      );
      await cubit.load();

      final loaded = cubit.state as NotificationPrefsLoaded;
      expect(loaded.prefs.isOtpAlwaysOn, isTrue);
      expect(loaded.prefs.isSystemCriticalAlwaysOn, isTrue);
    });
  });
}

class _FakeRepoThatFailsFetch implements NotificationPrefsRepository {
  @override
  Future<NotificationPrefs> fetch() async {
    throw Exception('fetch failed');
  }

  @override
  Future<NotificationPrefs> patch(NotificationTopicPrefs prefs) async {
    throw Exception('patch failed');
  }
}
