// iter6 B11 — the create gating fix.
//
// REGRESSION LOCK for the on-device defect: the create flow used to hand off
// the literal placeholder id `'new'` from `location-select` to `order-chat`,
// which then broadcast `requestId='new'` WITHOUT ever calling `POST /requests`
// → no request was ever created on-device (matching 422 / chat 404). This test
// drives the REAL `AppRouter.create(...)` graph to `/client-location`, taps the
// Confirm CTA, and proves:
//   1. the location-confirm step CALLS RequestSubmissionService.submit()
//      (i.e. POST /requests is invoked — submitCount == 1), and
//   2. it routes order-chat with the REAL server-minted id, NEVER `'new'`.

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
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

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
  group('iter6 B11 — location-confirm CREATES the request (POST /requests)', () {
    late FakeRequestSubmissionService submission;

    setUp(() async {
      await sl.reset();
      submission =
          FakeRequestSubmissionService(requestId: 'real-server-id-9999');
      sl.registerLazySingleton<RequestSubmissionService>(() => submission);
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
      sl.registerLazySingleton<LocationSelectRepository>(
        FakeLocationSelectRepository.new,
      );
      // The request-type step resolves TierRepository via sl and pre-selects
      // Flash, so the Continue CTA is enabled on first paint.
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // Post-create nav fix: Confirm now routes to the WAITING screen
      // (`waiting-no-coverage` → NoOfferTimeoutScreen). Its self-provided
      // ticker WaitingCubit attaches `Stream.periodic` poll/clock timers on a
      // SUCCESSFUL load, which would leak into the headless binding. Register a
      // WaitingRepository whose cold-load read FAILS so the screen mounts in its
      // (timer-free) error state — enough to assert the navigation target
      // without leaking timers. The waiting screen's own happy-path copy is
      // covered by waiting_screen_test.dart.
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
      'full flow tier→location→Confirm calls submit() once and routes to the '
      'WAITING screen with the REAL request id (never the placeholder "new")',
      (tester) async {
        final built = await _buildRouter();
        // Drive the REAL on-device path: request-type → Continue → location.
        built.router.go('/request-type');
        await tester.pumpWidget(
          _harness(built.router, built.role, built.roleEligibility,
              built.locale),
        );
        await tester.pumpAndSettle();

        // Step 1: pick a tier (Flash pre-selected) + Continue → location-select.
        final continueCta =
            find.bySemanticsIdentifier('request_type_continue_cta');
        expect(continueCta, findsOneWidget);
        await tester.ensureVisible(continueCta);
        await tester.tap(continueCta);
        await tester.pumpAndSettle();

        // Step 2 (G1): type the request CONTENT — required before Confirm
        // enables. This is the customer's own words, the exact string the
        // jeeber feed/detail must render.
        await tester.enterText(
          find.byKey(const Key('clientLocation.descriptionField')),
          '2 shawarma + cola from Barbar',
        );
        await tester.pump();

        // Step 3: confirm the location → must CREATE the request (B11 fix).
        final confirm =
            find.bySemanticsIdentifier('location_select_confirm_cta');
        expect(confirm, findsOneWidget);
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        // (1) POST /requests was actually called — exactly once.
        expect(
          submission.submitCount,
          1,
          reason: 'Confirm must call POST /requests (the B11 fix); the old '
              'flow never called it and broadcast requestId="new".',
        );
        expect(submission.lastDraft, isNotNull);

        // (2) The draft submitted carried the create payload (so a real
        //     `POST /requests` body was assembled — not a `'new'` broadcast).
        expect(submission.lastDraft!.tierName, isNotNull,
            reason: 'the submitted draft must carry the chosen tier');

        // (2b) G1 payload lock: the POST body description IS the user's text —
        // verbatim — and the old hardcoded '"{Tier} delivery request"'
        // placeholder is gone for good.
        expect(
          submission.lastDraft!.description,
          '2 shawarma + cola from Barbar',
          reason: 'the request description must be the customer\'s own words '
              '(G1 — "order whatever I want").',
        );
        expect(
          submission.lastDraft!.description.toLowerCase(),
          isNot(contains('delivery request')),
          reason: 'the tier-derived placeholder description must never be '
              'sent when the customer typed content.',
        );

        // (3) POST-CREATE UX FIX (run-8 Step-2): the customer now lands on the
        //     "Finding a Jeeber" WAITING screen (NoOfferTimeoutScreen) for the
        //     freshly-created request — NOT the order-chat compose screen. It is
        //     bound to the REAL server-minted id, NEVER the literal "new".
        final waitingScreen = tester
            .widget<NoOfferTimeoutScreen>(find.byType(NoOfferTimeoutScreen));
        expect(
          waitingScreen.requestId,
          'real-server-id-9999',
          reason: 'after create, the waiting screen must be routed with the '
              'server-minted request id (run-8 Step-2 gap fix).',
        );
        expect(
          waitingScreen.requestId,
          isNot('new'),
          reason: 'the placeholder "new" hand-off (B11 root cause) must be '
              'gone.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
