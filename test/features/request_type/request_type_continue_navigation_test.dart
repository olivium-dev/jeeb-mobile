// JM-024 — the request-type "Continue" CTA advances to `location-select`.

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
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

Future<
  ({
    GoRouter router,
    RoleCubit role,
    RoleEligibilityCubit roleEligibility,
    LocaleCubit locale,
  })
>
_buildRouter() async {
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

  // Default session gate is AlwaysAuthenticatedSessionGate, so the FR-P0-3
  final router = AppRouter.create(onboarding: onboarding, biometricLock: lock);
  return (
    router: router,
    role: role,
    roleEligibility: roleEligibility,
    locale: locale,
  );
}

Widget _harness(
  GoRouter router,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
) {
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
  group('JM-024 — /request-type Continue CTA advances to location-select', () {
    setUp(() async {
      await sl.reset();
      // `/request-type` resolves TierRepository via sl. The customer must tap a
      sl.registerLazySingleton<CurrentLocationResolver>(
        FakeCurrentLocationResolver.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // `/client-location` self-provides LocationSelectCubit; it resolves a
      sl.registerLazySingleton<LocationSelectRepository>(
        FakeLocationSelectRepository.new,
      );
      // Kept registered in case any sibling builder resolves it.
      sl.registerLazySingleton<RequestSubmissionService>(
        FakeRequestSubmissionService.new,
      );
      // iter6 B11: the request-type Continue CTA records the chosen tier in the
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets('selecting Flash then tapping Continue lands on the '
        'location-select screen (NOT the request-summary card)', (
      tester,
    ) async {
      final built = await _buildRouter();
      built.router.go('/request-type');
      await tester.pumpWidget(
        _harness(built.router, built.role, built.roleEligibility, built.locale),
      );
      await tester.pumpAndSettle();

      // The request-type screen is up; explicitly choose Flash to enable the
      expect(find.byType(RequestTypeScreen), findsOneWidget);
      await tester.tap(find.bySemanticsIdentifier('request_type_flash_radio'));
      await tester.pump();
      final continueCta = find.bySemanticsIdentifier(
        'request_type_continue_cta',
      );
      expect(continueCta, findsOneWidget);
      await tester.ensureVisible(continueCta);

      await tester.tap(continueCta);
      await tester.pumpAndSettle();

      // JM-024 AC1: Continue → location-select.
      expect(
        find.byType(ClientLocationScreen),
        findsOneWidget,
        reason:
            'Continue must advance to location-select (the blueprint '
            'create flow), not the legacy /request-summary card.',
      );
      expect(
        find.bySemanticsIdentifier('location_select_confirm_cta'),
        findsOneWidget,
        reason: 'The location-select Confirm CTA must be on screen.',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
