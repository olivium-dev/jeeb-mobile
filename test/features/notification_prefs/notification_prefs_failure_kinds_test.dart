// F22: `_parse` accepted a body with NO `preferences` and NO `topics` — an
// empty `{}` read as "everything on". F23/F24: every failure printed one
// sentence and the error view discarded the classification.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_state.dart';
import 'package:jeeb_mobile/features/notification_prefs/data/dio_notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';

Dio _answering({required int status, Map<String, dynamic>? body}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: body,
        );
        if (status >= 200 && status < 300) {
          handler.resolve(response);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );
  return dio;
}

Future<NotificationPrefsFailure> _failureFor(Dio dio) async {
  try {
    await DioNotificationPrefsRepository(dio).fetch();
  } on NotificationPrefsRepositoryException catch (e) {
    return e.failure;
  }
  fail('expected a NotificationPrefsRepositoryException');
}

class _ThrowingRepo implements NotificationPrefsRepository {
  const _ThrowingRepo(this.failure);

  final NotificationPrefsFailure failure;

  @override
  Future<NotificationPrefs> fetch() async =>
      throw NotificationPrefsRepositoryException(failure);

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      throw NotificationPrefsRepositoryException(failure);
}

class _LoadedRepo implements NotificationPrefsRepository {
  const _LoadedRepo();

  @override
  Future<NotificationPrefs> fetch() async => const NotificationPrefs();

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      NotificationPrefs(categories: categories);
}

/// Serves one good read, then throws — the warm-refresh failure shape.
class _ThenThrowsRepo implements NotificationPrefsRepository {
  _ThenThrowsRepo(this.prefs);

  final NotificationPrefs prefs;
  int reads = 0;

  @override
  Future<NotificationPrefs> fetch() async {
    reads++;
    if (reads == 1) return prefs;
    throw const NotificationPrefsRepositoryException(
      NotificationPrefsFailure.network,
    );
  }

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      NotificationPrefs(categories: categories);
}

void main() {
  test('an empty {} body is MALFORMED, never "everything on"', () async {
    expect(
      await _failureFor(_answering(status: 200, body: <String, dynamic>{})),
      NotificationPrefsFailure.malformed,
    );
  });

  test('401 is unauthorized, not unknown', () async {
    expect(
      await _failureFor(_answering(status: 401)),
      NotificationPrefsFailure.unauthorized,
    );
  });

  test('500 is serverError, not unknown', () async {
    expect(
      await _failureFor(_answering(status: 500)),
      NotificationPrefsFailure.serverError,
    );
  });

  test('the legacy topics shape still parses', () async {
    final prefs = await DioNotificationPrefsRepository(
      _answering(
        status: 200,
        body: <String, dynamic>{'push': true, 'topics': <String, dynamic>{}},
      ),
    ).fetch();

    expect(prefs.pushEnabled, isTrue);
  });

  test('each failure reaches its own screen-facing view', () async {
    for (final entry in const <NotificationPrefsFailure,
        NotificationPrefsFailureView>{
      NotificationPrefsFailure.malformed: NotificationPrefsFailureView.malformed,
      NotificationPrefsFailure.unauthorized:
          NotificationPrefsFailureView.unauthorized,
      NotificationPrefsFailure.serverError:
          NotificationPrefsFailureView.serverError,
      NotificationPrefsFailure.network: NotificationPrefsFailureView.network,
    }.entries) {
      final cubit = NotificationPrefsCubit(
        repository: _ThrowingRepo(entry.key),
      );
      addTearDown(cubit.close);
      await cubit.load();

      final state = cubit.state as NotificationPrefsError;
      expect(state.failure, entry.value);
      expect(state.appFailure, isNotNull);
    }
  });

  test('load() from LOADED keeps the rows instead of blanking them', () async {
    final cubit = NotificationPrefsCubit(repository: const _LoadedRepo());
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state, isA<NotificationPrefsLoaded>());

    final states = <NotificationPrefsState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(
      states.any((s) => s is NotificationPrefsLoading),
      isFalse,
      reason: 'a retry-after-load must not blank the rows',
    );
  });

  test('a FAILED warm re-read keeps the rows and reports a refresh note',
      () async {
    const seeded = NotificationPrefs(
      categories: NotificationCategoryPrefs(offers: false),
    );
    final cubit = NotificationPrefsCubit(repository: _ThenThrowsRepo(seeded));
    addTearDown(cubit.close);
    await cubit.load();
    final loaded = cubit.state as NotificationPrefsLoaded;

    await cubit.load();

    final after = cubit.state;
    expect(after, isA<NotificationPrefsLoaded>());
    after as NotificationPrefsLoaded;
    expect(after.prefs, loaded.prefs);
    expect(after.isRefreshing, isFalse);
    expect(after.refreshFailure, isNotNull);
    expect(after.saveError, isFalse);

    cubit.dismissRefreshFailure();
    expect(
      (cubit.state as NotificationPrefsLoaded).refreshFailure,
      isNull,
    );
  });
}
