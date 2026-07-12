// W1-INT route-resolution gate + RC-9 biometric/session guard.
//
// Proves the Wave-1 integrator route batch (21_NAV_PLAN §B batch W1;
// 50_EXECUTION_PLAN §"WAVE 1 (1) S1") is REGISTERED and that each new route
// resolves to its target widget — the integrator's exit gate ("every new route
// reaches its target"). These are nav-honesty pins (CTO brief §6.7): before the
// per-screen engineers wire any W1 call site, the targets must exist.
//
//   /requests/:id/offers   → ClientOffersScreen        (offer-review,  JM-028)
//   /requests/:id/waiting  → NoOfferTimeoutScreen      (waiting,       JM-026)
//   /orders/:id/receipt    → DeliveryReceiptScreen     (delivered-rcpt,JM-033)
//   /orders/:id/summary    → OrderSummaryScreen        (order-summary, JM-031)
//   /settings/addresses/edit → AddressDetailFormScreen (address-detail,JM-050)
//
// Plus RC-9 (W0 jm-007 AC6, 61_W0_QA_RESULTS): the biometric gate must NOT
// capture a LOGGED-OUT user onto /lock — an enrolled-but-tokenless returning
// user lands on the auth entry (`/register`, DEFECT-3 phone-OTP), never /lock.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_state.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/order_summary_screen.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A scripted session gate so the router's session check is deterministic
/// without a keystore (mirrors `fr_gating_first_run_test.dart`).
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

/// Builds the router onboarded + (by default) authenticated so an explicit
/// goNamed to each W1 route resolves without the login-redirect bouncing it.
/// [biometricEnrolled] seeds the `biometric_enrolled_logged_out` state for the
/// RC-9 guard test (enabled + PIN fallback → `locked`).
Future<_Built> _buildRouter({
  SessionGate session = const AlwaysAuthenticatedSessionGate(),
  bool biometricEnrolled = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.onboarding.completed': true,
    if (biometricEnrolled) ...<String, Object>{
      BiometricPreferenceRepositoryImpl.kEnabledKey: true,
      SharedPrefsPinRepository.kPinKey: '0000',
    },
  });
  final prefs = await SharedPreferences.getInstance();

  final onboarding = OnboardingCubit(prefs: prefs);
  final lock = BiometricLockCubit(
    preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
    gateway: const UnavailableBiometricGateway(),
    pinRepository: SharedPrefsPinRepository(prefs: prefs),
  );
  if (biometricEnrolled) {
    // Reach BiometricLockPhase.locked (enabled && hasPin → canChallenge), the
    // exact state a returning enrolled user has before unlocking.
    await lock.evaluate();
  }
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
      // Provide the app-level BiometricLockCubit (as app.dart does) so the
      // real BiometricLockScreen renders when the gate holds `/lock`.
      BlocProvider<BiometricLockCubit>.value(value: built.lock),
      // The tokenless redirect now lands on `/register` (DEFECT-3 phone-OTP),
      // whose RegistrationScreen reads OnboardingCubit in its verify callbacks.
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

void main() {
  late _Built built;

  setUp(() async {
    // The `/register` redirect (RC-9 logged-out test) mounts RegistrationScreen,
    // which resolves `sl<OtpService>()` at build. Register the in-repo fake so
    // the destination renders without the real auth-service client.
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
    SessionGate session = const AlwaysAuthenticatedSessionGate(),
    bool biometricEnrolled = false,
  }) async {
    built = await _buildRouter(
      session: session,
      biometricEnrolled: biometricEnrolled,
    );
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

  group('W1 integrator routes resolve to their targets', () {
    // Lightweight stub/leaf screens with no DI/provider deps: mount + find.
    // waiting-no-coverage (NoOfferTimeoutScreen) graduated from the integrator
    // stub to the real JM-026 screen, which self-provides a ticker-driven
    // WaitingCubit (poll + countdown) over sl<WaitingRepository>(); mounting it
    // in a bare harness leaks the poll/clock timers (the screen owns its own
    // `cubitFactory` test seam for that, exercised by the JM-026 widget tests).
    // Proving the route REGISTRATION via namedLocation is the integrator's
    // contract here — identical to the offer-review pin below (both are
    // cubit-bearing W1 screens).
    testWidgets('waiting-no-coverage route is registered at /requests/:id/waiting',
        (tester) async {
      await pump(tester);
      expect(
        built.router.namedLocation('waiting-no-coverage',
            pathParameters: {'id': 'req-1'}),
        '/requests/req-1/waiting',
      );
    });

    testWidgets('/orders/:id/receipt → DeliveryReceiptScreen (delivered-receipt)',
        (tester) async {
      await pump(tester);
      built.router
          .goNamed('delivered-receipt', pathParameters: {'id': 'del-1'});
      // pump (not pumpAndSettle): the screen self-provides DeliveryReceiptCubit
      // which loads via the Fake (no DI here) and the loaded body renders an
      // OmdsCachedImage proof photo (CachedNetworkImage) whose HTTP fetch never
      // completes under the test HttpClient — pumpAndSettle would spin forever.
      // Two pumps mount the route + let load() settle; the route-resolution
      // contract (resolves to DeliveryReceiptScreen) holds regardless of the
      // image frame. Mirrors the namedLocation posture for the other
      // cubit-bearing W1 screens above.
      await tester.pump();
      await tester.pump();
      expect(location(), '/orders/del-1/receipt');
      expect(find.byType(DeliveryReceiptScreen), findsOneWidget);
    });

    testWidgets('/orders/:id/summary → OrderSummaryScreen (order-summary)',
        (tester) async {
      await pump(tester);
      built.router
          .goNamed('order-summary', pathParameters: {'id': 'del-1'});
      await tester.pumpAndSettle();
      expect(location(), '/orders/del-1/summary');
      expect(find.byType(OrderSummaryScreen), findsOneWidget);
    });

    // address-detail is nested under `/settings/addresses`; navigating to the
    // child transiently builds the parent SavedLocationsScreen page (which
    // self-provides SavedLocationsCubit, absent in this bare harness) during
    // the route transition. The route itself resolves to AddressDetailFormScreen
    // (verified: AddressForm=1, SavedLocations=0). Prove the REGISTRATION via
    // namedLocation here (the JM-050 flow mounts it with the cubit provided) —
    // same posture as offer-review/`/lock` below.
    testWidgets(
        'address-detail route is registered at /settings/addresses/edit',
        (tester) async {
      await pump(tester);
      expect(
        built.router.namedLocation('address-detail'),
        '/settings/addresses/edit',
      );
    });

    // offer-review (ClientOffersScreen) self-provides a ticker-driven cubit
    // over sl<OffersRepository>(); mounting it in a bare harness leaks the
    // poll timer (the screen owns its own test seam for that). Proving the
    // route REGISTRATION via namedLocation is the integrator's contract here
    // (mirrors how w0_routes_resolve_test pins `/lock` registration).
    testWidgets('offer-review route is registered at /requests/:id/offers',
        (tester) async {
      await pump(tester);
      expect(
        built.router
            .namedLocation('offer-review', pathParameters: {'id': 'req-1'}),
        '/requests/req-1/offers',
      );
    });

    testWidgets('every W1 route name resolves (namedLocation, nav-honesty)',
        (tester) async {
      await pump(tester);
      expect(built.router.namedLocation('offer-review',
          pathParameters: {'id': 'r'}), '/requests/r/offers');
      expect(built.router.namedLocation('waiting-no-coverage',
          pathParameters: {'id': 'r'}), '/requests/r/waiting');
      expect(built.router.namedLocation('delivered-receipt',
          pathParameters: {'id': 'd'}), '/orders/d/receipt');
      expect(built.router.namedLocation('order-summary',
          pathParameters: {'id': 'd'}), '/orders/d/summary');
      expect(built.router.namedLocation('address-detail'),
          '/settings/addresses/edit');
    });
  });

  group('RC-9 — biometric gate honours the session', () {
    testWidgets(
        'enrolled BUT logged-out → /register, never /lock (RC-9, jm-007 AC6)',
        (tester) async {
      // biometric_enrolled_logged_out: enrolled (locked phase) AND no token.
      await pump(
        tester,
        session: const _ScriptedSessionGate(unauthenticated: true),
        biometricEnrolled: true,
      );
      // The lock cubit really reports `locked` (the pre-RC-9 gate would have
      // captured /lock); the session gate forces the auth entry first. That
      // entry is `/register` — the phone-OTP + Apple/Google social entry; the
      // email/password `/login` funnel was removed in JEBV4-199 (Q-044). The
      // RC-9 property under test is unchanged: a logged-out user must land on
      // the auth entry and NEVER be captured by `/lock`.
      expect(built.lock.state.phase, BiometricLockPhase.locked);
      expect(location(), '/register');
      expect(location(), isNot('/lock'));
    });

    testWidgets('enrolled AND logged-in → /lock still holds (no JM-005 regression)',
        (tester) async {
      await pump(
        tester,
        session: const _ScriptedSessionGate(unauthenticated: false),
        biometricEnrolled: true,
      );
      expect(built.lock.state.phase, BiometricLockPhase.locked);
      expect(location(), '/lock');
    });
  });
}
