// QA-PRE scaffold for JEB-4 / T-MOB-FIX-004 (LEAD pin: Option B).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

Future<({
  GoRouter router,
  OnboardingCubit onboarding,
  BiometricLockCubit lock,
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
    onboarding: onboarding,
    lock: lock,
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
  // Shell renders on `/` before the test navigates to `/request-summary`, so
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>.value(value: role),
      BlocProvider<RoleEligibilityCubit>.value(value: roleEligibility),
      BlocProvider<LocaleCubit>.value(value: locale),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      // Use the sync test delegate — the production delegate's
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

const _draft = RequestDraft(
  description: 'JEB-4 happy-path draft',
  tierName: 'Express',
  pickupAddress: '12 Hamra St, Beirut',
  dropoffAddress: '88 Verdun Ave, Beirut',
);

void main() {
  group('GoRoute /request-summary (T-MOB-FIX-004 LEAD pin: Option B)', () {
    // The /request-summary builder resolves sl<RequestSubmissionService>() to
    setUp(() async {
      await sl.reset();
      sl.registerLazySingleton<RequestSubmissionService>(
        FakeRequestSubmissionService.new,
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets(
      'Test 1 — happy path: RequestDraft extra renders screen with '
      'draft fields and an enabled Submit button injected via BlocProvider',
      (tester) async {
        final built = await _buildRouter();
        // Navigate before mount so the shell at `/` (which depends on cubits
        built.router.go('/request-summary', extra: _draft);
        await tester.pumpWidget(_harness(built.router, built.role, built.roleEligibility, built.locale));
        await tester.pumpAndSettle();

        // Cubit is in the tree (BlocProvider wires it up at the route).
        final ctx = tester.element(find.byType(Scaffold).last);
        expect(
          () => BlocProvider.of<RequestSummaryCubit>(ctx),
          returnsNormally,
          reason: 'Route builder must wrap RequestSummaryScreen with a '
              'BlocProvider<RequestSummaryCubit> seeded with the draft.',
        );

        // Cubit emitted setDraft(_draft) → screen renders draft fields.
        expect(find.text('JEB-4 happy-path draft'), findsOneWidget);
        expect(find.text('Express'), findsOneWidget);
        expect(find.text('12 Hamra St, Beirut'), findsOneWidget);
        expect(find.text('88 Verdun Ave, Beirut'), findsOneWidget);

        // Submit button is present and enabled (not isSubmitting).
        final submit = find.widgetWithText(OmdsLoadingButton, 'Send request');
        expect(submit, findsOneWidget);
        final submitButton = tester.widget<OmdsLoadingButton>(submit);
        expect(submitButton.isLoading, isFalse);
        expect(submitButton.isEnabled, isTrue);

        // No OmdsLoadingState (the "draft == null" placeholder rendered by
        expect(find.byType(OmdsLoadingState), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Test 2 — cold deep-link with extra == null falls back gracefully '
      '(no CastError, no Submit button, recovery UI rendered)',
      (tester) async {
        final built = await _buildRouter();
        // Simulates the cold `jeeb://` deep-link case the existing
        built.router.go('/request-summary');
        await tester.pumpWidget(_harness(built.router, built.role, built.roleEligibility, built.locale));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Hitting /request-summary with a null extra must not '
              'throw — the route builder must defensively check the extra '
              'type before constructing RequestSummaryScreen.',
        );

        // Submit button should not be present in the fallback path — there
        expect(
          find.widgetWithText(OmdsLoadingButton, 'Send request'),
          findsNothing,
          reason: 'Fallback path must not render the populated summary '
              'screen with a Submit button.',
        );

        // Some recovery scaffold must render so the user is not stranded
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'Test 3 — wrong extra type (cast would fail) falls back gracefully '
      '(no _TypeError, no Submit button, recovery UI rendered)',
      (tester) async {
        final built = await _buildRouter();
        // The existing builder does `state.extra as RequestDraft` which
        built.router.go('/request-summary', extra: 'not-a-request-draft');
        await tester.pumpWidget(_harness(built.router, built.role, built.roleEligibility, built.locale));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'A wrong-type `extra` payload must not throw _TypeError. '
              'Route builder must check `extra is RequestDraft` first.',
        );

        expect(
          find.widgetWithText(OmdsLoadingButton, 'Send request'),
          findsNothing,
        );

        expect(find.byType(Scaffold), findsWidgets);
      },
    );
  });
}
