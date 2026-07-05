// Isolated native UI test — SavedLocationsScreen (settings-addresses, JM-049).
// The screen self-provides its cubit from the `repository` seam and wraps its
// body in a RootAwareBackScope (a BackButtonListener that reaches for the
// GoRouter on a back gesture), so it must be pumped under a Router — we mount it
// in a one-route GoRouter via pumpRouterAndShoot (mirrors the widget test).
// Covers the seeded list (default badge + rows), the empty state, and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';

import '../support/screen_harness.dart';

/// Scriptable saved-locations repo — only `fetchSavedLocations` is exercised by
/// a screenshot (mutations throw; they are never reached without interaction).
class _FakeRepo implements SavedLocationRepository {
  const _FakeRepo(this.list);
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

const _seeded = <SavedLocation>[
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
];

GoRouter _router(List<SavedLocation> list) => GoRouter(
      initialLocation: '/settings/addresses',
      routes: [
        GoRoute(
          path: '/settings/addresses',
          name: 'settings-addresses',
          builder: (context, state) =>
              SavedLocationsScreen(repository: _FakeRepo(list)),
        ),
      ],
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings-addresses: seeded list + default badge (en)',
      (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(_seeded),
      'settings-addresses__populated',
    );
  });

  testWidgets('settings-addresses: empty state (en)', (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(const []),
      'settings-addresses__empty',
    );
  });

  testWidgets('settings-addresses: seeded list (ar)', (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(_seeded),
      'settings-addresses__ar',
      locale: const Locale('ar'),
    );
  });
}
