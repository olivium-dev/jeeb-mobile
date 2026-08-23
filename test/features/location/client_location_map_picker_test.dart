// UX merge: the merged "New request" screen owns the map-picker edge. The
// point the customer pins on `/capture-location` must come back to the screen
// and be exactly what `POST /requests` carries — never the device GPS fix.

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
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

typedef _Built = ({
  GoRouter router,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
});

Future<_Built> _buildRouter() async {
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

  return (
    router: AppRouter.create(onboarding: onboarding, biometricLock: lock),
    role: RoleCubit(prefs: prefs),
    roleEligibility: RoleEligibilityCubit(),
    locale: LocaleCubit(prefs: prefs),
  );
}

Widget _harness(_Built built) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>.value(value: built.role),
      BlocProvider<RoleEligibilityCubit>.value(value: built.roleEligibility),
      BlocProvider<LocaleCubit>.value(value: built.locale),
    ],
    child: MaterialApp.router(
      routerConfig: built.router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
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

/// The capture screen's centre pin loops forever (MIDNIGHT R11 M0-4), so
/// `pumpAndSettle` never terminates while it is mounted — advance by hand.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_Built> _openNewRequest(WidgetTester tester) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final built = await _buildRouter();
  built.router.go('/client-location');
  await tester.pumpWidget(_harness(built));
  await tester.pumpAndSettle();
  expect(find.byType(ClientLocationScreen), findsOneWidget);
  return built;
}

void main() {
  late FakeRequestSubmissionService submission;

  group('merged screen "New Location" opens the map picker', () {
    setUp(() async {
      await sl.reset();
      submission = FakeRequestSubmissionService();
      sl.registerLazySingleton<CurrentLocationResolver>(
        FakeCurrentLocationResolver.new,
      );
      sl.registerLazySingleton<TierRepository>(FakeTierRepository.new);
      sl.registerLazySingleton<LocationSelectRepository>(
        FakeLocationSelectRepository.new,
      );
      sl.registerLazySingleton<RequestSubmissionService>(() => submission);
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(sl<RequestSubmissionService>()),
      );
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

    testWidgets('the picked point reaches POST /requests — Confirm must not '
        'silently swap it for the device GPS fix', (tester) async {
      final built = await _openNewRequest(tester);

      final addRow = find.bySemanticsIdentifier(
        'location_select_new_location_cta',
      );
      await tester.ensureVisible(addRow);
      await tester.tap(addRow);
      await _pumpFrames(tester);
      expect(find.byType(CaptureLocationScreen), findsOneWidget);

      // Deliberately NOT the FakeCurrentLocationResolver fix (33.8959/35.4797).
      built.router.pop(
        const LocationPoint(latitude: 34.4367, longitude: 35.8497),
      );
      await _pumpFrames(tester);
      expect(find.byType(ClientLocationScreen), findsOneWidget);

      final field = find.bySemanticsIdentifier('compose_description_input');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Two coffees from the corner shop');
      await tester.pumpAndSettle();

      final confirm = find.bySemanticsIdentifier('location_select_confirm_cta');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await _pumpFrames(tester);

      expect(submission.submitCount, 1);
      expect(
        submission.lastDraft?.pickupLat,
        34.4367,
        reason: 'The pinned pickup the customer saw must be what is POSTed.',
      );
      expect(submission.lastDraft?.pickupLng, 35.8497);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the picker creates nothing and returns intact',
        (tester) async {
      final built = await _openNewRequest(tester);

      await tester.tap(
        find.bySemanticsIdentifier('location_select_new_location_cta'),
        warnIfMissed: false,
      );
      await _pumpFrames(tester);
      expect(find.byType(CaptureLocationScreen), findsOneWidget);

      built.router.pop();
      await _pumpFrames(tester);

      expect(find.byType(ClientLocationScreen), findsOneWidget);
      expect(submission.submitCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
