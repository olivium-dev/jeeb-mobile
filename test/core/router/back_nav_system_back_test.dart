// Sprint 5 Stream B — system-BACK navigation defect regression guard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Dispatches the platform `popRoute` message — the exact channel the OS uses
/// for the Android system BACK gesture, routed through the Router's
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
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('HOME-SHELL'))),
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
            path: '/settings/addresses',
            builder: (context, state) =>
                SavedLocationsScreen(repository: _EmptySavedRepo()),
          ),
        ],
      );

  // `JeebEmptyState`'s illustrations loop ∞ by design (02-STUDY-NOTES §Motion),
  // so pumpAndSettle only terminates under reduce motion.
  Widget collapseNullChild(BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child ?? const SizedBox.shrink(),
      );

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
