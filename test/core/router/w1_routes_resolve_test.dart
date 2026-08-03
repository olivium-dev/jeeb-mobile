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
import 'package:jeeb_mobile/core/theme/app_theme.dart';
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

/// A scripted session gate so the router's session check is det
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

/// Builds the router onboarded + (by default) authenticated so 
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
      BlocProvider<BiometricLockCubit>.value(value: built.lock),
      BlocProvider<OnboardingCubit>.value(value: built.onboarding),
      BlocProvider<RoleCubit>.value(value: built.role),
      BlocProvider<RoleEligibilityCubit>.value(value: built.roleEligibility),
      BlocProvider<LocaleCubit>.value(value: built.locale),
    ],
    child: MaterialApp.router(
      // The real app theme, as `app.dart` installs it: destination screens read
      // `Theme.of(context).extension<JeebSemanticColors>()!`, which only the
      // Jeeb theme registers. A bare default ThemeData makes them throw.
      theme: AppTheme.light(),
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

    testWidgets(
        'address-detail route is registered at /settings/addresses/edit',
        (tester) async {
      await pump(tester);
      expect(
        built.router.namedLocation('address-detail'),
        '/settings/addresses/edit',
      );
    });

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
      await pump(
        tester,
        session: const _ScriptedSessionGate(unauthenticated: true),
        biometricEnrolled: true,
      );
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
