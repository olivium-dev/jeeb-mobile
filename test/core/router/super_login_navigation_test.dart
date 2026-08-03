// DEF-1 regression: a successful super-login must land on Home immediately.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

void main() {
  assert(kDebugMode, 'router redirect tests run under debug');

  late _MockAuthTokenStore store;
  late SessionCubit session;

  setUp(() async {
    await sl.reset();
    // The /register destination resolves sl<OtpService>() at build.
    sl.registerLazySingleton<OtpService>(
      () => const FakeOtpService(latency: Duration.zero),
    );
    store = _MockAuthTokenStore();
    session = SessionCubit(tokenStore: store);
  });

  tearDown(() async {
    await session.close();
    await sl.reset();
  });

  Future<({GoRouter router, OnboardingCubit onboarding})> buildHome(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final onboarding = OnboardingCubit(prefs: prefs);
    final lock = BiometricLockCubit(
      preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
      gateway: const UnavailableBiometricGateway(),
      pinRepository: SharedPrefsPinRepository(prefs: prefs),
    );
    final role = RoleCubit(prefs: prefs);
    final roleEligibility = RoleEligibilityCubit();
    final locale = LocaleCubit(prefs: prefs);
    final router = AppRouter.create(
      onboarding: onboarding,
      biometricLock: lock,
      session: session,
    );
    addTearDown(() {
      lock.close();
      role.close();
      roleEligibility.close();
      locale.close();
      onboarding.close();
      router.dispose();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<OnboardingCubit>.value(value: onboarding),
          BlocProvider<RoleCubit>.value(value: role),
          BlocProvider<RoleEligibilityCubit>.value(value: roleEligibility),
          BlocProvider<LocaleCubit>.value(value: locale),
          // Mirror the production tree (app.dart): the SessionCubit is in scope
          BlocProvider<SessionCubit>.value(value: session),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    return (router: router, onboarding: onboarding);
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
      'onboarded + no token starts on /register; persisting a token and '
      'refreshing the session promotes go("/") to Home (DEF-1)', (tester) async {
    // Cold start: no token yet → gate forces /register (the phone-OTP + social
    when(() => store.accessToken).thenAnswer((_) async => null);

    final built = await buildHome(tester);
    await session.refresh(); // app.dart kicks this after first frame
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.byType(ShellScreen), findsNothing);
    expect(location(built.router), '/register');

    // Simulate a successful super-login: the sheet persists the real token, the
    when(() => store.accessToken).thenAnswer((_) async => 'real-access-token');
    await session.refresh();
    built.router.go('/');
    await tester.pumpAndSettle();

    expect(
      location(built.router),
      '/',
      reason: 'After the token is persisted AND the session refreshed, the '
          'first-run gate must let / resolve to Home — no relaunch required.',
    );
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(RegistrationScreen), findsNothing);
  });

  testWidgets(
      'without the session refresh, go("/") is bounced back to /register '
      '(documents the DEF-1 failure mode)', (tester) async {
    when(() => store.accessToken).thenAnswer((_) async => null);

    final built = await buildHome(tester);
    await session.refresh();
    await tester.pumpAndSettle();
    expect(location(built.router), '/register');

    // Token persisted to the keystore but the SessionCubit is NOT refreshed
    when(() => store.accessToken).thenAnswer((_) async => 'real-access-token');
    built.router.go('/');
    await tester.pumpAndSettle();

    expect(
      location(built.router),
      '/register',
      reason: 'This is the bug DEF-1 fixes: a persisted token alone does not '
          'update the router gate; the session must be refreshed.',
    );
  });
}
