// Search route-resolution gate (FIX-SEARCH-P0, cycle-6).
//
// Regression pin for the cycle-4/5 integration merge-drop documented in
// bugs/notif-prefs-405.md §Bug 2: commit a0a1502 added BOTH the `/search` +
// `/search-results` GoRoutes AND the shell-header `goNamed('search')` caller,
// but a later integration merge clobbered the router half while keeping the
// caller — so every header search tap threw a GoError (unknown route).
//
// This test drives the SURVIVING caller's target: `goNamed('search')` must
// navigate to the compose surface (SearchScreen) without throwing, and the
// `/search-results?q=` route must resolve to SearchResultsScreen. If an
// integration merge silently re-drops the registration, these fail.
//
//   /search          → SearchScreen         (search,         Stream C)
//   /search-results  → SearchResultsScreen  (search-results, Stream C)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/search/presentation/search_screen.dart';
import 'package:jeeb_mobile/features/search/presentation/search_results_screen.dart';
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

/// Builds the router onboarded + authenticated so an explicit goNamed to the
/// search routes resolves without the login-redirect bouncing it.
Future<_Built> _buildRouter() async {
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
    session: const AlwaysAuthenticatedSessionGate(),
  );
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
      BlocProvider<BiometricLockCubit>.value(value: built.lock),
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

  tearDown(() async {
    await GetIt.instance.reset();
  });

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

  group('search routes resolve (regression: merge-drop §Bug 2)', () {
    testWidgets(
        "goNamed('search') navigates to SearchScreen without throwing",
        (tester) async {
      await pump(tester);
      // The exact call the surviving shell-header search icon makes.
      built.router.goNamed('search');
      await tester.pumpAndSettle();
      expect(location(), '/search');
      expect(find.byType(SearchScreen), findsOneWidget);
      // No GoError / exception was thrown while navigating or building.
      expect(tester.takeException(), isNull);
    });

    testWidgets('/search-results?q= → SearchResultsScreen', (tester) async {
      await pump(tester);
      built.router.goNamed(
        'search-results',
        queryParameters: const <String, String>{'q': 'phone'},
      );
      await tester.pumpAndSettle();
      expect(location(), '/search-results?q=phone');
      expect(find.byType(SearchResultsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both search route names resolve (nav-honesty)',
        (tester) async {
      await pump(tester);
      expect(built.router.namedLocation('search'), '/search');
      expect(built.router.namedLocation('search-results'), '/search-results');
    });
  });
}
