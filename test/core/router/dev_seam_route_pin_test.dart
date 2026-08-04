// Regression guard for the dev-seam route-pin defect (screens 10 & 13).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/chat/presentation/dev_chat_preview_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
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

Widget _harness(_Built built) {
  return MultiBlocProvider(
    providers: [
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
  // Guard: the seam getters are only live in debug; these tests assume it.
  assert(kDebugMode, 'dev-seam route-pin tests must run in debug');

  setUp(() {
    // JEBV4-176: the /client-location screen resolves a device-GPS fix; provide
    sl.registerLazySingleton<CurrentLocationResolver>(
      FakeCurrentLocationResolver.new,
    );
  });

  tearDown(() async {
    DevSeam.debugReset();
    await sl.reset();
  });

  // We assert on the MOUNTED screen widget rather than

  group('dev-seam route pin (screens 10 & 13)', () {
    testWidgets(
      '(a) initial launch with a dev route pinned LANDS on that route',
      (tester) async {
        // Pin /client-location (the screen-10 capture target).
        DevSeam.debugOverride(
          const DevSeamConfig(route: '/client-location'),
        );
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(
          find.byType(ClientLocationScreen),
          findsOneWidget,
          reason: 'The pinned dev route must drive the initial landing.',
        );
        expect(find.byType(ShellScreen), findsNothing);
      },
    );

    testWidgets(
      '(b) after landing, a user-initiated push to a DIFFERENT route STICKS '
      '(screen 10: /client-location → /capture-location)',
      (tester) async {
        DevSeam.debugOverride(
          const DevSeamConfig(route: '/client-location'),
        );
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        // Sanity: we landed on the pinned route.
        expect(find.byType(ClientLocationScreen), findsOneWidget);

        // User taps "New Location" → pushes the capture screen. Pre-fix this
        built.router.push('/capture-location');
        // MIDNIGHT R11: the capture screen's centre pin loops forever (M0-4),
        // so it never settles — advance it by hand.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          find.byType(CaptureLocationScreen),
          findsOneWidget,
          reason: 'A user-pushed route after the initial dev-seam landing must '
              'stick — the pin is initial-landing-only.',
        );
      },
    );

    testWidgets(
      '(b2) screen 13: from a `/` pin, pushing /chat/:id sticks',
      (tester) async {
        // Screen 13 pins the shell home (root) then taps a pending item which
        DevSeam.debugOverride(const DevSeamConfig(route: '/'));
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(ShellScreen), findsOneWidget);

        built.router.push('/chat/conv-rep-1');
        await tester.pumpAndSettle();

        expect(
          find.byType(ChatDetailScreen),
          findsOneWidget,
          reason: 'A chat-detail push from the pinned root must mount and stay.',
        );
      },
    );

    testWidgets(
      '(b3) a chat-state capture pin releases after landing, so a later '
      'user push is not swallowed (JEBV4-321)',
      (tester) async {
        DevSeam.debugOverride(const DevSeamConfig(chatSelector: 'dm'));
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        expect(find.byType(DevChatPreviewScreen), findsOneWidget);

        // The chat fixture is another initial capture pin. Before JEBV4-321 its
        built.router.push('/capture-location');
        // MIDNIGHT R11: the capture screen's centre pin loops forever (M0-4),
        // so it never settles — advance it by hand.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          find.byType(CaptureLocationScreen),
          findsOneWidget,
          reason:
              'A capture-only guard must release after its first landing; '
              'otherwise accepted user pushes become visually dead CTAs.',
        );
        expect(find.byType(DevChatPreviewScreen), findsNothing);
      },
    );

    testWidgets(
      '(c) production (no dev route): pushing a route is not affected by the '
      'dev-seam pin',
      (tester) async {
        // No DevSeam override → _devRoute is empty → seam branch is inert and
        final built = await _buildRouter();
        await tester.pumpWidget(_harness(built));
        await tester.pumpAndSettle();

        // Lands on the shell, not forced anywhere by a (non-existent) pin.
        expect(find.byType(ShellScreen), findsOneWidget);

        // A push to a normal route is honoured (no dev-seam interference). We
        built.router.push('/capture-location');
        // MIDNIGHT R11: the capture screen's centre pin loops forever (M0-4),
        // so it never settles — advance it by hand.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.byType(CaptureLocationScreen),
          findsOneWidget,
          reason: 'With no dev route pinned, production routing is unchanged: '
              'a user-pushed route mounts and is never bounced by the seam.',
        );
      },
    );
  });
}
