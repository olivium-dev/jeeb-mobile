// W3+W4-INT route-resolution gate (the FINAL-WAVE integrator's exit gate).

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
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';
import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/transaction_detail_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';
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
/// W3/W4 route resolves without the login-redirect bouncing it.
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
      // LanguageSettingsScreen reads LocaleCubit from context (provided globally
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

  group('W3 integrator routes resolve to their targets', () {
    testWidgets('/wallet/activity → WalletActivityListScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('wallet-activity');
      await tester.pumpAndSettle();
      expect(location(), '/wallet/activity');
      expect(find.byType(WalletActivityListScreen), findsOneWidget);
    });

    testWidgets('/wallet/transactions/:id → TransactionDetailScreen',
        (tester) async {
      await pump(tester);
      built.router.goNamed('transaction-detail',
          pathParameters: <String, String>{'id': 'txn-1'});
      await tester.pumpAndSettle();
      expect(location(), '/wallet/transactions/txn-1');
      expect(find.byType(TransactionDetailScreen), findsOneWidget);
    });
  });

  group('W4 integrator routes resolve to their targets', () {
    testWidgets('/notifications → NotificationsListScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('notifications');
      await tester.pumpAndSettle();
      expect(location(), '/notifications');
      expect(find.byType(NotificationsListScreen), findsOneWidget);
    });

    testWidgets('/support → SupportTicketScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('support-ticket');
      await tester.pumpAndSettle();
      expect(location(), '/support');
      expect(find.byType(SupportTicketScreen), findsOneWidget);
    });

    testWidgets('/disputes/:id → DisputeStatusScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('dispute-status',
          pathParameters: <String, String>{'id': 'dsp-1'});
      await tester.pumpAndSettle();
      expect(location(), '/disputes/dsp-1');
      expect(find.byType(DisputeStatusScreen), findsOneWidget);
    });

    testWidgets('/profile/delivery-man/reviews → ReviewsListScreen',
        (tester) async {
      await pump(tester);
      built.router.goNamed('reviews-list');
      await tester.pumpAndSettle();
      expect(location(), '/profile/delivery-man/reviews');
      expect(find.byType(ReviewsListScreen), findsOneWidget);
    });

    testWidgets('/settings/language → LanguageSettingsScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('language-settings');
      await tester.pumpAndSettle();
      expect(location(), '/settings/language');
      expect(find.byType(LanguageSettingsScreen), findsOneWidget);
    });

    testWidgets('/settings/password → PasswordSecurityScreen', (tester) async {
      await pump(tester);
      built.router.goNamed('password-security');
      await tester.pumpAndSettle();
      expect(location(), '/settings/password');
      expect(find.byType(PasswordSecurityScreen), findsOneWidget);
    });
  });

  testWidgets('every W3/W4 route name resolves (namedLocation, nav-honesty)',
      (tester) async {
    await pump(tester);
    expect(built.router.namedLocation('wallet-activity'), '/wallet/activity');
    expect(
      built.router.namedLocation('transaction-detail',
          pathParameters: <String, String>{'id': 't1'}),
      '/wallet/transactions/t1',
    );
    expect(built.router.namedLocation('notifications'), '/notifications');
    expect(built.router.namedLocation('support-ticket'), '/support');
    expect(
      built.router.namedLocation('dispute-status',
          pathParameters: <String, String>{'id': 'd1'}),
      '/disputes/d1',
    );
    expect(built.router.namedLocation('reviews-list'),
        '/profile/delivery-man/reviews');
    expect(built.router.namedLocation('language-settings'),
        '/settings/language');
    expect(built.router.namedLocation('password-security'),
        '/settings/password');
  });
}
