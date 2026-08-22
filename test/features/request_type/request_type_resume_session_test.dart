// The voice door seeds a compose session THEN lands on "Choose your request"
// like every other create door. `?resume=1` is what stops Continue's `setTier`
// from blanking the dictated description, transcript and clip.

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
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

const _flash = Tier(
  id: TierId.flash,
  serverId: 'tier-flash',
  priceLow: 200000,
  priceHigh: 300000,
  currency: 'LBP',
  vehicleClass: TierVehicleClass.bikeOrScooter,
);

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
  return (
    router: AppRouter.create(onboarding: onboarding, biometricLock: lock),
    role: RoleCubit(prefs: prefs),
    roleEligibility: RoleEligibilityCubit(),
    locale: LocaleCubit(prefs: prefs),
  );
}

Widget _harness(
  ({
    GoRouter router,
    RoleCubit role,
    RoleEligibilityCubit roleEligibility,
    LocaleCubit locale,
  })
  built,
) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>.value(value: built.role),
      BlocProvider<RoleEligibilityCubit>.value(value: built.roleEligibility),
      BlocProvider<LocaleCubit>.value(value: built.locale),
    ],
    child: MaterialApp.router(
      routerConfig: built.router,
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

Future<void> _continueFrom(WidgetTester tester, String location) async {
  final built = await _buildRouter();
  built.router.go(location);
  await tester.pumpWidget(_harness(built));
  await tester.pumpAndSettle();
  expect(find.byType(RequestTypeScreen), findsOneWidget);

  await tester.tap(find.bySemanticsIdentifier('request_type_standard_radio'));
  await tester.pump();
  final cta = find.bySemanticsIdentifier('request_type_continue_cta');
  await tester.ensureVisible(cta);
  await tester.tap(cta);
  await tester.pumpAndSettle();
  expect(find.byType(ClientLocationScreen), findsOneWidget);
}

void main() {
  late ComposeRequestController compose;
  late FakeRequestSubmissionService submission;

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
    compose = sl<ComposeRequestController>();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('resume=1 re-prices a seeded voice session without wiping it',
      (tester) async {
    compose.beginVoiceSession(
      tier: _flash,
      description: 'two kilos of apples',
      transcription: 'two kilos of apples',
      audioUrl: 'clip-1',
    );

    await _continueFrom(tester, '/request-type?resume=1');

    expect(compose.tier?.id, TierId.standard, reason: 'the re-pick lands');
    expect(compose.description, 'two kilos of apples');

    // The clip and transcript have no getters — prove them where they matter.
    final confirm = find.bySemanticsIdentifier('location_select_confirm_cta');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    // The waiting surface animates forever, so advance by hand, not to settle.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(submission.submitCount, 1);
    expect(submission.lastDraft?.description, 'two kilos of apples');
    expect(submission.lastDraft?.transcription, 'two kilos of apples');
    expect(submission.lastDraft?.audioUrl, 'clip-1');
    expect(submission.lastDraft?.tierName, TierId.standard.name);
  });

  testWidgets('a cold entry still starts a FRESH session', (tester) async {
    compose.beginVoiceSession(
      tier: _flash,
      description: 'stale text from a previous compose',
      transcription: 'stale text from a previous compose',
      audioUrl: 'clip-0',
    );

    await _continueFrom(tester, '/request-type');

    expect(compose.tier?.id, TierId.standard);
    expect(
      compose.description,
      isNull,
      reason: 'a cold create must never inherit the previous session',
    );
    expect(find.text('stale text from a previous compose'), findsNothing);
  });
}
