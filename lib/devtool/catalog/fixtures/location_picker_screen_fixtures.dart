// Shared dev-only fixtures for `LocationPickerScreen` — the 461-line
// cubit-driven implementation.
//
// NOT the one the app serves. Two classes carry this name, and `app_router.dart`
// imports the OTHER one — a 36-line "coming soon" placeholder — and mounts it at
// `/location`. Its fixtures are in
// `location_picker_placeholder_screen_fixtures.dart`; see
// `docs/previews/FINDING_location_picker_placeholder.md`. Everything below
// describes a screen no user can currently reach.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_06_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/location/presentation/location_picker_screen.dart`.
//
// The catalog used to own a private `_seededLocationPickerCubit` that drove the
// real cubit over the SHIPPED `InMemoryLocationRepository`. That worked, but it
// was neither a designed state nor a reusable one: the in-memory repository
// answers every call after a 60-150 ms delay, so each catalog state was really
// "whatever the cubit had reached by the time you looked", it could only ever
// produce the three states that repository can produce (no failure, no
// in-flight, no long address), and copying it into the preview section would
// have given the two surfaces two different Beiruts to drift apart in.
//
// Everything here is a LOCAL fake with explicit knobs. `LocationPickerScreen`
// takes a `cubit:` seam and `LocationPickerCubit` takes a `repository:` seam, so
// neither surface resolves anything out of GetIt and neither can reach Dio —
// network-free by construction, not merely by the guard the hosts install.
//
// ## Why the states are built by CALLING the cubit
//
// `LocationPickerCubit` has no `seed:` constructor and `emit` is `@protected`,
// so a designed state is reached the way the user reaches it: through the
// cubit's own public API, over a fake that answers however the state needs. That
// is a feature — every fixture below is a claim about a real transition, and if
// the cubit stops producing that state the fixture stops producing it too.
//
// Each builder is SYNCHRONOUS to the point it cares about. `selectSearchResult`,
// `searchAddress('')`, `onPinDragged` and the pickup leg of `confirmAndContinue`
// all emit before returning, so the cubit handed to the screen is already in the
// designed state on the first frame — no `pumpAndSettle` race, no "wait for the
// delay to settle". Only the two states that are DEFINED by an in-flight call
// (`dropoffSaving`, `pickupLocatingGps`) leave a future outstanding, and those
// futures never complete on purpose.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/data/map_picker_launcher.dart';

/// Canned [LocationRepository]: every operation answers from a constructor
/// knob, immediately, with no Dio and no GetIt.
///
/// `const`-constructible so the builders below stay cheap and so a catalog state
/// can be written inline.
///
/// Three knobs mean "never answers" rather than "answers X" —
/// [gpsPending], [geocodePending], [savePending]. They return a future from a
/// [Completer] nobody completes, which is the only way to hold the screen on an
/// in-flight state (`isLocatingGps`, `isResolvingAddress`, `isSaving`) long
/// enough to look at it. The cubit's own guards make that safe: it never
/// re-enters a call it has already started.
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

  /// What a successful `resolveCurrentGps()` hands back.
  final LocationPoint gps;

  /// When set, `resolveCurrentGps()` throws [LocationFailure] with this kind —
  /// the shape the cubit maps into [LocationPickerError].
  final LocationFailureKind? gpsFailure;

  /// When true `resolveCurrentGps()` never answers, holding `isLocatingGps`.
  final bool gpsPending;

  /// Rows `searchAddress(query)` filters, case-insensitively on the address —
  /// the same matching rule `InMemoryLocationRepository` uses, so typing in the
  /// canvas behaves the way typing in the app does.
  final List<LocationPoint> searchCatalogue;

  /// When true `searchAddress()` throws, driving
  /// [LocationPickerError.searchFailed].
  final bool searchFails;

  /// What `reverseGeocode()` resolves a dragged pin to. Null models the
  /// documented "backend has no street-level data for this point" answer.
  final String? geocoded;

  /// When true `reverseGeocode()` never answers, holding `isResolvingAddress`.
  final bool geocodePending;

  /// When true `saveDeliveryLocations()` never answers, holding `isSaving`.
  final bool savePending;

  /// When true `saveDeliveryLocations()` throws, driving
  /// [LocationPickerError.saveFailed] and keeping the user on the dropoff step.
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

/// The interactive-map seam, scripted.
///
/// Left null the screen HIDES the "Pin on map" button entirely and the GPS
/// button takes the full width; supplied, the two share one Row. Returning
/// [pinned] (default: cancelled) means a reviewer can tap the button and get the
/// real `onPinDragged` → reverse-geocode path instead of a crash on a missing
/// plugin.
///
/// Both hosts default to the NO-map configuration and exactly one preview
/// installs this, because the two-button Row does not fit a phone: measured at
/// 100 + 29 pt of horizontal overflow on a 390 pt device in English and
/// 154 + 168 pt in Arabic. Installing it everywhere would put an overflow banner
/// on every state and make the other ten unreviewable.
class LocationPickerScreenFakeMapPicker implements MapPickerLauncher {
  const LocationPickerScreenFakeMapPicker({this.pinned});

  /// What the map picker pops. Null is "the user cancelled".
  final LocationPoint? pinned;

  @override
  Future<LocationPoint?> pickOnMap({LocationPoint? initial}) async => pinned;
}

/// The designed states of `LocationPickerScreen`, one builder each.
///
/// Every builder returns a FRESH cubit — both hosts rebuild their state on every
/// open, and a shared cubit would carry one reviewer's taps into the next state.
final class LocationPickerScreenFixtures {
  const LocationPickerScreenFixtures._();

  // ── The Beirut catalogue ────────────────────────────────────────────────
  // The same five addresses `InMemoryLocationRepository` serves and
  // `test/location_picker_cubit_test.dart` asserts against, so the catalog, the
  // canvas and the cubit suite all talk about one city.

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

  /// Everything a `beirut` query matches — the full five-row dropdown.
  static const List<LocationPoint> beirutCatalogue = <LocationPoint>[
    downtown,
    hamra,
    gemmayze,
    achrafieh,
    verdun,
  ];

  /// The first three of [beirutCatalogue].
  ///
  /// The dropdown is an inline child of the screen's Column, so its rows come
  /// straight out of the layout budget. Measured: at the 800x600 surface
  /// `flutter test` renders at, five rows overflow the Column by 44 pt and three
  /// clear it by ~40; on a 320x568 device five overflow by 116 pt. Three is the
  /// biggest dropdown that renders cleanly everywhere the render harness looks,
  /// which keeps the screen-level preview about the PUSH-DOWN rather than about
  /// one overflow banner. The five-row dropdown in isolation is previewed on
  /// `LocationSearchBar` itself.
  static const List<LocationPoint> beirutTopMatches = <LocationPoint>[
    downtown,
    hamra,
    gemmayze,
  ];

  /// The longest pickup a Lebanese address plausibly gets: a mall with a
  /// parking level and a named entrance.
  static const LocationPoint souksParking = LocationPoint(
    latitude: 33.8975,
    longitude: 35.5062,
    address: 'Beirut Souks — Parking Level B2, Weygand Street entrance, '
        'Beirut Central District, Lebanon',
  );

  /// The longest dropoff: a hospital wing, a floor and a landmark, which is how
  /// people actually describe where a courier should hand a package over.
  static const LocationPoint hospitalWing = LocationPoint(
    latitude: 33.8794,
    longitude: 35.5117,
    address: 'Saint George Hospital University Medical Center — Building C, '
        '4th floor reception, Achrafieh, Beirut, Lebanon',
  );

  /// A point the backend could not name — `address: null`, which the screen
  /// renders through `locationCoordinatesFallback`.
  static const LocationPoint unnamedPin = LocationPoint(
    latitude: 33.8938,
    longitude: 35.5018,
  );

  /// The map seam, for the ONE surface that reviews the two-button row. Cancels
  /// rather than pinning — see [LocationPickerScreenFakeMapPicker].
  static const LocationPickerScreenFakeMapPicker mapPicker =
      LocationPickerScreenFakeMapPicker();

  // ── Designed states ─────────────────────────────────────────────────────

  /// Cold open on step 1: nothing picked, Continue inert.
  static LocationPickerCubit pickupNoSelection() => LocationPickerCubit(
        repository: const LocationPickerScreenFakeRepository(),
      );

  /// Step 1 with `detectCurrentLocation()` in flight and never landing.
  ///
  /// `isLocatingGps` is emitted synchronously by the cubit before it awaits, so
  /// the screen is already in this state on its first build.
  static LocationPickerCubit pickupLocatingGps() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(gpsPending: true),
    );
    unawaited(cubit.detectCurrentLocation());
    return cubit;
  }

  /// Step 1 just after a pin drag: the draft jumped to the new lat/lng with no
  /// address yet, and the reverse geocode never answers.
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

  /// Step 1, one frame after the user tapped a suggestion.
  ///
  /// Deliberately does NOT clear the query, because that is the state the cubit
  /// really leaves behind: `selectSearchResult` copies the chosen address into
  /// `searchQuery` and empties `searchResults`, which is the exact triple the
  /// search bar renders as "No matching addresses".
  static LocationPickerCubit pickupSuggestionSelected() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(
        searchCatalogue: beirutCatalogue,
      ),
    );
    cubit.selectSearchResult(hamra);
    return cubit;
  }

  /// Step 1 with the suggestion dropdown open under the bar.
  ///
  /// Zero debounce so the lookup lands on the next turn of the loop instead of
  /// 300 ms later; the fake answers without a delay of its own. See
  /// [beirutTopMatches] for why this is three rows and not five.
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

  /// Step 2: pickup committed, and the dropoff draft pre-seeded with the pickup
  /// pin the way `confirmAndContinue` seeds it.
  static LocationPickerCubit dropoffPickupConfirmed() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(),
    );
    _commitDraft(cubit, hamra);
    unawaited(cubit.confirmAndContinue());
    return cubit;
  }

  /// Step 2 carrying the longest pickup AND the longest dropoff at once.
  static LocationPickerCubit dropoffLongestAddresses() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(),
    );
    _commitDraft(cubit, souksParking);
    unawaited(cubit.confirmAndContinue());
    _commitDraft(cubit, hospitalWing);
    return cubit;
  }

  /// Step 2 with the save in flight and never landing: the CTA reads "Saving…"
  /// and every other affordance is inert.
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

  /// Step 2 ready to fail its save. The CALLER fires `confirmAndContinue()`
  /// after the first frame — see the preview section's note on why an error
  /// seeded before mount is invisible.
  static LocationPickerCubit dropoffSaveFails() {
    final LocationPickerCubit cubit = LocationPickerCubit(
      repository: const LocationPickerScreenFakeRepository(saveFails: true),
    );
    _commitDraft(cubit, hamra);
    unawaited(cubit.confirmAndContinue());
    _commitDraft(cubit, gemmayze);
    return cubit;
  }

  /// Step 1 whose GPS call is going to be refused. Same contract as
  /// [dropoffSaveFails]: the caller fires `detectCurrentLocation()` after the
  /// first frame.
  static LocationPickerCubit pickupGpsPermissionDenied() => LocationPickerCubit(
        repository: const LocationPickerScreenFakeRepository(
          gpsFailure: LocationFailureKind.gpsPermissionDenied,
        ),
      );

  /// Both legs committed and saved — the terminal state the host pops on.
  ///
  /// The save resolves on a microtask, so this is the one builder whose final
  /// state can land either just before or just after the first build. Both
  /// orders render the same screen; only the `onCompleted` callback differs,
  /// and both hosts pass a no-op.
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

  /// Commits [point] as the active draft the way a tapped suggestion does, then
  /// clears the query.
  ///
  /// Both calls emit synchronously. The `searchAddress('')` is not cosmetic:
  /// `selectSearchResult` leaves the chosen address sitting in `searchQuery`
  /// with an empty result list, which the search bar renders as "No matching
  /// addresses" — so without it every committed-draft state below would carry a
  /// spurious empty-state card. It is also the only clear that schedules NO
  /// debounce timer (the cubit short-circuits on a blank query), which keeps
  /// these fixtures free of pending timers under `flutter test`.
  static void _commitDraft(LocationPickerCubit cubit, LocationPoint point) {
    cubit.selectSearchResult(point);
    cubit.searchAddress('');
  }
}
