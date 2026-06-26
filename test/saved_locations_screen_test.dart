import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// Scriptable saved-locations repo. Mirrors the `has_saved_addresses` seam
/// (Home default + Office) by default; `empty` exercises the zero-state.
class _FakeRepo implements SavedLocationRepository {
  _FakeRepo(this.list);

  factory _FakeRepo.seamSeed() => _FakeRepo(const [
        SavedLocation(
          id: 'addr-client-001-home',
          label: 'Home',
          latitude: 33.8869,
          longitude: 35.5131,
          category: SavedLocationCategory.home,
          address: 'Sassine Square, Ashrafieh',
          isDefault: true,
        ),
        SavedLocation(
          id: 'addr-client-001-office',
          label: 'Office',
          latitude: 33.8938,
          longitude: 35.5018,
          category: SavedLocationCategory.work,
          address: 'Downtown Beirut',
        ),
      ]);

  final List<SavedLocation> list;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => list;

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

/// Repo whose first load throws, then (if [recoverWith] is set) succeeds — lets
/// the error-state test prove the OmdsErrorState retry re-runs the real load.
class _FlakyRepo extends _FakeRepo {
  _FlakyRepo({this.recoverWith = const []}) : super(const []);

  final List<SavedLocation> recoverWith;
  int fetchCalls = 0;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    fetchCalls++;
    if (fetchCalls == 1) {
      throw Exception('load failed');
    }
    return recoverWith;
  }
}

/// Sentinel form screen so the `address-detail` route is assertable + carries
/// the destination id the jm-049 flow expects (`address_form_save_cta`).
class _FormSentinel extends StatelessWidget {
  const _FormSentinel({this.id});
  final String? id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          identifier: 'address_form_save_cta',
          button: true,
          child: Text('form id=${id ?? '<add>'}'),
        ),
      ),
    );
  }
}

String? lastFormId;
bool sawForm = false;

GoRouter _router(SavedLocationRepository repo) {
  return GoRouter(
    initialLocation: '/settings/addresses',
    routes: [
      GoRoute(
        path: '/settings/addresses',
        name: 'settings-addresses',
        builder: (context, state) => SavedLocationsScreen(repository: repo),
        routes: [
          GoRoute(
            path: 'edit',
            name: 'address-detail',
            builder: (context, state) {
              sawForm = true;
              lastFormId = state.uri.queryParameters['id'];
              return _FormSentinel(id: lastFormId);
            },
          ),
        ],
      ),
    ],
  );
}

Widget _harness(GoRouter router, {Locale locale = const Locale('en')}) {
  return MaterialApp.router(
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  setUp(() {
    lastFormId = null;
    sawForm = false;
  });

  group('SavedLocationsScreen — JM-049', () {
    testWidgets('AC1: default badge + add CTA visible with seeded addresses',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
      // Home is the default → exactly one default badge.
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsOneWidget,
      );
      // Index-0 edit affordance present (coined pattern).
      expect(
        find.bySemanticsIdentifier('saved_address_0_edit'),
        findsOneWidget,
      );
    });

    testWidgets('add CTA visible on empty state (signature id)',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo(const []))));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
      // No addresses → no default badge / edit row.
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsNothing,
      );
    });

    testWidgets('AC2: add CTA → address-detail (add path, no id)',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('saved_address_add_cta'));
      await tester.pumpAndSettle();

      expect(sawForm, isTrue);
      expect(lastFormId, isNull); // add path carries no id
      expect(
        find.bySemanticsIdentifier('address_form_save_cta'),
        findsOneWidget,
      );
    });

    testWidgets('AC3: edit → address-detail?id=<addressId>', (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('saved_address_0_edit'));
      await tester.pumpAndSettle();

      expect(sawForm, isTrue);
      expect(lastFormId, 'addr-client-001-home');
      expect(
        find.bySemanticsIdentifier('address_form_save_cta'),
        findsOneWidget,
      );
    });

    // Sprint-6 Stream-B polish: empty/error states use the OMDS feedback
    // widgets (was hand-rolled Icon+Text columns) for fleet consistency.
    testWidgets('empty state uses OmdsEmptyState with honest zero-state copy',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo(const []))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved-locations-empty')), findsOneWidget);
      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.text('No saved addresses yet'), findsOneWidget);
    });

    testWidgets('error state uses OmdsErrorState and retry re-runs the load',
        (tester) async {
      final repo = _FlakyRepo(
        recoverWith: const [
          SavedLocation(
            id: 'addr-1',
            label: 'Home',
            latitude: 0,
            longitude: 0,
            category: SavedLocationCategory.home,
          ),
        ],
      );
      await tester.pumpWidget(_harness(_router(repo)));
      await tester.pumpAndSettle();

      // First load threw → OMDS error surface with retry.
      expect(find.byKey(const Key('saved-locations-error')), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // Retry re-runs the real load (no fabricated data); second load recovers.
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repo.fetchCalls, 2);
      expect(find.byKey(const Key('saved-locations-error')), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
