// End-to-end deep-link resolution gate (Sprint 3 — stream "deeplink").
//
// Proves the full chain a platform deep link travels:
//   1. DeepLinkRouteInformationParser folds the custom-scheme host back into
//      the path: `jeeb://orders/d-1` (host `orders`, path `/d-1`) → `/orders/d-1`.
//   2. go_router resolves that location to the intended GoRoute target
//      (DeliveryDetailScreen) when the user is authenticated.
//   3. GUARDRAIL — the SAME user-data deep link, while UNAUTHENTICATED, is
//      bounced by the router's first-run auth gate to the auth entry
//      (`/register`), never blind-opening the order.
//   4. In-app rooted `/...` navigations and malformed `jeeb://` links pass
//      through the parser unchanged (no accidental rewrite / no crash).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/deep_link/deep_link_resolver.dart';
import 'package:jeeb_mobile/core/deep_link/deep_link_route_information_parser.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

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

Future<_Built> _buildRouter({required SessionGate session}) async {
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
      BlocProvider<OnboardingCubit>.value(value: built.onboarding),
      BlocProvider<RoleCubit>.value(value: built.role),
      BlocProvider<RoleEligibilityCubit>.value(value: built.roleEligibility),
      BlocProvider<LocaleCubit>.value(value: built.locale),
    ],
    child: MaterialApp.router(
      // Wrap the router's parser exactly as app.dart does, so the test
      // exercises the production deep-link entry path.
      routeInformationParser: DeepLinkRouteInformationParser(
        inner: built.router.routeInformationParser,
      ),
      routerDelegate: built.router.routerDelegate,
      routeInformationProvider: built.router.routeInformationProvider,
      backButtonDispatcher: built.router.backButtonDispatcher,
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

  setUp(() async {
    await sl.reset();
    sl.registerLazySingleton<OtpService>(
      () => const FakeOtpService(latency: Duration.zero),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    required SessionGate session,
  }) async {
    built = await _buildRouter(session: session);
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

  group('DeepLinkRouteInformationParser.rewrite', () {
    final parser = DeepLinkRouteInformationParser<Object>(
      inner: _NoopParser(),
    );

    RouteInformation info(String uri) =>
        RouteInformation(uri: Uri.parse(uri));

    test('folds jeeb://orders/d-1 to /orders/d-1', () {
      expect(parser.rewrite(info('jeeb://orders/d-1')).uri.toString(),
          '/orders/d-1');
    });

    test('preserves query on fold', () {
      expect(parser.rewrite(info('jeeb://orders/d-1/otp?mode=jeeber')).uri
          .toString(),
          '/orders/d-1/otp?mode=jeeber');
    });

    test('passes an in-app rooted path through unchanged', () {
      expect(parser.rewrite(info('/wallet')).uri.toString(), '/wallet');
    });

    test('passes a malformed jeeb:// link through unchanged (no crash)', () {
      // Disallowed-charset id (a space) → resolver returns null → the original
      // is forwarded unchanged so go_router applies its own error handling.
      expect(parser.rewrite(info('jeeb://orders/d%201')).uri.toString(),
          'jeeb://orders/d%201');
    });
  });

  group('jeeb:// link resolves to the expected GoRoute', () {
    testWidgets('authenticated: jeeb://orders/d-1 → DeliveryDetailScreen',
        (tester) async {
      await pump(tester, session: const AlwaysAuthenticatedSessionGate());

      // Fold the platform link exactly as the parser would, then drive the
      // router (proving go_router resolves the folded path to its target).
      final location0 = const DeepLinkResolver()
          .resolveLocation(Uri.parse('jeeb://orders/d-1'));
      expect(location0, '/orders/d-1');
      built.router.go(location0!);
      await tester.pumpAndSettle();

      expect(location(), '/orders/d-1');
      expect(find.byType(DeliveryDetailScreen), findsOneWidget);
    });

    testWidgets(
        'GUARDRAIL: unauthenticated jeeb://orders/d-1 is bounced to /register',
        (tester) async {
      await pump(
        tester,
        session: const _ScriptedSessionGate(unauthenticated: true),
      );

      final resolution =
          const DeepLinkResolver().resolve(Uri.parse('jeeb://orders/d-1'))!;
      expect(resolution.requiresAuth, isTrue);

      built.router.go(resolution.location);
      await tester.pumpAndSettle();

      // The auth gate refused to open the order; the deep link landed on the
      // auth entry instead (DEFECT-3 phone-OTP /register).
      expect(location(), '/register');
      expect(find.byType(DeliveryDetailScreen), findsNothing);
    });
  });
}

/// Minimal parser used to unit-test [DeepLinkRouteInformationParser.rewrite] in
/// isolation without standing up a full GoRouter.
class _NoopParser extends RouteInformationParser<Object> {
  @override
  Future<Object> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri;
}
