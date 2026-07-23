// JEBV4-176 — the capture-location placeholder must NOT fabricate a coordinate.
//
// The capture-location route used to seed its map controller with a hardcoded
// Beirut-downtown centre (33.8938, 35.5018) and pop THAT back on "Pin Location".
// Because the neutral placeholder viewport never pans (no live map is injected
// yet — B-23, Maps key owner-gated), every confirmed pin silently collapsed to
// downtown Beirut and could create a Beirut-pinned request. JEBV4-176 removes
// that silent fabrication: the placeholder route now pops WITHOUT a coordinate,
// so `markPinned(null, null)` leaves the pinned choice un-confirmable (Confirm
// stays disabled) exactly like the GPS-recovery path — no fabricated pickup can
// reach `POST /requests`.
//
// This test drives the REAL production `AppRouter` end-to-end:
//   request-type → location-select → capture-location (the ACTUAL
//   `CaptureLocationRoute` builder) → Pin Location → back to location-select →
//   attempt Confirm.
// It asserts that after the placeholder pin, NO create draft is submitted (the
// Confirm CTA is gated off) — and therefore the old Beirut default never
// reaches a request. It deliberately exercises `AppRouter`'s own
// `/capture-location` builder (NOT a hand-rolled stub GoRouter), so it FAILS if
// that builder ever regresses to fabricating a coordinate on pop. Once B-23
// injects a live `GoogleMap` mapBuilder, the pop will carry a real user-picked
// point and the choice becomes confirmable again.

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
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
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
  group('JEBV4-176 — the placeholder pin does NOT fabricate via the REAL '
      'AppRouter', () {
    late FakeRequestSubmissionService submission;

    setUp(() async {
      // A tall viewport so the below-the-fold add-location row is laid out
      // (the lazy ListView builds no element for off-screen rows).
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final view = binding.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 3200);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await sl.reset();
      submission = FakeRequestSubmissionService(requestId: 'req-b35');
      sl.registerLazySingleton<RequestSubmissionService>(() => submission);
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
      sl.registerLazySingleton<LocationSelectRepository>(
        FakeLocationSelectRepository.new,
      );
      // JEBV4-176: current-location resolves a REAL device fix (non-Beirut).
      sl.registerLazySingleton<CurrentLocationResolver>(
        FakeCurrentLocationResolver.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // Cold-load failure keeps the post-create waiting screen timer-free.
      sl.registerLazySingleton<WaitingRepository>(
        () => FakeWaitingRepository(
          failure: const WaitingException(WaitingFailure.network),
        ),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets(
      'the production /capture-location builder pops WITHOUT a coordinate, so '
      'the pinned choice is un-confirmable and no fabricated draft is created',
      (tester) async {
        final built = await _buildRouter();
        built.router.go('/request-type');
        await tester.pumpWidget(
          _harness(
            built.router,
            built.role,
            built.roleEligibility,
            built.locale,
          ),
        );
        await tester.pumpAndSettle();

        // Tier → Continue → location-select.
        await tester.tap(
          find.bySemanticsIdentifier('request_type_flash_radio'),
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('request_type_continue_cta'),
        );
        await tester.pumpAndSettle();

        // Open the map picker via the screen's OWN handler (the router no longer
        // overrides it) — this pushes the REAL `CaptureLocationRoute`.
        await tester.tap(
          find.bySemanticsIdentifier('location_select_new_location_cta'),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
          findsOneWidget,
        );

        // Confirm the pin — the production builder pops WITHOUT a coordinate
        // (JEBV4-176: no fabricated Beirut default).
        await tester.tap(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
        );
        await tester.pumpAndSettle();

        // Back on location-select: supply the G1 description, then attempt to
        // confirm. The pinned choice has NO real coordinate, so `canConfirm` is
        // false and the Confirm CTA is disabled — the tap is a no-op.
        await tester.enterText(
          find.byKey(const Key('clientLocation.descriptionField')),
          'A cake from Sea Sweet',
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('location_select_confirm_cta'),
        );
        await tester.pumpAndSettle();

        // No create draft was submitted: the placeholder pin fabricated nothing,
        // so `POST /requests` was never called. A regression that re-fabricated
        // a coordinate on pop would make the choice confirmable and submit a
        // draft carrying the removed Beirut default — failing here.
        expect(submission.submitCount, 0);
        expect(submission.lastDraft, isNull);
      },
    );
  });
}
