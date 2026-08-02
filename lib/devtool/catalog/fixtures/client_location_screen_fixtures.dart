import 'dart:async';

import '../../../features/location/data/fake_location_select_repository.dart';
import '../../../features/location/domain/current_location_resolver.dart';
import '../../../features/location/domain/location_select_repository.dart';
import '../../../features/location/domain/saved_location.dart';

class ClientLocationScreenScriptedGpsResolver implements CurrentLocationResolver {
  const ClientLocationScreenScriptedGpsResolver(this.result);

  final CurrentLocationResult result;

  @override
  Future<CurrentLocationResult> resolve() async => result;

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

/// A [CurrentLocationResolver] whose acquisition never completes.
class ClientLocationScreenPendingGpsResolver implements CurrentLocationResolver {
  const ClientLocationScreenPendingGpsResolver();

  @override
  Future<CurrentLocationResult> resolve() =>
      Completer<CurrentLocationResult>().future;

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

/// A [LocationSelectRepository] whose read never completes — the cold-load
class ClientLocationScreenPendingRepository implements LocationSelectRepository {
  const ClientLocationScreenPendingRepository();

  @override
  Future<List<SavedLocation>> fetchSavedAddresses(String userId) =>
      Completer<List<SavedLocation>>().future;
}

/// The designed states of `ClientLocationScreen`, as (repository, resolver)
class ClientLocationScreenFixtures {
  const ClientLocationScreenFixtures._();

  /// Owning user id. Injected so the screen never reaches for [AuthTokenStore]
  static const String userId = 'preview-user-001';

  /// The returning customer: `Home` (Sassine Square) + `Office` (Beirut Tower),
  static const LocationSelectRepository savedAddresses =
      FakeLocationSelectRepository();

  /// A brand-new customer. The live gateway answers `200 {items: []}` here, so
  static const LocationSelectRepository noSavedAddresses =
      FakeLocationSelectRepository(addresses: <SavedLocation>[]);

  /// A genuine transport failure on `GET /users/:id/saved-locations`.
  static const LocationSelectRepository savedAddressesUnavailable =
      FakeLocationSelectRepository(failWith: LocationSelectFailure.network);

  /// A read that never answers — the cold-load spinner.
  static const LocationSelectRepository savedAddressesPending =
      ClientLocationScreenPendingRepository();

  /// Longest plausible label a customer types into the JM-050 address form.
  static const String longestSavedLabel =
      'Teta Salma’s apartment — third building after the pharmacy';

  /// Longest plausible free-text address for the same entry.
  static const String longestSavedAddress =
      'Rue Gouraud, Gemmayzeh, above the corner bakery, Beirut Central '
      'District, Lebanon';

  /// One saved address at the length ceiling, to see what the card does with
  static const LocationSelectRepository longestSavedAddresses =
      FakeLocationSelectRepository(
    addresses: <SavedLocation>[
      SavedLocation(
        id: 'addr-preview-longest',
        label: longestSavedLabel,
        latitude: 33.8959,
        longitude: 35.4797,
        category: SavedLocationCategory.other,
        address: longestSavedAddress,
      ),
    ],
  );

  /// A REAL device fix — a Hamra point, deliberately NOT the `33.8886, 35.4955`
  static const CurrentLocationResolver gpsResolved =
      ClientLocationScreenScriptedGpsResolver(
    CurrentLocationResult.resolved(33.8959, 35.4797),
  );

  /// Acquisition in flight, held open.
  static const CurrentLocationResolver gpsResolving =
      ClientLocationScreenPendingGpsResolver();

  /// The app's location permission is denied → the "open app settings" panel.
  static const CurrentLocationResolver gpsPermissionDenied =
      ClientLocationScreenScriptedGpsResolver(
    CurrentLocationResult.permissionDenied(),
  );

  /// The OS location services are switched off → the "open location settings"
  static const CurrentLocationResolver gpsServiceDisabled =
      ClientLocationScreenScriptedGpsResolver(
    CurrentLocationResult.serviceDisabled(),
  );
}
