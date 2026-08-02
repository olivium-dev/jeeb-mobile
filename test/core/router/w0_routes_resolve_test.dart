// W0-INT route-resolution gate.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

typedef _Built = ({
  GoRouter router,
  OnboardingCubit onboarding,
  BiometricLockCubit lock,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
});

Future<_Built> _buildRouter() async {
  // Onboarded so the first-run onboarding gate is satisfied; the default
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

  final router = AppRouter.create(onboarding: onboarding, biometricLock: lock);
  return (
    router: router,
    onboarding: onboarding,
    lock: lock,
    role: role,
    roleEligibility: roleEligibility,
    locale: locale,
  );
}

Widget _harness(_Built built) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>.value(value: built.role),
      BlocProvider<RoleEligibilityCubit>.value(value: built.roleEligibility),
      BlocProvider<LocaleCubit>.value(value: built.locale),
    ],
    child: MaterialApp.router(
      routerConfig: built.router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  late _Built built;

  Future<void> pump(WidgetTester tester) async {
    built = await _buildRouter();
    addTearDown(() {
      built.lock.close();
      built.role.close();
      built.roleEligibility.close();
      built.locale.close();
      built.onboarding.close();
      built.router.dispose();
    });
    await tester.pumpWidget(_harness(built));
    await tester.pumpAndSettle();
  }

  String location() =>
      built.router.routerDelegate.currentConfiguration.uri.toString();

  group('W0 integrator routes resolve to their stubs', () {
    // JEBV4-199: the hidden email/password funnel route names are GONE. A
    for (final removed in const ['login', 'sign-up', 'recover-password',
        'recover-verify']) {
      testWidgets('removed funnel route "$removed" no longer resolves',
          (tester) async {
        await pump(tester);
        expect(
          () => built.router.namedLocation(removed),
          throwsA(anything),
          reason: 'JEBV4-199 deleted the $removed route',
        );
      });
    }

    testWidgets('/set-password → SetPasswordScreen (in-app-social)',
        (tester) async {
      await pump(tester);
      built.router.go('/set-password?mode=in-app-social');
      await tester.pumpAndSettle();
      final screen = tester.widget<SetPasswordScreen>(
        find.byType(SetPasswordScreen),
      );
      expect(screen.mode, SetPasswordMode.inAppSocial);
    });

    testWidgets('/account-status → AccountStatusScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('account-status');
      await tester.pumpAndSettle();
      expect(location(), '/account-status');
      expect(find.byType(AccountStatusScreen), findsOneWidget);
    });

    testWidgets('biometric-lock route is registered at /lock', (tester) async {
      await pump(tester);
      // The biometric gate redirects `/lock` → `/` while the (stub) cubit
      expect(built.router.namedLocation('biometric-lock'), '/lock');
    });

    testWidgets(
        'BiometricLockScreen is the real screen exposing biometric_unlock_prompt',
        (tester) async {
      // Mount the screen directly: the `/lock` builder now uses this real
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final lock = BiometricLockCubit(
        preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
        gateway: const UnavailableBiometricGateway(),
        pinRepository: SharedPrefsPinRepository(prefs: prefs),
      );
      addTearDown(lock.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<BiometricLockCubit>.value(
            value: lock,
            child: const BiometricLockScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('biometric_unlock_prompt'),
        findsOneWidget,
      );
    });
  });
}
