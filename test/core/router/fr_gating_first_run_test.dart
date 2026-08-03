// FR-GATING regression suite: prove the first-run routing is DETERMINISTIC and

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/onboarding/onboarding_screen.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/sync_app_localizations.dart';

/// A scripted gate so the router's session check is deterministic without a
/// keystore. `unauthenticated: true` means "onboarded user has no valid token".
class _ScriptedSessionGate implements SessionGate {
  const _ScriptedSessionGate({required this.unauthenticated});
  final bool unauthenticated;
  @override
  bool get isUnauthenticated => unauthenticated;
}

typedef _Built = ({
  GoRouter router,
  OnboardingCubit onboarding,
  BiometricLockCubit lock,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
});

Future<_Built> _buildRouter({
  required bool onboardingCompleted,
  SessionGate session = const AlwaysAuthenticatedSessionGate(),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.onboarding.completed': onboardingCompleted,
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
      BlocProvider<OnboardingCubit>.value(value: built.onboarding),
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

/// The router's resolved top-level location. Reliable for REDIRECT assertions
/// (redirects change the real location), unlike imperative push.
String _location(_Built built) =>
    built.router.routerDelegate.currentConfiguration.uri.toString();

void _addCleanup(_Built built) {
  addTearDown(() {
    built.lock.close();
    built.role.close();
    built.roleEligibility.close();
    built.locale.close();
    built.onboarding.close();
    built.router.dispose();
  });
}

void main() {
  assert(kDebugMode, 'FR-GATING tests must run in debug (dev-seam getters live)');

  setUp(() async {
    // The /register redirect mounts RegistrationScreen, which resolves
    await sl.reset();
    sl.registerLazySingleton<OtpService>(
      () => const FakeOtpService(latency: Duration.zero),
    );
    // JEBV4-176: current-location resolves a REAL device fix (no geolocator in
    sl.registerLazySingleton<CurrentLocationResolver>(
      FakeCurrentLocationResolver.new,
    );
  });

  tearDown(() async {
    DevSeam.debugReset();
    await sl.reset();
  });

  group('FR-P0-1: DevSeam route pin cannot silently skip first-run', () {
    testWidgets(
      'fresh install + bare jeeb.route=/ (no skip flag) LANDS ON ONBOARDING',
      (tester) async {
        // The exact historical bypass: a dev pins `/` out of habit.
        DevSeam.debugOverride(const DevSeamConfig(route: '/'));
        final built = await _buildRouter(onboardingCompleted: false);
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(
          find.byType(OnboardingScreen),
          findsOneWidget,
          reason: 'A bare route pin must NOT bypass onboarding on a fresh '
              'install — the onboarding gate wins.',
        );
        expect(find.byType(ShellScreen), findsNothing);
        expect(_location(built), '/onboarding');
      },
    );

    testWidgets(
      'fresh install + jeeb.route=/ + JEEB_DEV_HOME-style pin to / still '
      'lands on onboarding (no skip flag)',
      (tester) async {
        // Even a device-file shaped pin to a deep authenticated route must not
        DevSeam.debugOverride(const DevSeamConfig(route: '/client-location'));
        final built = await _buildRouter(onboardingCompleted: false);
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(ClientLocationScreen), findsNothing);
        expect(_location(built), '/onboarding');
      },
    );

    testWidgets(
      'fresh install + route=/ + skipOnboarding=true DOES bypass to Home '
      '(explicit opt-in)',
      (tester) async {
        DevSeam.debugOverride(
          const DevSeamConfig(route: '/', skipOnboarding: true),
        );
        final built = await _buildRouter(onboardingCompleted: false);
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(
          find.byType(ShellScreen),
          findsOneWidget,
          reason: 'With the explicit skipOnboarding opt-in, the pin bypasses '
              'first-run as before.',
        );
      },
    );

    testWidgets(
      'fresh install + deep route + skipOnboarding=true lands on the deep '
      'route (deep capture without seeding prefs)',
      (tester) async {
        DevSeam.debugOverride(
          const DevSeamConfig(
            route: '/client-location',
            skipOnboarding: true,
          ),
        );
        final built = await _buildRouter(onboardingCompleted: false);
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(ClientLocationScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'deep-capture on an ALREADY-ONBOARDED device still works WITHOUT skip '
      '(prior behaviour preserved)',
      (tester) async {
        // This is the original capture use case: onboarding already complete,
        DevSeam.debugOverride(const DevSeamConfig(route: '/client-location'));
        final built = await _buildRouter(onboardingCompleted: true);
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(ClientLocationScreen), findsOneWidget);
      },
    );
  });

  group('FR-P0-3: session/JWT gate forces auth when tokenless', () {
    testWidgets(
      'onboarded + NO token → redirected to /register (auth entry, not Home)',
      (tester) async {
        final built = await _buildRouter(
          onboardingCompleted: true,
          session: const _ScriptedSessionGate(unauthenticated: true),
        );
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        // JEBV4-199 (Q-044): the logged-out destination is `/register`, the
        expect(
          _location(built),
          '/register',
          reason: 'An onboarded-but-tokenless user must be forced to the '
              'phone-OTP auth entry before reaching Home.',
        );
        expect(find.byType(RegistrationScreen), findsOneWidget);
        expect(find.byType(ShellScreen), findsNothing);
      },
    );

    testWidgets(
      'onboarded + valid token → reaches Home (shell)',
      (tester) async {
        final built = await _buildRouter(
          onboardingCompleted: true,
          session: const _ScriptedSessionGate(unauthenticated: false),
        );
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(ShellScreen), findsOneWidget);
        expect(_location(built), '/');
      },
    );

    testWidgets(
      'unknown (cold-start) session is INERT — onboarded user reaches Home '
      'until evaluation resolves (no /register flash)',
      (tester) async {
        // The default AlwaysAuthenticatedSessionGate stands in for the inert
        final built = await _buildRouter(onboardingCompleted: true);
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(ShellScreen), findsOneWidget);
      },
    );
  });

  group('FR-P0-1 + FR-P0-3 combined: the full first-run invariant', () {
    testWidgets(
      'empty prefs + no token + no dev-seam → deterministically NOT Home '
      '(onboarding first, then login)',
      (tester) async {
        // No DevSeam override at all. Fresh install, no token.
        final built = await _buildRouter(
          onboardingCompleted: false,
          session: const _ScriptedSessionGate(unauthenticated: true),
        );
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        // Onboarding gate wins first (it precedes the session gate).
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(ShellScreen), findsNothing);
        expect(_location(built), '/onboarding');
      },
    );

    testWidgets(
      'after onboarding completes, the tokenless user is bounced to /register '
      '(auth becomes mandatory)',
      (tester) async {
        final built = await _buildRouter(
          onboardingCompleted: false,
          session: const _ScriptedSessionGate(unauthenticated: true),
        );
        _addCleanup(built);
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Simulate the user finishing the walkthrough.
        await built.onboarding.complete();
        await tester.pumpAndSettle();

        // `/register` (phone-OTP + social) is the logged-out destination; the
        expect(
          _location(built),
          '/register',
          reason: 'Onboarding done + no token → auth is now mandatory.',
        );
        expect(find.byType(RegistrationScreen), findsOneWidget);
      },
    );
  });
}
