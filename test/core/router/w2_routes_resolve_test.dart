// W2-INT route-resolution gate.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/wallet/data/stub_wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_charge_info_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';
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

/// Builds the router onboarded + authenticated so an explicit goNamed to each
/// W2 route resolves without the login-redirect bouncing it.
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
      // JeebEmptyState's E1 illustration loops ∞ by design (02-STUDY-NOTES
      // §Motion): pumpAndSettle only terminates under reduce motion.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
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

  setUp(() {
    // WalletHubScreen self-provides WalletHubCubit over sl<WalletRepository>().
    if (!sl.isRegistered<WalletRepository>()) {
      sl.registerLazySingleton<WalletRepository>(
        () => const StubWalletRepository(),
      );
    }
    // WalletHubScreen (JM-053) also reads sl<JeeberKycStatusGate>() for the AC7
    if (!sl.isRegistered<JeeberKycStatusGate>()) {
      sl.registerLazySingleton<JeeberKycStatusGate>(
        () => const SeamJeeberKycStatusGate(),
      );
    }
  });

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
    // Home's in-memory repo resolves behind a 150ms fake-latency timer that
    // schedules no frame; advance past it so none is left pending.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  String location() =>
      built.router.routerDelegate.currentConfiguration.uri.toString();

  group('W2 integrator routes resolve to their targets', () {
    testWidgets('/jeeber/onboarding/funding → OnboardingFundingScreen',
        (tester) async {
      await pump(tester);
      built.router.goNamed('onboarding-funding');
      await tester.pumpAndSettle();
      expect(location(), '/jeeber/onboarding/funding');
      expect(find.byType(OnboardingFundingScreen), findsOneWidget);
    });

    testWidgets('/jeeber/offer-gate → OfferKycGateScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('offer-kyc-gate');
      await tester.pumpAndSettle();
      expect(location(), '/jeeber/offer-gate');
      expect(find.byType(OfferKycGateScreen), findsOneWidget);
    });

    testWidgets('/kyc/rejected → KycRejectedScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('kyc-rejected');
      await tester.pumpAndSettle();
      expect(location(), '/kyc/rejected');
      expect(find.byType(KycRejectedScreen), findsOneWidget);
    });

    testWidgets('/jeeber/pending-offers → JeeberPendingOffersScreen',
        (tester) async {
      await pump(tester);
      built.router.goNamed('jeeber-pending-offers');
      await tester.pumpAndSettle();
      expect(location(), '/jeeber/pending-offers');
      expect(find.byType(JeeberPendingOffersScreen), findsOneWidget);
    });

    testWidgets('/wallet → WalletHubScreen (REPLACES the coming-soon stub)',
        (tester) async {
      await pump(tester);
      built.router.goNamed('wallet');
      await tester.pumpAndSettle();
      expect(location(), '/wallet');
      expect(find.byType(WalletHubScreen), findsOneWidget);
    });

    testWidgets('/wallet/charge-info → WalletChargeInfoScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('wallet-charge-info');
      await tester.pumpAndSettle();
      expect(location(), '/wallet/charge-info');
      expect(find.byType(WalletChargeInfoScreen), findsOneWidget);
    });

    testWidgets('every W2 route name resolves (namedLocation, nav-honesty)',
        (tester) async {
      await pump(tester);
      expect(built.router.namedLocation('onboarding-funding'),
          '/jeeber/onboarding/funding');
      expect(built.router.namedLocation('offer-kyc-gate'),
          '/jeeber/offer-gate');
      expect(built.router.namedLocation('kyc-rejected'), '/kyc/rejected');
      expect(built.router.namedLocation('jeeber-pending-offers'),
          '/jeeber/pending-offers');
      expect(built.router.namedLocation('wallet'), '/wallet');
      expect(built.router.namedLocation('wallet-charge-info'),
          '/wallet/charge-info');
    });
  });
}
