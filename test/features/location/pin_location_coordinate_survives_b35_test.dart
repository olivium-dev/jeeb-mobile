// B-35 — the map-pinned coordinate must survive back to client-location.
//
// The capture-location route used to pop WITHOUT the picked LocationPoint (and
// the router even overrode the screen's own result-consuming handler with a
// fire-and-forget push), so a confirmed pin was silently discarded and every
// pinned pickup collapsed to the Beirut fallback.
//
// This test drives the REAL production `AppRouter` end-to-end:
//   request-type → location-select → capture-location (the ACTUAL
//   `CaptureLocationRoute` builder) → Pin Location → back to location-select →
//   Confirm/create.
// It asserts the coordinate the router pops reaches the `POST /requests` draft.
//
// It deliberately exercises `AppRouter`'s own `/capture-location` builder (NOT a
// hand-rolled stub GoRouter), so it FAILS if that builder ever regresses to a
// value-less `context.pop()` — the exact production regression the previous,
// stub-router version of this test could not catch.
//
// PLUMBING-COMPLETE-PENDING-B-23: no live draggable map is injected in
// production yet (B-23, Maps key owner-gated), so the placeholder viewport never
// calls `MapCaptureController.updateCenter` and the confirmed pin carries the
// canonical default centre (33.8938, 35.5018). We therefore assert THAT
// coordinate — NOT a fabricated "picked" point — reaches the draft, and prove it
// is NOT the value-less-pop fallback (33.8886, 35.4955). Once B-23 injects a
// live `GoogleMap` mapBuilder, the same pop will carry a real user-picked point.

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
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

// The canonical default centre the production router seeds the capture
// controller with (app_router `_captureDefaultCenter`). The value-less-pop
// regression would instead collapse to the compose fallback below.
const double _defaultCenterLat = 33.8938;
const double _defaultCenterLng = 35.5018;

// The Beirut fallback the compose controller applies ONLY when no pin/saved
// coordinate reaches it — i.e. what a value-less pop would produce.
const double _fallbackLat = 33.8886;
const double _fallbackLng = 35.4955;

Future<({
  GoRouter router,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
})> _buildRouter() async {
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
  group('B-35 — the map-pinned coordinate survives via the REAL AppRouter', () {
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
      'the coordinate popped by the production /capture-location builder '
      'reaches the create draft (not the value-less-pop fallback)',
      (tester) async {
        final built = await _buildRouter();
        built.router.go('/request-type');
        await tester.pumpWidget(
          _harness(
              built.router, built.role, built.roleEligibility, built.locale),
        );
        await tester.pumpAndSettle();

        // Tier → Continue → location-select.
        await tester.tap(find.bySemanticsIdentifier('request_type_continue_cta'));
        await tester.pumpAndSettle();

        // Open the map picker via the screen's OWN handler (the router no longer
        // overrides it) — this pushes the REAL `CaptureLocationRoute`.
        await tester.tap(
          find.bySemanticsIdentifier('location_select_new_location_cta'),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsIdentifier('capture_location_pin_cta'),
            findsOneWidget);

        // Confirm the pin — the production builder pops its controller's centre.
        await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
        await tester.pumpAndSettle();

        // Back on location-select: supply the G1 description, then confirm.
        await tester.enterText(
          find.byKey(const Key('clientLocation.descriptionField')),
          'A cake from Sea Sweet',
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('location_select_confirm_cta'),
        );
        await tester.pumpAndSettle();

        // The coordinate the REAL router popped reached the POST /requests draft
        // verbatim — the canonical default centre, NOT the Beirut value-less-pop
        // fallback. A regression to `context.pop()` (no value) would clear the
        // pin and collapse this to (_fallbackLat, _fallbackLng), failing here.
        final draft = submission.lastDraft;
        expect(draft, isNotNull);
        expect(draft!.pickupLat, _defaultCenterLat);
        expect(draft.pickupLng, _defaultCenterLng);
        expect(draft.dropoffLat, _defaultCenterLat);
        expect(draft.dropoffLng, _defaultCenterLng);
        expect(draft.pickupLat, isNot(_fallbackLat));
        expect(draft.pickupLng, isNot(_fallbackLng));
      },
    );
  });
}
