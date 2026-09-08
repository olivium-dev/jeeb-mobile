// F23: the save catch discarded the kind and the snack offered no way back —
// the toggle reverted and the user had nothing to do about it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_state.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';

class _SaveFailingRepo implements NotificationPrefsRepository {
  _SaveFailingRepo({this.failUntil = 1 << 30});

  /// Saves fail while `saveCalls < failUntil`.
  final int failUntil;
  int saveCalls = 0;
  NotificationCategoryPrefs? lastPending;

  @override
  Future<NotificationPrefs> fetch() async => const NotificationPrefs();

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async {
    saveCalls++;
    lastPending = categories;
    if (saveCalls <= failUntil) {
      throw const NotificationPrefsRepositoryException(
        NotificationPrefsFailure.serverError,
      );
    }
    return NotificationPrefs(categories: categories);
  }
}

NotificationPrefsCubit _cubit(NotificationPrefsRepository repo) =>
    NotificationPrefsCubit(
      repository: repo,
      debounce: const Duration(milliseconds: 1),
    );

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('a failed PATCH reverts the toggle and carries the kind', () async {
    final repo = _SaveFailingRepo();
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    cubit.toggleCategory(NotificationCategory.offers, false);
    await _settle();

    final state = cubit.state as NotificationPrefsLoaded;
    expect(state.prefs.categories.offers, isTrue, reason: 'reverted');
    expect(state.saveError, isTrue);
    expect(state.saveFailure, isA<ServerFailure>());
  });

  test('retryLastSave replays the same pending prefs', () async {
    final repo = _SaveFailingRepo(failUntil: 1);
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    cubit.toggleCategory(NotificationCategory.offers, false);
    await _settle();
    expect(repo.saveCalls, 1);

    await cubit.retryLastSave();

    expect(repo.saveCalls, 2);
    expect(repo.lastPending!.offers, isFalse);
    final state = cubit.state as NotificationPrefsLoaded;
    expect(state.prefs.categories.offers, isFalse);
    expect(state.saveError, isFalse);
  });

  test('retryLastSave with nothing pending is a no-op', () async {
    final repo = _SaveFailingRepo();
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.retryLastSave();

    expect(repo.saveCalls, 0);
  });

  test('acknowledgeError clears both the flag and the failure', () async {
    final cubit = _cubit(_SaveFailingRepo());
    addTearDown(cubit.close);
    await cubit.load();

    cubit.toggleCategory(NotificationCategory.offers, false);
    await _settle();
    cubit.acknowledgeError();

    final state = cubit.state as NotificationPrefsLoaded;
    expect(state.saveError, isFalse);
    expect(state.saveFailure, isNull);
  });
}
