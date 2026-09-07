import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/network/app_failure.dart';
import '../../../../core/widgets/jeeb/jeeb_failure_block.dart';
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

  /// A failed chip fetch must not read as "no saved locations".
  AppFailure? _failure;

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
          _failure = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failure = AppFailure.of(e);
          _loading = false;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failure = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final AppFailure? failure = _failure;
    if (failure != null) {
      return JeebFailureBlock.compact(
        failure: failure,
        identifier: 'saved_locations_chips_error',
        headlineOverride:
            AppLocalizations.of(context).savedLocationsChipsLoadFailed,
        retryIdentifier: 'saved_locations_chips_retry_cta',
        onRetry: _retry,
      );
    }
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
// DEV-ONLY, NOT SHIPPED.

/// The canvas box for the picker header: phone width, and tall enough that the
const Size _savedLocationsChipRowBox = Size(390, 200);

/// Marks the map stand-in so the render test can measure where the map starts.
/// Whether the row pushed the map down is the whole of AC3, and measuring this
const Key savedLocationsChipRowPreviewMapKey =
    Key('saved-locations-chip-row-preview-map');

class _SavedLocationsChipRowMapStandIn extends StatelessWidget {
  const _SavedLocationsChipRowMapStandIn({required this.fixture});

  /// Which fake fed [SavedLocationsChipRow] — `home + work`, `empty list`,
  /// `fetch never lands`, … Rendered so a preview wired to the wrong fake
  final String fixture;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: savedLocationsChipRowPreviewMapKey,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(Spacing.small),
      alignment: Alignment.topLeft,
      child: Text(
        // Forced LTR: this line is diagnostic, not shipped copy, and a latin
        'fixture: $fixture',
        textDirection: TextDirection.ltr,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

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

class _SavedLocationsChipRowPendingRepository extends _SavedLocationsChipRowFakeRepository {
  const _SavedLocationsChipRowPendingRepository() : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

class _SavedLocationsChipRowFailingRepository extends _SavedLocationsChipRowFakeRepository {
  const _SavedLocationsChipRowFailingRepository() : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async =>
      throw const SavedLocationException('GET saved-locations failed');
}

/// The `has_saved_addresses` seam seed (63_W1_TEST_PLAN §4.1), reused verbatim
/// from `test/saved_locations_screen_test.dart` so the canvas and the existing
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

@JeebPreview(group: 'location', name: 'Home + Work', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowHomeAndWork() => _savedLocationsChipRowWithLocations(
      const <SavedLocation>[_savedLocationsChipRowHome, _savedLocationsChipRowOffice],
      fixture: 'home + work',
    );

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

@JeebPreview(group: 'location', name: 'Empty · row hidden', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowEmpty() =>
    _savedLocationsChipRowWithLocations(const <SavedLocation>[], fixture: 'empty list');

@JeebPreview(group: 'location', name: 'Loading · row hidden', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowLoading() =>
    _savedLocationsChipRowHosted(const _SavedLocationsChipRowPendingRepository(), fixture: 'fetch never lands');

@JeebPreview(group: 'location', name: 'Fetch failed · row hidden', size: _savedLocationsChipRowBox)
Widget savedLocationsChipRowFetchFailed() =>
    _savedLocationsChipRowHosted(const _SavedLocationsChipRowFailingRepository(), fixture: 'fetch throws');
