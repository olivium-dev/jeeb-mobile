// Sprint 5 Stream B — system-BACK navigation defect regression guard.
//
// DEFECT: pressing the SYSTEM back gesture (Android hardware/gesture back, the
// `BackButtonDispatcher`/`PopScope` path — distinct from the AppBar back BUTTON
// covered by `back_button_blank_surface_test.dart`) on `order-detail`, `Login`,
// or `Saved-addresses` EXITED the app to the launcher instead of popping to the
// parent.
//
// ROOT CAUSE (go vs push): those screens can become the ROOT of the navigation
// stack — reached via `context.go(...)`/`goNamed(...)` (the auth funnel →
// `/login`, customer-profile → `/settings/addresses`) or via an inbound
// delivery push-notification / deep link (`GoRouter.go('/orders/:id')`). `go`
// REPLACES the stack, so there is nothing beneath the screen; the system BACK
// gesture has no pop target and propagates to the OS, exiting the app.
// (`context.push(...)` keeps the parent on the stack and does not exhibit this.)
//
// FIX: each screen is wrapped in `RootAwareBackScope`, which pops normally when
// a back stack exists and otherwise redirects BACK to the screen's logical
// parent (`/` for order-detail, `/register` for login, `/settings` for
// saved-addresses) instead of exiting. This test drives the REAL screens via a
// router and the REAL system-back gesture (the `popRoute` platform message).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/auth/presentation/login_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Dispatches the platform `popRoute` message — the exact channel the OS uses
/// for the Android system BACK gesture, routed through the Router's
/// `BackButtonDispatcher` → the top route's `PopScope`.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

/// Empty saved-locations repo so the manager mounts its (empty) ready state
/// without DI or a network call — the back affordance is present regardless.
class _EmptySavedRepo implements SavedLocationRepository {
  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => const [];
  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      throw UnimplementedError();
  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteLocation(String id) async {}
}

void main() {
  // A router that mounts the THREE real defect screens plus light placeholders
  // for their parent destinations. Mirrors `app.dart`'s null-child collapse so
  // an over-pop would surface as a blank `SizedBox.shrink()` (it must not).
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('HOME-SHELL'))),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('REGISTER-PARENT'))),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('SETTINGS-PARENT'))),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (context, state) =>
                DeliveryDetailScreen(deliveryId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/settings/addresses',
            builder: (context, state) =>
                SavedLocationsScreen(repository: _EmptySavedRepo()),
          ),
        ],
      );

  Widget collapseNullChild(BuildContext context, Widget? child) =>
      child ?? const SizedBox.shrink();

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: collapseNullChild,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
    'system BACK from order-detail reached via go() (deep-link/notification '
    'root) pops to Home, not the launcher',
    (tester) async {
      final router = await pump(tester);

      // The notification / deep-link entry: a stack-REPLACING navigation.
      router.go('/orders/o-1');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delivery-detail-list')), findsOneWidget);
      expect(locationOf(router), '/orders/o-1');

      await systemBack(tester);
      await tester.pumpAndSettle();

      // Popped to the parent (Home) instead of exiting; surface never blank.
      expect(locationOf(router), '/');
      expect(find.text('HOME-SHELL'), findsOneWidget);
    },
  );

  testWidgets(
    'system BACK from order-detail reached via push() pops to its parent '
    'normally (no regression to the in-app path)',
    (tester) async {
      final router = await pump(tester);
      expect(find.text('HOME-SHELL'), findsOneWidget);

      router.push('/orders/o-1');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delivery-detail-list')), findsOneWidget);

      await systemBack(tester);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/');
      expect(find.text('HOME-SHELL'), findsOneWidget);
    },
  );

  testWidgets(
    'system BACK from Login reached via go() (auth funnel root) pops to '
    '/register, not the launcher',
    (tester) async {
      final router = await pump(tester);

      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(locationOf(router), '/login');

      await systemBack(tester);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/register');
      expect(find.text('REGISTER-PARENT'), findsOneWidget);
    },
  );

  testWidgets(
    'system BACK from Saved-addresses reached via go() pops to /settings, '
    'not the launcher',
    (tester) async {
      final router = await pump(tester);

      router.go('/settings/addresses');
      await tester.pumpAndSettle();
      expect(find.byType(SavedLocationsScreen), findsOneWidget);
      expect(locationOf(router), '/settings/addresses');

      await systemBack(tester);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/settings');
      expect(find.text('SETTINGS-PARENT'), findsOneWidget);
    },
  );
}
