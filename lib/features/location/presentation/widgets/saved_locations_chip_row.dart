import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../cubit/location_picker_cubit.dart';
import '../../data/location_repository.dart';
import '../../domain/saved_location.dart';
import '../../domain/saved_location_repository.dart';

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

