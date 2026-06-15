// FIX-B — the request-type "Continue" CTA must navigate (E2E gap).
//
// Before this fix the sticky `request_type_continue` button was a dead end:
// the router wired `onTierSelected` (so tapping a TIER CARD navigated to
// `/request-summary`) but never wired `onContinue`, so pressing Continue
// invoked a null callback and nothing happened.
//
// These tests drive the REAL `AppRouter.create(...)` graph (same harness as
// request_summary_route_test.dart) to `/request-type`, then tap the Continue
// CTA — proving it lands on the same destination the tier-card tap uses
// (`/request-summary`) and carries the currently-selected tier.
//
// FAIL-WITHOUT: with `onContinue` unwired in the router the CTA is a no-op, so
// the post-tap assertions (RequestSummaryScreen rendered with the selected
// tier name) fail — these tests are red without the FIX-B router change.

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
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
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

  // Default session gate is AlwaysAuthenticatedSessionGate, so the FR-P0-3
  // login redirect is inert and protected routes (`/request-type`) render.
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
  group('FIX-B — /request-type Continue CTA navigates with the selected tier',
      () {
    setUp(() async {
      await sl.reset();
      // `/request-type` builder resolves TierRepository via sl (falling back to
      // FakeTierRepository if absent); register it explicitly for determinism.
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // `/request-summary` builder resolves sl<RequestSubmissionService>() to
      // construct its cubit — register a fake so the destination route builds.
      sl.registerLazySingleton<RequestSubmissionService>(
        FakeRequestSubmissionService.new,
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets(
      'tapping Continue (default-selected Flash tier) lands on '
      'RequestSummaryScreen carrying that tier',
      (tester) async {
        final built = await _buildRouter();
        // Land directly on the request-type route so the shell at `/` (whose
        // tabs depend on cubits outside this test) never renders.
        built.router.go('/request-type');
        await tester.pumpWidget(
          _harness(built.router, built.role, built.roleEligibility, built.locale),
        );
        await tester.pumpAndSettle();

        // The request-type screen is up and its Continue CTA is enabled because
        // the cubit pre-selects the recommended (Flash) tier on load.
        expect(find.byType(RequestTypeScreen), findsOneWidget);
        final continueCta = find.byKey(const Key('request-type-continue'));
        expect(continueCta, findsOneWidget);
        await tester.ensureVisible(continueCta);

        // FAIL-WITHOUT: with onContinue unwired this tap is a no-op and the
        // RequestSummaryScreen below never renders.
        await tester.tap(continueCta);
        await tester.pumpAndSettle();

        expect(
          find.byType(RequestSummaryScreen),
          findsOneWidget,
          reason: 'Continue must navigate to /request-summary (the same '
              'destination the tier-card tap uses).',
        );
        // The screen-built draft carries the localized tier title (plain
        // "Flash" — the emoji glyph is now a separate OMDS vector icon, not
        // baked into the data), proving Continue forwards the CURRENTLY
        // SELECTED tier, not an empty / default draft.
        expect(
          find.text('Flash'),
          findsOneWidget,
          reason: 'The summary must show the selected tier name forwarded by '
              'the Continue CTA.',
        );
        // Destination cubit is wired (BlocProvider at the summary route).
        final ctx = tester.element(find.byType(RequestSummaryScreen));
        expect(
          () => BlocProvider.of<RequestSummaryCubit>(ctx),
          returnsNormally,
        );
        expect(tester.takeException(), isNull);
      },
    );

    // Screen-level proof (no router) that the Continue CTA forwards the
    // CURRENTLY-SELECTED tier in the RequestDraft — not the default. Driving a
    // pre-loaded cubit with Eco selected isolates the Continue→draft contract
    // from the tier-card tap navigation. The router-level navigation itself is
    // already pinned by the test above.
    testWidgets(
      'Continue forwards a RequestDraft seeded with the selected (Eco) tier',
      (tester) async {
        final cubit = TierSelectionCubit(repository: const FakeTierRepository());
        addTearDown(cubit.close);
        await cubit.load(); // pre-selects recommended Flash
        cubit.selectTier(TierId.eco); // user changes selection to Eco
        expect(cubit.state.selectedTierId, TierId.eco);

        RequestDraft? forwarded;
        await tester.pumpWidget(
          _screenHost(
            RequestTypeScreen(
              cubit: cubit,
              onContinue: (draft) => forwarded = draft,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final continueCta = find.byKey(const Key('request-type-continue'));
        await tester.ensureVisible(continueCta);
        // FAIL-WITHOUT is covered by the router test; here we pin the draft
        // contract the router forwards: Continue must hand back the Eco tier.
        await tester.tap(continueCta);
        await tester.pump();

        expect(forwarded, isNotNull);
        expect(
          forwarded!.tierId,
          TierId.eco.name,
          reason: 'Continue must carry the latest selected tier (Eco).',
        );
        expect(
          forwarded!.tierName,
          'Eco',
          reason: 'The draft carries the localized tier title, not the enum '
              'name — proving the screen-built draft, not a stub.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// Minimal Localizations host for the screen-level test (no router / shell).
Widget _screenHost(Widget child) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
