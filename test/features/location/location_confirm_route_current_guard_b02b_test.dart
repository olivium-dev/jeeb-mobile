// B-02b — the create-success navigation must be gated on route-CURRENTNESS,
// not merely on `mounted`.
//
// The Confirm CTA's `POST /requests` can outlive the location-select route. The
// original guard only disabled the Confirm CTA and only re-checked `mounted`
// before navigating — but a PUSH (capture-location / saved-addresses /
// dictation) leaves this footer MOUNTED yet no longer the top route. On
// completion the `mounted`-only gate still passed, so `goNamed('waiting…')`
// fired the waiting surface out from underneath the newly-pushed route (a rogue
// navigation).
//
// The fix has two halves, both proven here against the REAL production
// `AppRouter`:
//   1. the body's nav rows (add-location, saved-addresses) are LOCKED while a
//      create is in flight, so the user cannot push them mid-POST; and
//   2. the success nav additionally requires `ModalRoute.isCurrent`, so any
//      residual push path (dictation mic, deep link, back-then-forward) cannot
//      let the create yank the user to the waiting surface.

import 'dart:async';

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
import 'package:jeeb_mobile/features/location/presentation/widgets/client_location_add_row.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A submission service whose [submit] blocks on a gate the test releases, so
/// the create can be held in flight while the user navigates away.
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
  group('B-02b — create-success nav is gated on route-currentness', () {
    late _GatedSubmissionService submission;

    setUp(() async {
      // A tall viewport so the whole location-select body (including the
      // below-the-fold add-location row) is laid out without scrolling — the
      // lazy ListView otherwise builds no element for off-screen rows.
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final view = binding.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 3200);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await sl.reset();
      submission = _GatedSubmissionService();
      sl.registerLazySingleton<RequestSubmissionService>(() => submission);
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
      sl.registerLazySingleton<LocationSelectRepository>(
        FakeLocationSelectRepository.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // If the guard regressed and the waiting surface DID mount, a failing
      // waiting repo keeps it timer-free (so the assertion, not a leaked timer,
      // is what fails).
      sl.registerLazySingleton<WaitingRepository>(
        () => FakeWaitingRepository(
          failure: const WaitingException(WaitingFailure.network),
        ),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    Future<GoRouter> pumpToInFlight(WidgetTester tester) async {
      final built = await _buildRouter();
      built.router.go('/request-type');
      await tester.pumpWidget(
        _harness(built.router, built.role, built.roleEligibility, built.locale),
      );
      await tester.pumpAndSettle();

      // Tier → Continue → location-select.
      await tester.tap(find.bySemanticsIdentifier('request_type_continue_cta'));
      await tester.pumpAndSettle();

      // G1: the request content is required before Confirm enables.
      await tester.enterText(
        find.byKey(const Key('clientLocation.descriptionField')),
        'A cake from Sea Sweet',
      );
      await tester.pump();

      final confirm = find.bySemanticsIdentifier('location_select_confirm_cta');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump(); // fire the create; it now blocks on the gate.
      expect(submission.submitCount, 1);
      return built.router;
    }

    testWidgets(
      'the nav rows are LOCKED while the create is in flight (no push)',
      (tester) async {
        await pumpToInFlight(tester);

        // The add-location row is now wrapped by a locking IgnorePointer
        // (`_SubmitLock`). Found by widget type — IgnorePointer strips the
        // subtree's semantics while active, so a semantics-id finder can't see
        // the row, which is itself proof it is locked out.
        final addRow = find.byType(ClientLocationAddRow);
        expect(addRow, findsOneWidget);
        final lock = find.ancestor(
          of: addRow,
          matching: find.byWidgetPredicate(
              (w) => w is IgnorePointer && w.ignoring == true),
        );
        expect(lock, findsOneWidget,
            reason: 'the add-location row must be locked while in flight');

        // Tapping the add-location row while in flight must NOT push
        // capture-location — the lock swallows the tap.
        await tester.tap(addRow, warnIfMissed: false);
        await tester.pump();
        expect(find.bySemanticsIdentifier('capture_location_pin_cta'),
            findsNothing);
        // Still on the location-select step (its Confirm CTA is present).
        expect(find.bySemanticsIdentifier('location_select_confirm_cta'),
            findsOneWidget);

        // Cleanly finish the in-flight create so no pending timer/future leaks.
        submission.release();
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a create that completes AFTER the user pushed another route does NOT '
      'navigate the waiting surface from underneath it',
      (tester) async {
        final router = await pumpToInFlight(tester);

        // Simulate a residual push path (dictation mic / deep link / back-then-
        // forward): the user leaves location-select while the POST is in flight.
        // The footer stays MOUNTED (covered), so only a route-currentness gate —
        // not `mounted` — can suppress the rogue success nav.
        router.pushNamed('capture-location');
        await tester.pumpAndSettle();
        expect(find.bySemanticsIdentifier('capture_location_pin_cta'),
            findsOneWidget);

        // Complete the create. With the route-currentness guard, the success
        // nav is suppressed: we stay on the pushed capture route (its Pin CTA is
        // still shown). A regression to a `mounted`-only gate would `goNamed`
        // the waiting surface, REPLACING the stack and unmounting this screen —
        // so the Pin CTA would vanish and this assertion would fail.
        submission.release();
        await tester.pump();
        await tester.pump();

        expect(submission.submitCount, 1);
        expect(find.bySemanticsIdentifier('capture_location_pin_cta'),
            findsOneWidget,
            reason: 'the completed create must NOT goNamed the waiting surface '
                'from underneath the pushed capture-location route');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
