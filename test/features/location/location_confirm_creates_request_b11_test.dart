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

void main() {
  group('iter6 B11 — location-confirm CREATES the request (POST /requests)', () {
    late FakeRequestSubmissionService submission;

    setUp(() async {
      await sl.reset();
      submission = FakeRequestSubmissionService(
        requestId: 'real-server-id-9999',
      );
      sl.registerLazySingleton<RequestSubmissionService>(() => submission);
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
      sl.registerLazySingleton<LocationSelectRepository>(
        FakeLocationSelectRepository.new,
      );
      sl.registerLazySingleton<CurrentLocationResolver>(
        FakeCurrentLocationResolver.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
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

        await tester.tap(
          find.bySemanticsIdentifier('request_type_flash_radio'),
        );
        await tester.pump();
        final continueCta = find.bySemanticsIdentifier(
          'request_type_continue_cta',
        );
        expect(continueCta, findsOneWidget);
        await tester.ensureVisible(continueCta);
        await tester.tap(continueCta);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('clientLocation.descriptionField')),
          '2 shawarma + cola from Barbar',
        );
        await tester.pump();

        final confirm = find.bySemanticsIdentifier(
          'location_select_confirm_cta',
        );
        expect(confirm, findsOneWidget);
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(
          submission.submitCount,
          1,
          reason:
              'Confirm must call POST /requests (the B11 fix); the old '
              'flow never called it and broadcast requestId="new".',
        );
        expect(submission.lastDraft, isNotNull);

        expect(
          submission.lastDraft!.tierName,
          isNotNull,
          reason: 'the submitted draft must carry the chosen tier',
        );

        expect(
          submission.lastDraft!.description,
          '2 shawarma + cola from Barbar',
          reason:
              'the request description must be the customer\'s own words '
              '(G1 — "order whatever I want").',
        );
        expect(
          submission.lastDraft!.description.toLowerCase(),
          isNot(contains('delivery request')),
          reason:
              'the tier-derived placeholder description must never be '
              'sent when the customer typed content.',
        );

        final waitingScreen = tester.widget<NoOfferTimeoutScreen>(
          find.byType(NoOfferTimeoutScreen),
        );
        expect(
          waitingScreen.requestId,
          'real-server-id-9999',
          reason:
              'after create, the waiting screen must be routed with the '
              'server-minted request id (run-8 Step-2 gap fix).',
        );
        expect(
          waitingScreen.requestId,
          isNot('new'),
          reason:
              'the placeholder "new" hand-off (B11 root cause) must be '
              'gone.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
