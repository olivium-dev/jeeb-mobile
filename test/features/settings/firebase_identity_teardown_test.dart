// THE SECOND IDENTITY MUST NOT OUTLIVE THE FIRST.
library;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/session/firebase_identity_teardown.dart';
import 'package:jeeb_mobile/features/settings/data/dio_account_service.dart';
import 'package:jeeb_mobile/features/settings/data/dio_account_session_terminator.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';

/// Counts teardown invocations, and can fail like a plugin would.
class _SpyTeardown {
  int calls = 0;
  Object? error;

  Future<void> call() async {
    calls++;
    final e = error;
    if (e != null) throw e;
  }
}

/// Every write succeeds (204) unless [patchStatus] scripts a failure.
class _ScriptedDio extends Fake implements Dio {
  _ScriptedDio({this.patchStatus});

  /// Status the `PATCH /v1/users/{id}/status` call answers with; null = 204.
  final int? patchStatus;
  final List<String> postPaths = <String>[];
  final List<String> patchPaths = <String>[];
  final List<String> deletePaths = <String>[];

  Response<T> _ok<T>(String path) =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 204);

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postPaths.add(path);
    return _ok<T>(path);
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    patchPaths.add(path);
    final status = patchStatus;
    if (status != null) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return _ok<T>(path);
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    deletePaths.add(path);
    return _ok<T>(path);
  }
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) data[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

void main() {
  late _SpyTeardown firebase;
  late _FakeSecureStorage storage;
  late AuthTokenStore tokenStore;

  setUp(() {
    firebase = _SpyTeardown();
    storage = _FakeSecureStorage();
    tokenStore = AuthTokenStore(storage: storage);
  });

  group('DioAccountService — logout drops BOTH identities', () {
    test('signOut signs out of Firebase as well as clearing the keystore',
        () async {
      await storage.write(key: 'auth.refreshToken', value: 'rt-1');
      final sut = DioAccountService(
        _ScriptedDio(),
        tokenStore,
        firebaseSignOut: firebase.call,
      );

      final outcome = await sut.signOut();

      expect(outcome, AccountActionOutcome.success);
      expect(await tokenStore.refreshToken, isNull, reason: 'Jeeb half');
      expect(
        firebase.calls,
        1,
        reason: 'Firebase half — without it the departed uid keeps reading '
            'every conversation it was a participant of',
      );
    });

    test('a THROWING Firebase sign-out still reports success', () async {
      // Fail-safe, same rule as the gateway logout: a user trapped in a
      firebase.error = StateError('firebase plugin exploded');
      final sut = DioAccountService(
        _ScriptedDio(),
        tokenStore,
        firebaseSignOut: firebase.call,
      );

      await expectLater(sut.signOut(), completion(AccountActionOutcome.success));
      expect(firebase.calls, 1);
    });

    test('account deletion (queued, and already-queued) tears Firebase down',
        () async {
      await storage.write(key: 'auth.userId', value: 'u-1');

      final queued = DioAccountService(
        _ScriptedDio(),
        tokenStore,
        firebaseSignOut: firebase.call,
      );
      expect(
        await queued.requestAccountDeletion(),
        AccountActionOutcome.success,
      );
      expect(firebase.calls, 1, reason: 'the account is going away');

      final already = DioAccountService(
        _ScriptedDio(patchStatus: 409),
        tokenStore,
        firebaseSignOut: firebase.call,
      );
      expect(
        await already.requestAccountDeletion(),
        AccountActionOutcome.alreadyPending,
      );
      expect(firebase.calls, 2, reason: '409 means it is ALREADY going away');
    });

    // CONTROL. Without this the assertions above are satisfiable by a service
    test('CONTROL: a FAILED deletion request does NOT touch Firebase',
        () async {
      await storage.write(key: 'auth.userId', value: 'u-1');
      final sut = DioAccountService(
        _ScriptedDio(patchStatus: 500),
        tokenStore,
        firebaseSignOut: firebase.call,
      );

      // F37: a 500 is a SERVER error, never a connectivity one.
      expect(
        await sut.requestAccountDeletion(),
        AccountActionOutcome.serverError,
      );
      expect(
        firebase.calls,
        0,
        reason: 'nothing was queued and the user is still signed in',
      );
    });
  });

  group('DioAccountSessionTerminator — the LIVE logout path', () {
    DioAccountSessionTerminator build(Dio dio) => DioAccountSessionTerminator(
          dio,
          tokenStore,
          deviceIdProvider: () async => 'dev-abc',
          firebaseSignOut: firebase.call,
        );

    test('logout signs out of Firebase', () async {
      await storage.write(key: 'auth.refreshToken', value: 'rt-1');

      await build(_ScriptedDio()).logout();

      expect(await tokenStore.refreshToken, isNull);
      expect(firebase.calls, 1);
    });

    test('deleteAccount signs out of Firebase', () async {
      await storage.write(key: 'auth.userId', value: 'u-1');

      await build(_ScriptedDio()).deleteAccount();

      expect(firebase.calls, 1);
    });

    test('a THROWING Firebase sign-out cannot block the logout', () async {
      firebase.error = StateError('firebase plugin exploded');
      await storage.write(key: 'auth.refreshToken', value: 'rt-1');

      await expectLater(build(_ScriptedDio()).logout(), completes);
      expect(await tokenStore.refreshToken, isNull);
    });
  });

  group('signOutFirebaseIdentity — the production default', () {
    // The ONLY claim this suite can make about the real implementation, and it
    test('with no Firebase app it completes silently, never throws', () async {
      await expectLater(signOutFirebaseIdentity(), completes);
    });
  });
}
