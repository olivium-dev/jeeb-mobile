import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/config/dev_base_url.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/devtool/dev_settings_page.dart';

class _FailingAuthTokenStore extends AuthTokenStore {
  @override
  Future<void> clear() =>
      Future<void>.error(StateError('keychain unavailable'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'auth.accessToken': 'development-access-token',
      'auth.refreshToken': 'development-refresh-token',
      'auth.userId': 'development-user',
    });
    final prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(prefs);
    sl.registerSingleton<Dio>(
      Dio(BaseOptions(baseUrl: kDevelopmentGatewayBaseUrl)),
    );
    sl.registerSingleton<AuthTokenStore>(AuthTokenStore());
  });

  tearDown(() async => sl.reset());

  testWidgets('selects staging behind a safe restart boundary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServerUrlPage()));

    expect(find.text('Development'), findsOneWidget);
    expect(find.text('Staging'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('devtool.environment.staging')),
    );
    await tester.pumpAndSettle();

    final prefs = sl<SharedPreferences>();
    expect(DevBaseUrl.readEnvironment(prefs), DevBackendEnvironment.staging);
    expect(DevBaseUrl.read(prefs), kStagingGatewayBaseUrl);
    expect(sl<Dio>().options.baseUrl, kDevelopmentGatewayBaseUrl);
    expect(await sl<AuthTokenStore>().accessToken, isNull);
    expect(find.text(kStagingGatewayBaseUrl), findsWidgets);
    expect(
      find.text(
        'Staging selected. Restart the app to apply it; the previous session '
        'was cleared.',
      ),
      findsOneWidget,
    );
    expect(find.text('Restart required'), findsOneWidget);
  });

  testWidgets('aborts the switch when old credentials cannot be cleared', (
    tester,
  ) async {
    sl.unregister<AuthTokenStore>();
    sl.registerSingleton<AuthTokenStore>(_FailingAuthTokenStore());
    await tester.pumpWidget(const MaterialApp(home: ServerUrlPage()));

    await tester.tap(
      find.byKey(const ValueKey<String>('devtool.environment.staging')),
    );
    await tester.pumpAndSettle();

    final prefs = sl<SharedPreferences>();
    expect(DevBaseUrl.readEnvironment(prefs), isNull);
    expect(DevBaseUrl.read(prefs), isNull);
    expect(sl<Dio>().options.baseUrl, kDevelopmentGatewayBaseUrl);
    expect(
      find.text('Environment switch failed; the current selection was kept.'),
      findsOneWidget,
    );
  });
}
