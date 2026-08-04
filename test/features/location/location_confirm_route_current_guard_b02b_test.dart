// B-02b — the create-success navigation must be gated on route-CURRENTNESS,

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
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart'
    show shouldRouteAfterCreate;
import 'package:jeeb_mobile/features/location/presentation/widgets/client_location_add_row.dart';
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
  group('B-02b — create-success nav is gated on route-currentness', () {
    late _GatedSubmissionService submission;

    setUp(() async {
      // A tall viewport so the whole location-select body (including the
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
      // JEBV4-176: current-location resolves a REAL device fix (non-Beirut).
      sl.registerLazySingleton<CurrentLocationResolver>(
        FakeCurrentLocationResolver.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      // If the guard regressed and the waiting surface DID mount, a failing
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
      await tester.tap(find.bySemanticsIdentifier('request_type_flash_radio'));
      await tester.pump();
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
        final addRow = find.byType(ClientLocationAddRow);
        expect(addRow, findsOneWidget);
        final lock = find.ancestor(
          of: addRow,
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring == true,
          ),
        );
        expect(
          lock,
          findsOneWidget,
          reason: 'the add-location row must be locked while in flight',
        );

        // Tapping the add-location row while in flight must NOT push
        await tester.tap(addRow, warnIfMissed: false);
        await tester.pump();
        expect(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
          findsNothing,
        );
        // Still on the location-select step (its Confirm CTA is present).
        expect(
          find.bySemanticsIdentifier('location_select_confirm_cta'),
          findsOneWidget,
        );

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

        // Residual push path: the user opens the capture route while the POST is
        router.pushNamed('capture-location');
        // MIDNIGHT R11: the centre pin floats/breathes forever, so the capture
        // route never settles — advance it by hand.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
          findsOneWidget,
        );

        // Complete the create. The success nav is suppressed: we stay on the
        submission.release();
        await tester.pump();
        await tester.pump();

        expect(submission.submitCount, 1);
        expect(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
          findsOneWidget,
          reason:
              'the completed create must NOT goNamed the waiting surface '
              'from underneath the pushed capture-location route',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Direct, harness-free proof that the route-currentness RULE is load-bearing.
  group('B-02b — shouldRouteAfterCreate (route-currentness predicate)', () {
    test('navigates only when mounted AND the route is current', () {
      expect(
        shouldRouteAfterCreate(mounted: true, isRouteCurrent: true),
        isTrue,
      );
    });

    test(
      'does NOT navigate when mounted but the route is NOT current '
      '(overlay/dialog on top) — the isRouteCurrent term is load-bearing',
      () {
        expect(
          shouldRouteAfterCreate(mounted: true, isRouteCurrent: false),
          isFalse,
        );
      },
    );

    test('does NOT navigate when unmounted (backed out / page disposed)', () {
      expect(
        shouldRouteAfterCreate(mounted: false, isRouteCurrent: true),
        isFalse,
      );
      expect(
        shouldRouteAfterCreate(mounted: false, isRouteCurrent: false),
        isFalse,
      );
    });
  });
}
