// QA-PRE scaffold for JEB-4 / T-MOB-FIX-004 (LEAD pin: Option B).
//
// These tests intentionally import `app_router.dart`, which currently fails to
// compile (3 undefined_named_parameter errors at app_router.dart:244-246). The
// test target therefore won't build until JEB-239 (ENG) rewrites the
// `/request-summary` GoRoute builder to wrap `RequestSummaryScreen` in a
// `BlocProvider<RequestSummaryCubit>` and defensively guards `state.extra`.
// Once the route handler is fixed, these tests run and pin behaviour:
//   1. Happy path  — extra is a RequestDraft, screen renders, Submit enabled.
//   2. Cold deep-link with extra == null — graceful fallback, no crash.
//   3. Wrong extra type — graceful fallback, no _TypeError.
//
// AC3 (cold `jeeb://` deep-link scheme registration) is out of scope per LEAD
// pin and routes to T-MOB-DEEPLINK-001.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';

Future<({GoRouter router, OnboardingCubit onboarding, BiometricLockCubit lock})>
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

  final router = AppRouter.create(onboarding: onboarding, biometricLock: lock);
  return (router: router, onboarding: onboarding, lock: lock);
}

Widget _harness(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
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
    testWidgets(
      'Test 1 — happy path: RequestDraft extra renders screen with '
      'draft fields and an enabled Submit button injected via BlocProvider',
      (tester) async {
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built.router));
        await tester.pumpAndSettle();

        built.router.go('/request-summary', extra: _draft);
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
        final submit = find.widgetWithText(FilledButton, 'Submit Request');
        expect(submit, findsOneWidget);
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

        // No CircularProgressIndicator (the "draft == null" placeholder).
        expect(find.byType(CircularProgressIndicator), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Test 2 — cold deep-link with extra == null falls back gracefully '
      '(no CastError, no Submit button, recovery UI rendered)',
      (tester) async {
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built.router));
        await tester.pumpAndSettle();

        // Simulates the cold `jeeb://` deep-link case the existing
        // `state.extra as RequestDraft` cast would crash on.
        built.router.go('/request-summary');
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Hitting /request-summary with a null extra must not '
              'throw — the route builder must defensively check the extra '
              'type before constructing RequestSummaryScreen.',
        );

        // Submit button should not be present in the fallback path — there
        // is no draft to submit.
        expect(
          find.widgetWithText(FilledButton, 'Submit Request'),
          findsNothing,
          reason: 'Fallback path must not render the populated summary '
              'screen with a Submit button.',
        );

        // Some recovery scaffold must render so the user is not stranded
        // on a blank screen.
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'Test 3 — wrong extra type (cast would fail) falls back gracefully '
      '(no _TypeError, no Submit button, recovery UI rendered)',
      (tester) async {
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built.router));
        await tester.pumpAndSettle();

        // The existing builder does `state.extra as RequestDraft` which
        // throws `_TypeError` when extra is anything else. After fix the
        // builder must `is RequestDraft`-guard before downcasting.
        built.router.go('/request-summary', extra: 'not-a-request-draft');
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'A wrong-type `extra` payload must not throw _TypeError. '
              'Route builder must check `extra is RequestDraft` first.',
        );

        expect(
          find.widgetWithText(FilledButton, 'Submit Request'),
          findsNothing,
        );

        expect(find.byType(Scaffold), findsWidgets);
      },
    );
  });
}
