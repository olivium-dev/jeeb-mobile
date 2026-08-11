import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_state.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';

/// In-memory [NotificationPrefsRepository] test seam (never registered in DI).
class _FakePrefsRepo implements NotificationPrefsRepository {
  _FakePrefsRepo({
    NotificationCategoryPrefs? initial,
    this.failSave = false,
  }) : _stored = NotificationPrefs(
          categories: initial ?? const NotificationCategoryPrefs(),
        );

  NotificationPrefs _stored;
  final bool failSave;

  /// The last category map the cubit PUT to us (asserts the locked class is
  /// never sent — the save() only carries the four toggleable categories).
  NotificationCategoryPrefs? lastSaved;

  @override
  Future<NotificationPrefs> fetch() async => _stored;

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async {
    if (failSave) {
      throw const NotificationPrefsRepositoryException(
        NotificationPrefsFailure.network,
      );
    }
    lastSaved = categories;
    _stored = _stored.copyWith(categories: categories);
    return _stored;
  }
}

class _FailingFetchRepo implements NotificationPrefsRepository {
  _FailingFetchRepo(this.failure);
  final NotificationPrefsFailure failure;

  @override
  Future<NotificationPrefs> fetch() async =>
      throw NotificationPrefsRepositoryException(failure);

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      throw NotificationPrefsRepositoryException(failure);
}

// Short debounce so PUTs land quickly under test.
const _fastDebounce = Duration(milliseconds: 10);

/// Waits for [ready] instead of sleeping a fixed multiple of the debounce — a
/// loaded CI runner can overshoot a 40 ms budget and flake the assertion.
Future<void> _settle(bool Function() ready) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

NotificationPrefsCubit _buildCubit({
  NotificationCategoryPrefs? initial,
  bool failSave = false,
}) {
  final cubit = NotificationPrefsCubit(
    repository: _FakePrefsRepo(initial: initial, failSave: failSave),
    debounce: _fastDebounce,
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('NotificationPrefsCubit — load (JM-058 AC)', () {
    test('starts in loading state before load() is called', () {
      final cubit = _buildCubit();
      expect(cubit.state, isA<NotificationPrefsLoading>());
    });

    test('load() → loaded with the four D64 categories', () async {
      final cubit = _buildCubit();
      await cubit.load();

      final state = cubit.state;
      expect(state, isA<NotificationPrefsLoaded>());
      final loaded = state as NotificationPrefsLoaded;
      // Operational categories default on; marketing defaults off (consent).
      expect(loaded.prefs.categories.offers, isTrue);
      expect(loaded.prefs.categories.orderStatus, isTrue);
      expect(loaded.prefs.categories.wallet, isTrue);
      expect(loaded.prefs.categories.marketing, isFalse);
      // Transactional class is always locked (D64).
      expect(loaded.prefs.transactionalLocked, isTrue);
    });

    test('load() → error (network) when the gateway throws', () async {
      final cubit = NotificationPrefsCubit(
        repository: _FailingFetchRepo(NotificationPrefsFailure.network),
        debounce: _fastDebounce,
      );
      addTearDown(cubit.close);

      await cubit.load();
      final state = cubit.state;
      expect(state, isA<NotificationPrefsError>());
      expect(
        (state as NotificationPrefsError).failure,
        NotificationPrefsFailureView.network,
      );
    });
  });

  group('NotificationPrefsCubit — toggleCategory (JM-058 AC)', () {
    test('optimistically updates the category in the UI', () async {
      final cubit = _buildCubit();
      await cubit.load();

      cubit.toggleCategory(NotificationCategory.offers, false);

      final loaded = cubit.state as NotificationPrefsLoaded;
      expect(loaded.prefs.categories.offers, isFalse);
    });

    test('schedules a debounced PUT that confirms the server snapshot',
        () async {
      final repo = _FakePrefsRepo();
      final cubit = NotificationPrefsCubit(
        repository: repo,
        debounce: _fastDebounce,
      );
      addTearDown(cubit.close);
      await cubit.load();

      cubit.toggleCategory(NotificationCategory.marketing, true);
      await _settle(() => repo.lastSaved != null);

      final loaded = cubit.state as NotificationPrefsLoaded;
      expect(loaded.prefs.categories.marketing, isTrue);
      // The PUT carried only the four toggleable categories (no locked class).
      expect(repo.lastSaved, isNotNull);
      expect(repo.lastSaved!.marketing, isTrue);
    });

    test('rapid toggles debounce into a single PUT', () async {
      final repo = _FakePrefsRepo();
      final cubit = NotificationPrefsCubit(
        repository: repo,
        debounce: const Duration(milliseconds: 30),
      );
      addTearDown(cubit.close);
      await cubit.load();

      cubit.toggleCategory(NotificationCategory.wallet, false);
      cubit.toggleCategory(NotificationCategory.wallet, true);
      cubit.toggleCategory(NotificationCategory.wallet, false);
      // Only the last value should be PUT after the debounce window.
      await _settle(() => repo.lastSaved != null);

      expect(repo.lastSaved!.wallet, isFalse);
    });
  });

  group('NotificationPrefsCubit — revert-on-error (D30)', () {
    test('failed PUT reverts the category and sets saveError', () async {
      final cubit = _buildCubit(failSave: true);
      await cubit.load();

      final before =
          (cubit.state as NotificationPrefsLoaded).prefs.categories.offers;

      cubit.toggleCategory(NotificationCategory.offers, !before);
      await _settle(
        () => (cubit.state as NotificationPrefsLoaded).saveError,
      );

      final loaded = cubit.state as NotificationPrefsLoaded;
      expect(loaded.prefs.categories.offers, before); // reverted
      expect(loaded.saveError, isTrue);
    });

    test('acknowledgeError clears the saveError flag', () async {
      final cubit = _buildCubit(failSave: true);
      await cubit.load();
      cubit.toggleCategory(NotificationCategory.offers, false);
      await _settle(
        () => (cubit.state as NotificationPrefsLoaded).saveError,
      );

      expect((cubit.state as NotificationPrefsLoaded).saveError, isTrue);

      cubit.acknowledgeError();
      expect((cubit.state as NotificationPrefsLoaded).saveError, isFalse);
    });
  });

  group('NotificationCategory wire contract (D64)', () {
    test('order-status serialises to snake_case `order_status`', () {
      expect(NotificationCategory.orderStatus.wireKey, 'order_status');
    });

    test('fromWire tolerates legacy camelCase status keys', () {
      expect(
        NotificationCategoryWire.fromWire('statusChanges'),
        NotificationCategory.orderStatus,
      );
      expect(
        NotificationCategoryWire.fromWire('orderStatus'),
        NotificationCategory.orderStatus,
      );
    });

    test('toTopicsJson round-trips through fromTopicsJson', () {
      const prefs = NotificationCategoryPrefs(
        offers: false,
        orderStatus: true,
        wallet: false,
        marketing: true,
      );
      final parsed =
          NotificationCategoryPrefs.fromTopicsJson(prefs.toTopicsJson());
      expect(parsed, prefs);
    });

    test('fromTopicsJson falls back to defaults on empty / partial map', () {
      final parsed = NotificationCategoryPrefs.fromTopicsJson(const {});
      expect(parsed.offers, isTrue);
      expect(parsed.orderStatus, isTrue);
      expect(parsed.wallet, isTrue);
      expect(parsed.marketing, isFalse);
    });
  });
}
