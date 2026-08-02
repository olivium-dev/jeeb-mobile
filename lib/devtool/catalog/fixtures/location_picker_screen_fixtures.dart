/// Designed states for LocationPickerScreen.
/// States built by calling cubit API (not seed), so each fixture claims a real transition.

import 'dart:async';

import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/data/map_picker_launcher.dart';

/// Fake repository; all operations answer from constructor knobs, no Dio.
class LocationPickerScreenFakeRepository implements LocationRepository {
  const LocationPickerScreenFakeRepository({
    this.gps = LocationPickerScreenFixtures.downtown,
    this.gpsFailure,
    this.gpsPending = false,
    this.searchCatalogue = const <LocationPoint>[],
    this.searchFails = false,
    this.geocoded,
    this.geocodePending = false,
    this.savePending = false,
    this.saveFails = false,
  });

  /// Successful GPS result.
  final LocationPoint gps;

  /// GPS failure kind.
  final LocationFailureKind? gpsFailure;

  /// GPS never answers (holds isLocatingGps).
  final bool gpsPending;

  /// Search result rows (case-insensitive address filter).
  final List<LocationPoint> searchCatalogue;

  /// Search throws error.
  final bool searchFails;

  /// Reverse-geocode result (null = no data).
  final String? geocoded;

  /// Reverse-geocode never answers (holds isResolvingAddress).
  final bool geocodePending;

  /// Save never answers (holds isSaving).
  final bool savePending;

  /// Save throws error.
  final bool saveFails;

  @override
  Future<LocationPoint> resolveCurrentGps() async {
    if (gpsPending) return Completer<LocationPoint>().future;
    final LocationFailureKind? failure = gpsFailure;
    if (failure != null) throw LocationFailure(failure);
    return gps;
  }

  @override
  Future<List<LocationPoint>> searchAddress(String query) async {
    if (searchFails) throw const LocationFailure(LocationFailureKind.searchFailed);
    final String trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const <LocationPoint>[];
    return searchCatalogue
        .where((LocationPoint p) => (p.address ?? '').toLowerCase().contains(trimmed))
        .toList(growable: false);
  }

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (geocodePending) return Completer<String?>().future;
    return geocoded;
  }

  @override
  Future<DeliveryLocations> saveDeliveryLocations({
    required LocationPoint pickup,
    required LocationPoint dropoff,
  }) async {
    if (savePending) return Completer<DeliveryLocations>().future;
    if (saveFails) throw const LocationFailure(LocationFailureKind.saveFailed);
    return DeliveryLocations(pickup: pickup, dropoff: dropoff);
  }

  @override
  Future<DeliveryLocations?> loadSavedLocations() async => null;
}

/// Fake map picker; null = cancelled.
class LocationPickerScreenFakeMapPicker implements MapPickerLauncher {
  const LocationPickerScreenFakeMapPicker({this.pinned});

  /// Map picker result (null = cancelled).
  final LocationPoint? pinned;

  @override
  Future<LocationPoint?> pickOnMap({LocationPoint? initial}) async => pinned;
}

/// LocationPickerScreen designed states (one builder each).
final class LocationPickerScreenFixtures {
  const LocationPickerScreenFixtures._();

  static const LocationPoint downtown = LocationPoint(
    latitude: 33.8938,
    longitude: 35.5018,
    address: 'Downtown, Beirut',
  );
  static const LocationPoint hamra = LocationPoint(
    latitude: 33.8889,
    longitude: 35.4955,
    address: 'Hamra Street, Beirut',
  );
  static const LocationPoint gemmayze = LocationPoint(
    latitude: 33.8869,
    longitude: 35.5131,
    address: 'Gemmayze, Beirut',
  );
  static const LocationPoint achrafieh = LocationPoint(
    latitude: 33.8703,
    longitude: 35.5380,
    address: 'Achrafieh, Beirut',
  );
  static const LocationPoint verdun = LocationPoint(
    latitude: 33.9081,
    longitude: 35.4806,
    address: 'Verdun, Beirut',
  );

  /// Full five-row dropdown (beirut query).
  static const List<LocationPoint> beirutCatalogue = <LocationPoint>[
    downtown,
    hamra,
    gemmayze,
    achrafieh,
    verdun,
  ];

  /// First three rows (fits screen without overflow).
  static const List<LocationPoint> beirutTopMatches = <LocationPoint>[
    downtown,
    hamra,
    gemmayze,
  ];

  /// Longest pickup: mall with parking level and entrance.
  static const LocationPoint souksParking = LocationPoint(
    latitude: 33.8975,
    longitude: 35.5062,
    address: 'Beirut Souks — Parking Level B2, Weygand Street entrance, '
        'Beirut Central District, Lebanon',
  );

  /// Longest dropoff: hospital wing, floor, landmark.
  static const LocationPoint hospitalWing = LocationPoint(
    latitude: 33.8794,
    longitude: 35.5117,
    address: 'Saint George Hospital University Medical Center — Building C, '
        '4th floor reception, Achrafieh, Beirut, Lebanon',
  );

  /// Backend couldn't name this point (address: null).
  static const LocationPoint unnamedPin = LocationPoint(
    latitude: 33.8938,
    longitude: 35.5018,
  );

  /// Map seam (for two-button row review).
  static const LocationPickerScreenFakeMapPicker mapPicker =
      LocationPickerScreenFakeMapPicker();

  /// Step 1: no selection.
  static LocationPickerCubit pickupNoSelection() => LocationPickerCubit(
        repository: const LocationPickerScreenFakeRepository(),
      );

  /// Step 1: GPS in flight (never lands).
  static LocationPickerCubit pickupLocatingGps() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(gpsPending: true),
    );
    unawaited(cubit.detectCurrentLocation());
    return cubit;
  }

  /// Step 1: pin dragged, reverse-geocode in flight.
  static LocationPickerCubit pickupResolvingAddress() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(geocodePending: true),
    );
    cubit.onPinDragged(
      latitude: unnamedPin.latitude,
      longitude: unnamedPin.longitude,
    );
    return cubit;
  }

  /// Step 1: suggestion tapped.
  static LocationPickerCubit pickupSuggestionSelected() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(
        searchCatalogue: beirutCatalogue,
      ),
    );
    cubit.selectSearchResult(hamra);
    return cubit;
  }

  /// Step 1: search results open.
  static LocationPickerCubit pickupSearchResults() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(
        searchCatalogue: beirutTopMatches,
      ),
      searchDebounce: Duration.zero,
    );
    cubit.searchAddress('beirut');
    return cubit;
  }

  /// Step 2: pickup confirmed.
  static LocationPickerCubit dropoffPickupConfirmed() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(),
    );
    _commitDraft(cubit, hamra);
    unawaited(cubit.confirmAndContinue());
    return cubit;
  }

  /// Step 2: longest pickup and dropoff together.
  static LocationPickerCubit dropoffLongestAddresses() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(),
    );
    _commitDraft(cubit, souksParking);
    unawaited(cubit.confirmAndContinue());
    _commitDraft(cubit, hospitalWing);
    return cubit;
  }

  /// Step 2: save in flight (never lands).
  static LocationPickerCubit dropoffSaving() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(savePending: true),
    );
    _commitDraft(cubit, hamra);
    unawaited(cubit.confirmAndContinue());
    _commitDraft(cubit, gemmayze);
    unawaited(cubit.confirmAndContinue());
    return cubit;
  }

  /// Step 2: save will fail (caller fires confirmAndContinue after first frame).
  static LocationPickerCubit dropoffSaveFails() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(saveFails: true),
    );
    _commitDraft(cubit, hamra);
    unawaited(cubit.confirmAndContinue());
    _commitDraft(cubit, gemmayze);
    return cubit;
  }

  /// Step 1: GPS permission denied (caller fires after first frame).
  static LocationPickerCubit pickupGpsPermissionDenied() => LocationPickerCubit(
        repository: const LocationPickerScreenFakeRepository(
          gpsFailure: LocationFailureKind.gpsPermissionDenied,
        ),
      );

  /// Terminal state: both legs committed and saved.
  static LocationPickerCubit confirmedPair() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(),
    );
    _commitDraft(cubit, hamra);
    unawaited(cubit.confirmAndContinue());
    _commitDraft(cubit, gemmayze);
    unawaited(cubit.confirmAndContinue());
    return cubit;
  }

  /// Commit draft and clear query (synchronous).
  static void _commitDraft(LocationPickerCubit cubit, LocationPoint point) {
    cubit.selectSearchResult(point);
    cubit.searchAddress('');
  }
}
