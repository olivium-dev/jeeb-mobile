// sprint-009 P0 (stop-the-bleed) — the /orders/:id/tracking route must render
// the map PLACEHOLDER, never a live GoogleMap, until sprint-013 provisions the
// Maps key.
//
// Root cause (QA-diagnosed): `android/app/src/main/AndroidManifest.xml` carries
// NO `com.google.android.geo.API_KEY`, so mounting a live GoogleMap makes the
// native Maps SDK throw an UNCAUGHT IllegalStateException off the platform
// thread → SIGKILL. Three inbound CTAs (home "Track my order", delivery-detail
// "Live tracking", chat offer-accepted banner) all converge on this one route
// builder, so pinning it here guards all three.
//
// Two pins:
//   (a) the /orders/:id/tracking builder constructs LiveTrackingScreen with
//       useLiveMap == false (and no live TrackingGoogleMap mounts).
//   (b) a manifest gate: useLiveMap default == false OR the manifest contains
//       the geo API key — so when sprint-013 flips the default back to true,
//       this test DEMANDS the key be present first.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/live_tracking/data/demo_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

typedef _Built = ({
  GoRouter router,
  OnboardingCubit onboarding,
  BiometricLockCubit lock,
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
  final role = RoleCubit(prefs: prefs);
  final roleEligibility = RoleEligibilityCubit();
  final locale = LocaleCubit(prefs: prefs);

  final router = AppRouter.create(
    onboarding: onboarding,
    biometricLock: lock,
    session: const AlwaysAuthenticatedSessionGate(),
  );
  return (
    router: router,
    onboarding: onboarding,
    lock: lock,
    role: role,
    roleEligibility: roleEligibility,
    locale: locale,
  );
}

Widget _harness(_Built built) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<BiometricLockCubit>.value(value: built.lock),
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

void main() {
  late _Built built;

  setUp(() {
    // The tracking route builds a LiveTrackingCubit over sl<LiveTrackingRepository>.
    // Register the const demo repo so the route mounts under test.
    if (!sl.isRegistered<LiveTrackingRepository>()) {
      sl.registerLazySingleton<LiveTrackingRepository>(
        () => const DemoLiveTrackingRepository(),
      );
    }
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<void> pump(WidgetTester tester) async {
    built = await _buildRouter();
    addTearDown(() {
      built.lock.close();
      built.role.close();
      built.roleEligibility.close();
      built.locale.close();
      built.onboarding.close();
      built.router.dispose();
    });
    await tester.pumpWidget(_harness(built));
    await tester.pumpAndSettle();
  }

  testWidgets('the /orders/:id/tracking builder pins useLiveMap == false '
      '(no live GoogleMap mounts) — P0 keyless-map crash guard', (tester) async {
    await pump(tester);
    built.router.goNamed('live-tracking', pathParameters: {'id': 'd-1'});
    await tester.pumpAndSettle();

    expect(
      built.router.routerDelegate.currentConfiguration.uri.toString(),
      '/orders/d-1/tracking',
    );

    final screen = tester.widget<LiveTrackingScreen>(
      find.byType(LiveTrackingScreen),
    );
    expect(screen.useLiveMap, isFalse,
        reason: 'the route must not mount a keyless live map (native SIGKILL)');
    // Belt-and-suspenders: no live map platform view is in the tree.
    expect(find.byType(TrackingGoogleMap), findsNothing);
  });

  test('manifest gate: LiveTrackingScreen default useLiveMap == false OR the '
      'AndroidManifest contains com.google.android.geo.API_KEY '
      '(sprint-013 must add the key before flipping the default back)', () {
    final defaultUseLiveMap =
        const LiveTrackingScreen(deliveryId: 'x').useLiveMap;

    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final manifestHasGeoKey =
        manifest.contains('com.google.android.geo.API_KEY');

    expect(
      defaultUseLiveMap == false || manifestHasGeoKey,
      isTrue,
      reason: 'A live map with no geo API key is a native FATAL. Either keep '
          'useLiveMap defaulting to false, or provision the key in the '
          'manifest (sprint-013) before defaulting it back to true.',
    );
  });
}
