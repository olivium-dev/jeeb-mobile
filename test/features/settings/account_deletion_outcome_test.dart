// F3: `_requestAccountDeletion` wrapped the PATCH in `catch (_) {}` and
// returned early on a null userId, so `deleteAccount()` always resolved and
// the sheet reported success for an account that still exists.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/settings/data/dio_account_session_terminator.dart';
import 'package:jeeb_mobile/features/settings/domain/account_session_terminator.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

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
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
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

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.clear();
  }
}

class _ScriptedDio extends Fake implements Dio {
  _ScriptedDio({this.patchStatus});

  final int? patchStatus;
  final List<String> deletePaths = <String>[];

  Response<T> _ok<T>(String path) =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 204);

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
    final int? status = patchStatus;
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

/// A terminator that always fails the deletion, for the sheet test.
class _ThrowingTerminator implements AccountSessionTerminator {
  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    throw const ServerFailure(status: 500);
  }

  @override
  Future<void> logout() async {}
}

void main() {
  late _FakeSecureStorage storage;
  late AuthTokenStore tokenStore;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = _FakeSecureStorage();
    tokenStore = AuthTokenStore(storage: storage);
  });

  DioAccountSessionTerminator build(Dio dio) => DioAccountSessionTerminator(
        dio,
        tokenStore,
        deviceIdProvider: () async => 'dev-abc',
        firebaseSignOut: () async {},
      );

  test('a 500 THROWS and clears nothing — the account still exists', () async {
    await storage.write(key: 'auth.accessToken', value: 'at-1');
    await storage.write(key: 'auth.userId', value: 'u-1');
    final dio = _ScriptedDio(patchStatus: 500);

    await expectLater(
      build(dio).deleteAccount(),
      throwsA(isA<ServerFailure>()),
    );

    expect(dio.deletePaths, isEmpty, reason: 'push device stays registered');
    expect(storage.data.containsKey('auth.accessToken'), isTrue);
  });

  test('a null userId THROWS UnauthorizedFailure and clears nothing',
      () async {
    await storage.write(key: 'auth.accessToken', value: 'at-1');
    final dio = _ScriptedDio();

    await expectLater(
      build(dio).deleteAccount(),
      throwsA(isA<UnauthorizedFailure>()),
    );

    expect(dio.deletePaths, isEmpty);
    expect(storage.data.containsKey('auth.accessToken'), isTrue);
  });

  test('a 204 clears the local session', () async {
    await storage.write(key: 'auth.accessToken', value: 'at-1');
    await storage.write(key: 'auth.userId', value: 'u-1');
    final dio = _ScriptedDio();

    await build(dio).deleteAccount();

    expect(dio.deletePaths, contains('/api/PushNotification/device'));
    expect(storage.data.containsKey('auth.accessToken'), isFalse);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · a failed deletion keeps the sheet '
        'open and never completes', (tester) async {
      useReduceMotion(tester);
      final terminator = _ThrowingTerminator();
      var completed = 0;

      await tester.pumpWidget(
        wrapForTest(
          Scaffold(
            body: LogoutDeleteConfirmSheet(
              mode: LogoutDeleteMode.delete,
              terminator: terminator,
              onCompleted: () => completed++,
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('delete_confirm_cta'));
      await tester.pumpAndSettle();

      expect(terminator.deleteCalls, 1);
      expect(completed, 0, reason: 'nothing was deleted, so nothing completed');
      expect(
        find.bySemanticsIdentifier('logout_delete_confirm_sheet'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('logout_delete_error'), findsOneWidget);
    });
  }
}
