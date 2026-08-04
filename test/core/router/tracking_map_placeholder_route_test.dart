// Maps-ON guard — the /orders/:id/tracking route now renders the LIVE

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
      // JeebEmptyState's E1 illustration loops ∞ by design (02-STUDY-NOTES
      // §Motion): pumpAndSettle only terminates under reduce motion.
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

void main() {
  late _Built built;

  setUp(() {
    // The tracking route builds a LiveTrackingCubit over sl<LiveTrackingRepository>.
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

  testWidgets('the /orders/:id/tracking builder wires useLiveMap == true '
      'and a live TrackingGoogleMap mounts — Maps-ON', (tester) async {
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
    expect(screen.useLiveMap, isTrue,
        reason: 'the route now opts into the live map (key provisioned, '
            'billing enabled)');
    // The live map platform view is actually in the tree on the route (the
    expect(find.byType(TrackingGoogleMap), findsOneWidget);
  });

  test('safety invariant: a true default useLiveMap REQUIRES '
      'com.google.android.geo.API_KEY in the AndroidManifest '
      '(a live map must never be keyless)', () {
    final defaultUseLiveMap =
        const LiveTrackingScreen(deliveryId: 'x').useLiveMap;

    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final manifestHasGeoKey =
        manifest.contains('com.google.android.geo.API_KEY');

    // The default is now ON.
    expect(defaultUseLiveMap, isTrue,
        reason: 'Maps is enabled — the tracking surface renders the live map');
    // A true default is only safe WITH the key present (invariant:
    expect(
      defaultUseLiveMap == false || manifestHasGeoKey,
      isTrue,
      reason: 'A live map with no geo API key is a native FATAL. With '
          'useLiveMap defaulting to true, the manifest MUST carry '
          'com.google.android.geo.API_KEY.',
    );
  });
}
