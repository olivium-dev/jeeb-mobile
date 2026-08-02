// Designed-state fixtures for `ClientLocationScreen` — the JM-024
// `location-select` step of the create flow.
//
// ONE source of truth, TWO consumers:
//
//   * `lib/devtool/catalog/entries/batch_06_entries.dart` — the on-device
//     Screen Catalog entry designers browse, and
//   * the `JEEB PREVIEWS` section at the bottom of
//     `lib/features/location/presentation/client_location_screen.dart` — the
//     engineer's `flutter widget-preview start` loop.
//
// Both surfaces used to be free to invent their own seeds, which is how a
// catalog state and a preview of the "same" screen drift apart. A state added
// or corrected here now lands in both at once.
//
// Everything below is inert by construction: no Dio, no GetIt, no geolocator,
// no platform channel. `ClientLocationScreen` takes BOTH of its collaborators
// as constructor seams (`repository:` and `currentLocationResolver:`), plus an
// injectable `userId:`, so every designed state is reachable without a real
// repository — the `CatalogNetworkGuard` the two hosts install has nothing left
// to catch here.
//
// A note on the GPS resolver, because it is the one behaviour these fixtures
// deliberately take away from the catalog: with `currentLocationResolver:` left
// null the screen builds a REAL `GeolocatorCurrentLocationResolver`
// (`ClientLocationScreen._resolveGpsResolver`), so opening the catalog entry on
// a device raised a live location-permission prompt and then rendered whichever
// state that device happened to be in. Scripting the outcome is what makes a
// "designed state" designed.

import 'dart:async';

import '../../../features/location/data/fake_location_select_repository.dart';
import '../../../features/location/domain/current_location_resolver.dart';
import '../../../features/location/domain/location_select_repository.dart';
import '../../../features/location/domain/saved_location.dart';

/// A [CurrentLocationResolver] whose one-shot acquisition always ends in a
/// scripted [CurrentLocationResult].
///
/// Covers every branch of `LocationSelectCubit.resolveCurrentGps` — resolved,
/// permission denied, services off, platform failure — without a platform
/// channel. The settings deep-links are no-ops: a catalog/preview host has no
/// OS settings page to open, and opening one would take the reviewer out of the
/// app mid-review.
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
///
/// This is the ONLY way to hold the screen in `CurrentGpsStatus.resolving`:
/// the cubit emits `resolving`, then awaits the resolver, so any resolver that
/// answers immediately flashes through the state faster than a canvas or a
/// widget test can observe it.
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
/// state, held open.
///
/// `LocationSelectCubit.load()` emits `loading` and awaits the fetch, so the
/// only way to LOOK at the full-screen spinner is a read that never answers.
/// A slow network is exactly this state, just with an end.
class ClientLocationScreenPendingRepository implements LocationSelectRepository {
  const ClientLocationScreenPendingRepository();

  @override
  Future<List<SavedLocation>> fetchSavedAddresses(String userId) =>
      Completer<List<SavedLocation>>().future;
}

/// The designed states of `ClientLocationScreen`, as (repository, resolver)
/// pairs the two hosts assemble the screen from.
class ClientLocationScreenFixtures {
  const ClientLocationScreenFixtures._();

  /// Owning user id. Injected so the screen never reaches for [AuthTokenStore]
  /// (secure storage, unavailable in both hosts) — and deliberately NOT the
  /// `user-client-001` mock identity the S0-OAD-03 guard bans from `lib/`.
  static const String userId = 'preview-user-001';

  /// The returning customer: `Home` (Sassine Square) + `Office` (Beirut Tower),
  /// mirroring the `has_saved_addresses` seed.
  static const LocationSelectRepository savedAddresses =
      FakeLocationSelectRepository();

  /// A brand-new customer. The live gateway answers `200 {items: []}` here, so
  /// this is `loaded`-with-nothing, NOT a failure — the distinction the screen's
  /// `canConfirm` rule turns on.
  static const LocationSelectRepository noSavedAddresses =
      FakeLocationSelectRepository(addresses: <SavedLocation>[]);

  /// A genuine transport failure on `GET /users/:id/saved-locations`.
  ///
  /// The contract this seeds is "degrade the sub-list, never the flow": the
  /// retry banner appears, and the Current/New affordances and the Confirm CTA
  /// all stay live.
  static const LocationSelectRepository savedAddressesUnavailable =
      FakeLocationSelectRepository(failWith: LocationSelectFailure.network);

  /// A read that never answers — the cold-load spinner.
  static const LocationSelectRepository savedAddressesPending =
      ClientLocationScreenPendingRepository();

  /// Longest plausible label a customer types into the JM-050 address form.
  /// There is no length cap on that field, so this is not a synthetic ceiling.
  static const String longestSavedLabel =
      'Teta Salma’s apartment — third building after the pharmacy';

  /// Longest plausible free-text address for the same entry.
  static const String longestSavedAddress =
      'Rue Gouraud, Gemmayzeh, above the corner bakery, Beirut Central '
      'District, Lebanon';

  /// One saved address at the length ceiling, to see what the card does with
  /// copy that cannot fit on a 390pt phone.
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
  /// downtown-Beirut coordinate JEBV4-176 removed, so a fixture that fell back
  /// to the old default would be visible rather than plausible.
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
  /// panel.
  static const CurrentLocationResolver gpsServiceDisabled =
      ClientLocationScreenScriptedGpsResolver(
    CurrentLocationResult.serviceDisabled(),
  );
}
