import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../cubit/location_picker_cubit.dart';
import '../../data/location_repository.dart';
import '../../domain/saved_location.dart';
import '../../domain/saved_location_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import 'dart:async';

class SavedLocationsChipRow extends StatefulWidget {
  const SavedLocationsChipRow({
    super.key,
    required this.repository,
    this.onLocationSaved,
    this.pendingLatLng,
    this.pendingAddress,
  });

  final SavedLocationRepository repository;

  final VoidCallback? onLocationSaved;

  final (double, double)? pendingLatLng;

  final String? pendingAddress;

  @override
  State<SavedLocationsChipRow> createState() => _SavedLocationsChipRowState();
}

class _SavedLocationsChipRowState extends State<SavedLocationsChipRow> {
  List<SavedLocation>? _locations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.repository.fetchSavedLocations();
      if (mounted) {
        setState(() {
          _locations = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final locations = _locations ?? const [];
    if (locations.isEmpty) return const SizedBox.shrink();
    return _ChipRow(
      locations: locations,
      onTap: _onChipTap,
    );
  }

  void _onChipTap(SavedLocation loc) {
    context.read<LocationPickerCubit>().selectSearchResult(
      LocationPoint(
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: loc.address ?? loc.label,
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.locations, required this.onTap});

  final List<SavedLocation> locations;
  final void Function(SavedLocation) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.large,
            Spacing.small,
            Spacing.large,
            Spacing.xSmall,
          ),
          child: Text(
            l10n.savedLocationsTitle,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.large,
            ),
            itemCount: locations.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: Spacing.xSmall),
            itemBuilder: (context, index) {
              final loc = locations[index];
              return _LocationChip(
                location: loc,
                onTap: () => onTap(loc),
              );
            },
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location, required this.onTap});

  final SavedLocation location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = _chipLabel(l10n, location);
    return OmdsChip(
      label: label,
      onTap: onTap,
      icon: Icon(_categoryIcon(location.category), size: Sizes.small),
    );
  }

  String _chipLabel(AppLocalizations l10n, SavedLocation loc) {
    switch (loc.category) {
      case SavedLocationCategory.home:
        return l10n.savedLocationsChipHome;
      case SavedLocationCategory.work:
        return l10n.savedLocationsChipWork;
      case SavedLocationCategory.other:
        return loc.label.isNotEmpty ? loc.label : l10n.savedLocationsChipOther;
    }
  }

  IconData _categoryIcon(SavedLocationCategory category) {
    switch (category) {
      case SavedLocationCategory.home:
        return Icons.home_rounded;
      case SavedLocationCategory.work:
        return Icons.work_rounded;
      case SavedLocationCategory.other:
        return Icons.place_rounded;
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/saved_locations_chip_row_preview_test.dart
// ===========================================================================
// Widget previews for [SavedLocationsChipRow] — run with
// `flutter widget-preview start`.
//
// The widget owns its own load: `initState` calls
// `repository.fetchSavedLocations()` and it renders nothing until that
// settles. Every preview below therefore injects a local fake repository
// through the constructor seam — a canned list, a future that never lands, or
// a throw. No preview constructs a Dio-backed repository, so these are
// network-free by construction and not merely by the guard in
// [jeebPreviewHost].
//
// Three of the six states — empty, loading, fetch-failed — collapse the widget
// to `SizedBox.shrink()`. That collapse is the AC (T-MOB-012 AC3: "if no saved
// locations exist the row is hidden so the map is not pushed down"), but it
// also means three previews would be pixel-identical blank boxes and a
// render-only test could not tell them apart. So each preview is composed the
// way the picker screen composes it — chip row above the map — using
// [_SavedLocationsChipRowMapStandIn], a fixture that is NOT production code. It reports which
// fixture fed the row, and its top edge is where the map begins, which makes
// "the row is hidden" and "the row pushed the map down" different pictures.
//
// Two things these previews surfaced, both in the widget rather than in the
// previews:
//
//  * the 40 pt `SizedBox` around the chip list is shorter than the 48 pt
//    minimum tap target [OmdsChip] asks for, so every chip is clipped to a
//    40 pt target — and at 200% text the chip capsule itself no longer fits;
//  * a failed fetch is swallowed: no error, no retry, no way for the user to
//    tell "we could not load your addresses" from "you have none".
//
// See the notes on each preview.

/// The canvas box for the picker header: phone width, and tall enough that the
/// chip row plus a slice of map are both visible — the collapse states are only
/// readable against something below them. Pinned by the render test.
const Size _savedLocationsChipRowBox = Size(390, 200);

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
class _SavedLocationsChipRowMapStandIn extends StatelessWidget {
  const _SavedLocationsChipRowMapStandIn({required this.fixture});

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
class _SavedLocationsChipRowFakeRepository implements SavedLocationRepository {
  const _SavedLocationsChipRowFakeRepository(this.locations);

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
class _SavedLocationsChipRowPendingRepository extends _SavedLocationsChipRowFakeRepository {
  const _SavedLocationsChipRowPendingRepository() : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

/// A repository whose read fails the way the live BFF fails — a thrown
/// [SavedLocationException], not a null or an empty list.
class _SavedLocationsChipRowFailingRepository extends _SavedLocationsChipRowFakeRepository {
  const _SavedLocationsChipRowFailingRepository() : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async =>
      throw const SavedLocationException('GET saved-locations failed');
}

/// The `has_saved_addresses` seam seed (63_W1_TEST_PLAN §4.1), reused verbatim
/// from `test/saved_locations_screen_test.dart` so the canvas and the existing
/// suites describe the same account.
const SavedLocation _savedLocationsChipRowHome = SavedLocation(
  id: 'addr-client-001-home',
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
  isDefault: true,
);

const SavedLocation _savedLocationsChipRowOffice = SavedLocation(
  id: 'addr-client-001-office',
  label: 'Office',
  latitude: 33.8938,
  longitude: 35.5018,
  category: SavedLocationCategory.work,
  address: 'Downtown Beirut',
);

Widget _savedLocationsChipRowHosted(SavedLocationRepository repository, {required String fixture}) {
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
        Expanded(child: _SavedLocationsChipRowMapStandIn(fixture: fixture)),
      ],
    ),
  );
}

Widget _savedLocationsChipRowWithLocations(List<SavedLocation> locations, {required String fixture}) =>
    _savedLocationsChipRowHosted(_SavedLocationsChipRowFakeRepository(locations), fixture: fixture);

/// The happy path: the two addresses the `has_saved_addresses` seam seeds.
///
/// Worth reading closely in the canvas — the chips say **Home** and **Work**,
/// not `Home` and `Office`. For the `home`/`work` categories the widget
/// discards `SavedLocation.label` and renders the localized category name, so
/// the address the manage screen lists as "Office" appears here as "Work".
@JeebPreview(group: 'location', name: 'Home + Work', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowHomeAndWork() => _savedLocationsChipRowWithLocations(
      const <SavedLocation>[_savedLocationsChipRowHome, _savedLocationsChipRowOffice],
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
@JeebPreview(group: 'location', name: 'Other · long + unnamed', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowOtherLabels() => _savedLocationsChipRowWithLocations(
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
@JeebPreview(group: 'location', name: 'Ten saved · at the cap', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowAtCap() => _savedLocationsChipRowWithLocations(
      <SavedLocation>[
        _savedLocationsChipRowHome,
        _savedLocationsChipRowOffice,
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
@JeebPreview(group: 'location', name: 'Empty · row hidden', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowEmpty() =>
    _savedLocationsChipRowWithLocations(const <SavedLocation>[], fixture: 'empty list');

/// The pre-load window, made permanent.
///
/// `initState` fires the fetch and the widget renders `SizedBox.shrink()` until
/// it lands, with no skeleton and no reserved height. On a slow connection the
/// chips therefore appear late and shove the map down under the user's finger
/// mid-drag. This preview holds that window open by never completing the read.
@JeebPreview(group: 'location', name: 'Loading · row hidden', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowLoading() =>
    _savedLocationsChipRowHosted(const _SavedLocationsChipRowPendingRepository(), fixture: 'fetch never lands');

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
@JeebPreview(group: 'location', name: 'Fetch failed · row hidden', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowFetchFailed() =>
    _savedLocationsChipRowHosted(const _SavedLocationsChipRowFailingRepository(), fixture: 'fetch throws');
