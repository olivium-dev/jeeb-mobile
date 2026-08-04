// T-MOB-FIX-001 — Jeeber request-detail route GetIt crash.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/observability/crash_reporter.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Future<({
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
  OnboardingCubit onboarding,
  BiometricLockCubit lock,
})> _buildCubits(SharedPreferences prefs) async {
  final onboarding = OnboardingCubit(prefs: prefs);
  final lock = BiometricLockCubit(
    preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
    gateway: const UnavailableBiometricGateway(),
    pinRepository: SharedPrefsPinRepository(prefs: prefs),
  );
  return (
    role: RoleCubit(prefs: prefs),
    roleEligibility: RoleEligibilityCubit(),
    locale: LocaleCubit(prefs: prefs),
    onboarding: onboarding,
    lock: lock,
  );
}

Widget _harness({
  required GoRouter router,
  required RoleCubit role,
  required RoleEligibilityCubit roleEligibility,
  required LocaleCubit locale,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>.value(value: role),
      BlocProvider<RoleEligibilityCubit>.value(value: roleEligibility),
      BlocProvider<LocaleCubit>.value(value: locale),
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
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await GetIt.I.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
    prefs = await SharedPreferences.getInstance();
    // Real production wiring — the same call bootstrap.dart makes. This is what
    configureDependencies(
      sharedPreferences: prefs,
      crashReporter: const NoopCrashReporter(),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets(
    'navigating to /jeeber/requests/:id with a FeedRequest extra builds the '
    'JeeberRequestDetailScreen without the GetIt Bad state crash',
    (tester) async {
      final cubits = await _buildCubits(prefs);
      final router = AppRouter.create(
        onboarding: cubits.onboarding,
        biometricLock: cubits.lock,
      );

      router.go(
        '/jeeber/requests/REQ-001',
        extra: const FeedRequest(
          id: 'REQ-001',
          shortLabel: '2kg tomatoes from the souq',
        ),
      );

      await tester.pumpWidget(
        _harness(
          router: router,
          role: cubits.role,
          roleEligibility: cubits.roleEligibility,
          locale: cubits.locale,
        ),
      );
      await tester.pumpAndSettle();

      // The exact crash signal: building the route must not throw the GetIt
      expect(
        tester.takeException(),
        isNull,
        reason: 'The jeeber-request-detail route must resolve '
            'ProhibitedItemReportService from GetIt instead of throwing '
            'a Bad state during build.',
      );
      expect(
        find.byType(JeeberRequestDetailScreen),
        findsOneWidget,
        reason: 'The detail screen must render once its reportService '
            'dependency is registered.',
      );
    },
  );

  testWidgets(
    'the route builder resolves the exact dependency the screen requires',
    (tester) async {
      // Direct assertion on the dependency the route hands to the screen's
      expect(
        GetIt.I.isRegistered<ProhibitedItemReportService>(),
        isTrue,
        reason: 'app_router resolves sl<ProhibitedItemReportService>() when '
            'building the jeeber-request-detail route.',
      );
      expect(
        () => GetIt.I<ProhibitedItemReportService>(),
        returnsNormally,
      );
    },
  );
}
