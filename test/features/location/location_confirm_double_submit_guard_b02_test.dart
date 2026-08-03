import 'dart:async';

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
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/sync_app_localizations.dart';

class _GatedSubmissionService implements RequestSubmissionService {
  final Completer<void> _gate = Completer<void>();
  int submitCount = 0;
  RequestDraft? lastDraft;

  void release() => _gate.complete();

  @override
  Future<String> submit(RequestDraft draft) async {
    submitCount++;
    lastDraft = draft;
    await _gate.future;
    return 'real-server-id-9999';
  }
}

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
  group('FIX-B02 — Confirm CTA guards against double-submit', () {
    late _GatedSubmissionService submission;

    setUp(() async {
      await sl.reset();
      submission = _GatedSubmissionService();
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
      'a second tap while the create is in flight does NOT submit twice',
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

        // G1: the request content is required before Confirm enables.
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

        // First tap: fires the create; it now blocks on the gate (in flight).
        await tester.tap(confirm);
        await tester.pump();
        expect(
          submission.submitCount,
          1,
          reason: 'first tap must fire POST /requests exactly once',
        );

        // The CTA reports its loading state (disabled + spinner) while in
        final button = tester.widget<OmdsLoadingButton>(
          find.byType(OmdsLoadingButton),
        );
        expect(
          button.isLoading,
          isTrue,
          reason: 'the Confirm CTA must show its loading state in flight',
        );

        // Second tap while in flight must be a no-op (the guard).
        await tester.tap(confirm, warnIfMissed: false);
        await tester.pump();
        expect(
          submission.submitCount,
          1,
          reason:
              'the in-flight guard must swallow the second tap — a double '
              'tap must never create the request twice',
        );

        // Release the gate so the create completes and nav proceeds. Use
        submission.release();
        await tester.pump();
        await tester.pump();
        expect(submission.submitCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
