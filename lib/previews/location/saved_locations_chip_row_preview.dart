/// Widget previews for [SavedLocationsChipRow] — run with
/// `flutter widget-preview start`.
///
/// The widget owns its own load: `initState` calls
/// `repository.fetchSavedLocations()` and it renders nothing until that
/// settles. Every preview below therefore injects a local fake repository
/// through the constructor seam — a canned list, a future that never lands, or
/// a throw. No preview constructs a Dio-backed repository, so these are
/// network-free by construction and not merely by the guard in
/// [jeebPreviewHost].
///
/// Three of the six states — empty, loading, fetch-failed — collapse the widget
/// to `SizedBox.shrink()`. That collapse is the AC (T-MOB-012 AC3: "if no saved
/// locations exist the row is hidden so the map is not pushed down"), but it
/// also means three previews would be pixel-identical blank boxes and a
/// render-only test could not tell them apart. So each preview is composed the
/// way the picker screen composes it — chip row above the map — using
/// [_MapStandIn], a fixture that is NOT production code. It reports which
/// fixture fed the row, and its top edge is where the map begins, which makes
/// "the row is hidden" and "the row pushed the map down" different pictures.
///
/// Two things these previews surfaced, both in the widget rather than in the
/// previews:
///
///  * the 40 pt `SizedBox` around the chip list is shorter than the 48 pt
///    minimum tap target [OmdsChip] asks for, so every chip is clipped to a
///    40 pt target — and at 200% text the chip capsule itself no longer fits;
///  * a failed fetch is swallowed: no error, no retry, no way for the user to
///    tell "we could not load your addresses" from "you have none".
///
/// See the notes on each preview.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/location/cubit/location_picker_cubit.dart';
import '../../features/location/data/location_repository.dart';
import '../../features/location/domain/saved_location.dart';
import '../../features/location/domain/saved_location_repository.dart';
import '../../features/location/presentation/widgets/saved_locations_chip_row.dart';
import '../harness/jeeb_preview.dart';

/// The canvas box for the picker header: phone width, and tall enough that the
/// chip row plus a slice of map are both visible — the collapse states are only
/// readable against something below them. Pinned by the render test.
const Size _rowBox = Size(390, 200);

/// Marks the map stand-in so the render test can measure where the map starts.
/// Whether the row pushed the map down is the whole of AC3, and measuring this
/// offset is the only way a test can tell a hidden row from a rendered one.
const Key savedLocationsChipRowPreviewMapKey =
    Key('saved-locations-chip-row-preview-map');

/// Stand-in for the map the chip row floats above (fixture, not production).
///
/// Fills whatever the chip row left over, and names the repository fixture that
/// produced the state so the three collapsed previews are distinguishable on
/// screen and in the render test.
class _MapStandIn extends StatelessWidget {
  const _MapStandIn({required this.fixture});

  /// Which fake fed [SavedLocationsChipRow] — `home + work`, `empty list`,
  /// `fetch never lands`, … Rendered so a preview wired to the wrong fake
  /// fails the render test instead of looking plausible in the canvas.
  final String fixture;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: savedLocationsChipRowPreviewMapKey,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.topLeft,
      child: Text(
        // Forced LTR: this line is diagnostic, not shipped copy, and a latin
        // identifier reorders visually inside an RTL paragraph.
        'fixture: $fixture',
        textDirection: TextDirection.ltr,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Canned saved-locations repository. Reads return [locations]; the three
/// mutating members are unreachable from this widget and throw if that ever
/// stops being true.
class _FakeSavedLocationRepository implements SavedLocationRepository {
  const _FakeSavedLocationRepository(this.locations);

  final List<SavedLocation> locations;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => locations;

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) =>
      throw UnimplementedError();

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteLocation(String id) => throw UnimplementedError();
}

/// A repository whose read never lands — holds the widget in its pre-load
/// state for as long as the canvas is open.
class _PendingSavedLocationRepository extends _FakeSavedLocationRepository {
  const _PendingSavedLocationRepository() : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

/// A repository whose read fails the way the live BFF fails — a thrown
/// [SavedLocationException], not a null or an empty list.
class _FailingSavedLocationRepository extends _FakeSavedLocationRepository {
  const _FailingSavedLocationRepository() : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async =>
      throw const SavedLocationException('GET saved-locations failed');
}

/// The `has_saved_addresses` seam seed (63_W1_TEST_PLAN §4.1), reused verbatim
/// from `test/saved_locations_screen_test.dart` so the canvas and the existing
/// suites describe the same account.
const SavedLocation _home = SavedLocation(
  id: 'addr-client-001-home',
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
  isDefault: true,
);

const SavedLocation _office = SavedLocation(
  id: 'addr-client-001-office',
  label: 'Office',
  latitude: 33.8938,
  longitude: 35.5018,
  category: SavedLocationCategory.work,
  address: 'Downtown Beirut',
);

Widget _hosted(SavedLocationRepository repository, {required String fixture}) {
  return BlocProvider<LocationPickerCubit>(
    // Chip taps call `context.read<LocationPickerCubit>().selectSearchResult`,
    // so the cubit has to be here or the canvas throws on first tap. It is
    // built on production's own in-memory repository: inert, and incapable of
    // reaching the network even before [jeebPreviewHost] installs its guard.
    create: (_) => LocationPickerCubit(repository: InMemoryLocationRepository()),
    child: Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SavedLocationsChipRow(repository: repository),
        Expanded(child: _MapStandIn(fixture: fixture)),
      ],
    ),
  );
}

Widget _withLocations(List<SavedLocation> locations, {required String fixture}) =>
    _hosted(_FakeSavedLocationRepository(locations), fixture: fixture);

/// The happy path: the two addresses the `has_saved_addresses` seam seeds.
///
/// Worth reading closely in the canvas — the chips say **Home** and **Work**,
/// not `Home` and `Office`. For the `home`/`work` categories the widget
/// discards `SavedLocation.label` and renders the localized category name, so
/// the address the manage screen lists as "Office" appears here as "Work".
@JeebPreview(name: 'Home + Work', size: _rowBox)
Widget savedLocationsChipRowHomeAndWork() => _withLocations(
      const <SavedLocation>[_home, _office],
      fixture: 'home + work',
    );

/// The `other` category, where the label IS the chip text — including the two
/// ends of it in one row.
///
/// The first chip carries the longest label the 10-address cap makes plausible;
/// [OmdsChip]'s `Text` sets no `maxLines` and no `overflow`, and the list is
/// horizontal and unbounded, so a long label does not ellipsize — it grows the
/// chip until it runs off the edge and has to be scrolled to. The second chip
/// has an EMPTY label, which is the only path to the `savedLocationsChipOther`
/// fallback string; if that fallback ever breaks, this preview renders a chip
/// with an icon and no text at all.
@JeebPreview(name: 'Other · long + unnamed', size: _rowBox)
Widget savedLocationsChipRowOtherLabels() => _withLocations(
      const <SavedLocation>[
        SavedLocation(
          id: 'addr-client-001-souks',
          label: 'Beirut Souks — Parking Level B2, Weygand Street',
          latitude: 33.8975,
          longitude: 35.5062,
          category: SavedLocationCategory.other,
          address: 'Beirut Souks, Weygand Street',
        ),
        SavedLocation(
          id: 'addr-client-001-unnamed',
          label: '',
          latitude: 33.8912,
          longitude: 35.4955,
          category: SavedLocationCategory.other,
          address: 'Hamra Street',
        ),
      ],
      fixture: 'long + unnamed',
    );

/// A full shelf: the 10-address cap
/// ([SavedLocationCapReachedException] / `savedLocationsCapReached`).
///
/// Only two or three chips fit at phone width, so this is the state that says
/// whether the row scrolls — and, in the AR rendering, whether it scrolls from
/// the correct edge. There is no scroll affordance of any kind: no fade, no
/// count, no "manage" chip, so a user with ten addresses sees the same first
/// two as a user with two.
@JeebPreview(name: 'Ten saved · at the cap', size: _rowBox)
Widget savedLocationsChipRowAtCap() => _withLocations(
      <SavedLocation>[
        _home,
        _office,
        for (int i = 1; i <= 8; i++)
          SavedLocation(
            id: 'addr-client-001-other-$i',
            label: 'Address $i',
            latitude: 33.88 + i / 1000,
            longitude: 35.50 + i / 1000,
            category: SavedLocationCategory.other,
            address: 'Beirut $i',
          ),
      ],
      fixture: 'ten at the cap',
    );

/// A new account with nothing saved: the row hides entirely (AC3) rather than
/// rendering an empty shelf under a "Saved locations" heading.
///
/// The map stand-in starts at the top of the canvas — that flush top edge is
/// what "the map is not pushed down" looks like.
@JeebPreview(name: 'Empty · row hidden', size: _rowBox)
Widget savedLocationsChipRowEmpty() =>
    _withLocations(const <SavedLocation>[], fixture: 'empty list');

/// The pre-load window, made permanent.
///
/// `initState` fires the fetch and the widget renders `SizedBox.shrink()` until
/// it lands, with no skeleton and no reserved height. On a slow connection the
/// chips therefore appear late and shove the map down under the user's finger
/// mid-drag. This preview holds that window open by never completing the read.
@JeebPreview(name: 'Loading · row hidden', size: _rowBox)
Widget savedLocationsChipRowLoading() =>
    _hosted(const _PendingSavedLocationRepository(), fixture: 'fetch never lands');

/// The failure this widget cannot express.
///
/// `_load` catches everything and only clears the loading flag, leaving
/// `_locations` null — so a fetch that failed is rendered EXACTLY like an
/// account with no saved addresses. Compare the manage screen, which has an
/// `OmdsErrorState` plus a retry (`savedLocationsError` /
/// `savedLocationsRetry`); here a user whose addresses failed to load is told
/// nothing and has no way to ask again short of leaving the screen. If this
/// preview ever stops looking identical to `Empty · row hidden`, that gap has
/// been closed.
@JeebPreview(name: 'Fetch failed · row hidden', size: _rowBox)
Widget savedLocationsChipRowFetchFailed() =>
    _hosted(const _FailingSavedLocationRepository(), fixture: 'fetch throws');
