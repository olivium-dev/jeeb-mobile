// sprint-8f — Confirm CTA must NOT hard-depend on saved-locations.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
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
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
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
      // MIDNIGHT M3-03: this flow lands on the waiting screen, whose E2 radar
      // loops ∞ by design — pumpAndSettle only terminates under reduce motion.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

/// The OmdsLoadingButton inside the `location_select_confirm_cta` Semantics.
/// B-02 swapped OmdsPrimaryButton → OmdsLoadingButton (disable + spinner while
OmdsLoadingButton _confirmButton(WidgetTester tester) {
  final cta = find.bySemanticsIdentifier('location_select_confirm_cta');
  expect(
    cta,
    findsOneWidget,
    reason: 'the Confirm CTA must be rendered (footer not hidden)',
  );
  return tester.widget<OmdsLoadingButton>(
    find.descendant(of: cta, matching: find.byType(OmdsLoadingButton)),
  );
}

/// Drives request-type → Continue → location-select, then returns once the
/// Confirm CTA is on screen.
Future<void> _driveToLocationSelect(WidgetTester tester) async {
  final built = await _buildRouter();
  built.router.go('/request-type');
  await tester.pumpWidget(
    _harness(built.router, built.role, built.roleEligibility, built.locale),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsIdentifier('request_type_flash_radio'));
  await tester.pump();
  final continueCta = find.bySemanticsIdentifier('request_type_continue_cta');
  expect(continueCta, findsOneWidget);
  await tester.ensureVisible(continueCta);
  await tester.tap(continueCta);
  // MIDNIGHT M0-4: the saved-addresses error band is a `JeebEmptyState` whose
  // illustration loops forever — advance the transition by hand.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// G1: the Confirm CTA is additionally gated on a non-empty "What do you
/// need?" description — type one so the saved-locations behaviour under test
Future<void> _describeRequest(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('clientLocation.descriptionField')),
    '2 shawarma + cola from Barbar',
  );
  await tester.pump();
}

void main() {
  group('sprint-8f — Confirm CTA enabled + submit fires when saved-locations is '
      'unavailable', () {
    late FakeRequestSubmissionService submission;

    void registerCommon(LocationSelectRepository repo) {
      submission = FakeRequestSubmissionService(requestId: 'real-server-id-8f');
      sl.registerLazySingleton<RequestSubmissionService>(() => submission);
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
      sl.registerLazySingleton<LocationSelectRepository>(() => repo);
      // JEBV4-176: the current-location option resolves a REAL device fix — the
      sl.registerLazySingleton<CurrentLocationResolver>(
        FakeCurrentLocationResolver.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // Confirm now routes to the WAITING screen (waiting-no-coverage). Register
      sl.registerLazySingleton<WaitingRepository>(
        () => FakeWaitingRepository(
          failure: const WaitingException(WaitingFailure.network),
        ),
      );
    }

    setUp(() async {
      await sl.reset();
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets(
      'saved-locations ERRORED (404/network): Confirm is ENABLED and tapping '
      'it fires POST /requests',
      (tester) async {
        // Saved-locations fetch fails — exactly the live 404 condition.
        registerCommon(
          const FakeLocationSelectRepository(
            failWith: LocationSelectFailure.network,
          ),
        );

        await _driveToLocationSelect(tester);

        // The saved-locations error banner is shown — proving the fetch
        // failed. MIDNIGHT: the band is a `JeebEmptyState`, so the assertion is
        // re-homed onto its frozen identifier rather than the widget type.
        // Scrolled to: the seeded tier is disclosed above it now.
        final Finder savedError = find.bySemanticsIdentifier(
          'location_select_saved_addresses_error',
        );
        await tester.scrollUntilVisible(
          savedError,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          savedError,
          findsOneWidget,
          reason: 'the saved-locations fetch must have failed in this case',
        );

        await _describeRequest(tester);

        // The CTA is ENABLED despite the failed fetch (the defect was it staying
        expect(
          _confirmButton(tester).isEnabled,
          isTrue,
          reason:
              'Confirm must enable on the picked pickup+dropoff (Current '
              'Location default), NOT on the saved-locations load succeeding',
        );

        // Tapping it actually CREATES the request (proves it is interactive,
        await tester.tap(
          find.bySemanticsIdentifier('location_select_confirm_cta'),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          submission.submitCount,
          1,
          reason:
              'Confirm must call POST /requests even when saved-locations '
              '404d',
        );
        expect(submission.lastDraft, isNotNull);
        // Single confirmed point seeds both pickup + dropoff coordinates.
        expect(submission.lastDraft!.pickupLat, isNotNull);
        expect(submission.lastDraft!.dropoffLat, isNotNull);

        final waiting = tester.widget<NoOfferTimeoutScreen>(
          find.byType(NoOfferTimeoutScreen),
        );
        expect(waiting.requestId, 'real-server-id-8f');
        expect(waiting.requestId, isNot('new'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'saved-locations EMPTY: Confirm is ENABLED and tapping it fires '
      'POST /requests',
      (tester) async {
        // Saved-locations loads successfully but returns NO addresses.
        registerCommon(const FakeLocationSelectRepository(addresses: []));

        await _driveToLocationSelect(tester);

        // No error banner (load succeeded) and no saved-address cards.
        expect(
          find.bySemanticsIdentifier('location_select_saved_addresses_error'),
          findsNothing,
        );

        // G1 validation lock: with the description still empty the CTA stays
        expect(
          _confirmButton(tester).isEnabled,
          isFalse,
          reason: 'an empty "What do you need?" must block Confirm (G1)',
        );

        await _describeRequest(tester);

        expect(
          _confirmButton(tester).isEnabled,
          isTrue,
          reason: 'an empty saved-locations list must not block Confirm',
        );

        await tester.tap(
          find.bySemanticsIdentifier('location_select_confirm_cta'),
        );
        await tester.pumpAndSettle();

        expect(submission.submitCount, 1);
        final waiting = tester.widget<NoOfferTimeoutScreen>(
          find.byType(NoOfferTimeoutScreen),
        );
        expect(waiting.requestId, 'real-server-id-8f');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
