import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/location_picker_cubit.dart';
import '../cubit/location_picker_state.dart';
import '../data/location_repository.dart';
import '../data/map_picker_launcher.dart';
import 'location_search_bar.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/location_picker_screen_fixtures.dart';

class LocationPickerScreen extends StatelessWidget {
  const LocationPickerScreen({
    super.key,
    this.cubit,
    this.mapPickerLauncher,
    this.onCompleted,
  });

  final LocationPickerCubit? cubit;

  final MapPickerLauncher? mapPickerLauncher;

  final ValueChanged<DeliveryLocations>? onCompleted;

  @override
  Widget build(BuildContext context) {
    final inherited = cubit;
    if (inherited != null) {
      return BlocProvider.value(
        value: inherited,
        child: _LocationPickerView(
          mapPickerLauncher: mapPickerLauncher,
          onCompleted: onCompleted,
        ),
      );
    }
    return _LocationPickerView(
      mapPickerLauncher: mapPickerLauncher,
      onCompleted: onCompleted,
    );
  }
}

class _LocationPickerView extends StatefulWidget {
  const _LocationPickerView({
    required this.mapPickerLauncher,
    required this.onCompleted,
  });

  final MapPickerLauncher? mapPickerLauncher;
  final ValueChanged<DeliveryLocations>? onCompleted;

  @override
  State<_LocationPickerView> createState() => _LocationPickerViewState();
}

class _LocationPickerViewState extends State<_LocationPickerView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker(BuildContext context) async {
    final launcher = widget.mapPickerLauncher;
    if (launcher == null) return;
    final cubit = context.read<LocationPickerCubit>();
    final result = await launcher.pickOnMap(initial: cubit.state.draftSelection);
    if (result != null) {
      cubit.onPinDragged(
        latitude: result.latitude,
        longitude: result.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return BlocConsumer<LocationPickerCubit, LocationPickerState>(
      listenWhen: (prev, next) =>
          prev.error != next.error ||
          prev.searchQuery != next.searchQuery ||
          (prev.step != LocationPickerStep.done &&
              next.step == LocationPickerStep.done),
      listener: (context, state) {
        if (state.error != null) {
          showOmdsErrorSnackbar(
            context,
            message: _errorCopy(l10n, state.error!),
          );
          context.read<LocationPickerCubit>().acknowledgeError();
        }
        if (state.searchQuery != _searchController.text) {
          _searchController.value = TextEditingValue(
            text: state.searchQuery,
            selection: TextSelection.collapsed(
              offset: state.searchQuery.length,
            ),
          );
        }
        if (state.isComplete && state.pickup != null && state.dropoff != null) {
          final pair = DeliveryLocations(
            pickup: state.pickup!,
            dropoff: state.dropoff!,
          );
          if (widget.onCompleted != null) {
            widget.onCompleted!(pair);
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(pair);
          }
        }
      },
      buildWhen: (prev, next) => prev != next,
      builder: (context, state) => Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: OMDSAppBar(
          title: _appBarTitle(l10n, state),
          showBackButton: true,
          onBackPressed: () {
            final cubit = context.read<LocationPickerCubit>();
            if (cubit.state.step == LocationPickerStep.dropoff) {
              cubit.goBack();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepBadge(step: state.step, l10n: l10n),
                const SizedBox(height: Spacing.medium),
                LocationSearchBar(
                  controller: _searchController,
                  hintText: l10n.locationSearchHint,
                  query: state.searchQuery,
                  results: state.searchResults,
                  isSearching: state.isSearching,
                  emptyResultsLabel: l10n.locationSearchEmpty,
                  onChanged: (q) =>
                      context.read<LocationPickerCubit>().searchAddress(q),
                  onResultSelected: (point) {
                    context
                        .read<LocationPickerCubit>()
                        .selectSearchResult(point);
                  },
                ),
                const SizedBox(height: Spacing.medium),
                _DraftPreviewCard(state: state, l10n: l10n),
                const SizedBox(height: Spacing.medium),
                Row(
                  children: [
                    Expanded(
                      child: OmdsPrimaryButton(
                        text: l10n.locationUseCurrentGps,
                        variant: OmdsButtonVariant.outlined,
                        icon: const Icon(Icons.my_location, size: 18),
                        isEnabled: !state.isLocatingGps && !state.isSaving,
                        onTap: () => context
                            .read<LocationPickerCubit>()
                            .detectCurrentLocation(),
                      ),
                    ),
                    if (widget.mapPickerLauncher != null) ...[
                      const SizedBox(width: Spacing.small),
                      Expanded(
                        child: OmdsPrimaryButton(
                          text: l10n.locationOpenMap,
                          variant: OmdsButtonVariant.outlined,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          isEnabled: !state.isSaving,
                          onTap: () => _openMapPicker(context),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                _PairPreview(state: state, l10n: l10n),
                const SizedBox(height: Spacing.medium),
                OmdsPrimaryButton(
                  text: _confirmCta(l10n, state),
                  isEnabled: state.canConfirm,
                  onTap: () =>
                      context.read<LocationPickerCubit>().confirmAndContinue(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _appBarTitle(AppLocalizations l10n, LocationPickerState state) {
    switch (state.step) {
      case LocationPickerStep.pickup:
        return l10n.locationPickupTitle;
      case LocationPickerStep.dropoff:
        return l10n.locationDropoffTitle;
      case LocationPickerStep.done:
        return l10n.locationConfirmedTitle;
    }
  }

  String _confirmCta(AppLocalizations l10n, LocationPickerState state) {
    if (state.isSaving) return l10n.locationSavingCta;
    switch (state.step) {
      case LocationPickerStep.pickup:
        return l10n.locationContinueToDropoff;
      case LocationPickerStep.dropoff:
        return l10n.locationConfirmAndSave;
      case LocationPickerStep.done:
        return l10n.locationConfirmedTitle;
    }
  }

  String _errorCopy(AppLocalizations l10n, LocationPickerError error) {
    switch (error) {
      case LocationPickerError.gpsPermissionDenied:
        return l10n.locationErrorPermissionDenied;
      case LocationPickerError.gpsUnavailable:
        return l10n.locationErrorGpsUnavailable;
      case LocationPickerError.searchFailed:
        return l10n.locationErrorSearchFailed;
      case LocationPickerError.geocodingFailed:
        return l10n.locationErrorGeocodingFailed;
      case LocationPickerError.saveFailed:
        return l10n.locationErrorSaveFailed;
    }
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step, required this.l10n});

  final LocationPickerStep step;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = switch (step) {
      LocationPickerStep.pickup => l10n.locationStepPickup,
      LocationPickerStep.dropoff => l10n.locationStepDropoff,
      LocationPickerStep.done => l10n.locationStepDone,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: OmdsBorderRadius.uiLarge,
      ),
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DraftPreviewCard extends StatelessWidget {
  const _DraftPreviewCard({required this.state, required this.l10n});

  final LocationPickerState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final draft = state.draftSelection;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.uiMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.locationSelectedPreviewLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.xSmall),
                if (state.isLocatingGps)
                  Text(
                    l10n.locationDetectingGps,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  )
                else if (draft == null)
                  Text(
                    l10n.locationNoSelectionYet,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    draft.address ??
                        l10n.locationCoordinatesFallback(
                          draft.latitude.toStringAsFixed(5),
                          draft.longitude.toStringAsFixed(5),
                        ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                if (state.isResolvingAddress)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xSmall),
                    child: Text(
                      l10n.locationResolvingAddress,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairPreview extends StatelessWidget {
  const _PairPreview({required this.state, required this.l10n});

  final LocationPickerState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pickup = state.pickup;
    if (pickup == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PairRow(
          icon: Icons.trip_origin,
          label: l10n.locationPickupTitle,
          point: pickup,
          l10n: l10n,
        ),
        if (state.dropoff != null) ...[
          const SizedBox(height: Spacing.xSmall),
          _PairRow(
            icon: Icons.place,
            label: l10n.locationDropoffTitle,
            point: state.dropoff!,
            l10n: l10n,
          ),
        ],
      ],
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.icon,
    required this.label,
    required this.point,
    required this.l10n,
  });

  final IconData icon;
  final String label;
  final LocationPoint point;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final address = point.address ??
        l10n.locationCoordinatesFallback(
          point.latitude.toStringAsFixed(5),
          point.longitude.toStringAsFixed(5),
        );
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 18),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: address),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size _locationPickerScreenPhoneBox = Size(390, 844);

/// Assembles the real screen from one seeded cubit, in the configuration the
Widget _locationPickerScreenHosted(LocationPickerCubit cubit) =>
    LocationPickerScreen(cubit: cubit, onCompleted: (_) {});

/// The same screen with the map seam installed — the production wiring, and the
Widget _locationPickerScreenHostedWithMap(LocationPickerCubit cubit) =>
    LocationPickerScreen(
      cubit: cubit,
      mapPickerLauncher: LocationPickerScreenFixtures.mapPicker,
      onCompleted: (_) {},
    );

/// Runs [act] against [cubit] once the first frame is on screen.
class _LocationPickerScreenAfterFirstFrame extends StatefulWidget {
  const _LocationPickerScreenAfterFirstFrame({
    required this.cubit,
    required this.act,
  });

  final LocationPickerCubit cubit;
  final void Function(LocationPickerCubit cubit) act;

  @override
  State<_LocationPickerScreenAfterFirstFrame> createState() =>
      _LocationPickerScreenAfterFirstFrameState();
}

class _LocationPickerScreenAfterFirstFrameState
    extends State<_LocationPickerScreenAfterFirstFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) widget.act(widget.cubit);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _locationPickerScreenHosted(widget.cubit);
}

/// Post-frame action for [locationPickerScreenSaveFailed].
void _locationPickerScreenConfirm(LocationPickerCubit cubit) {
  cubit.confirmAndContinue();
}

/// Post-frame action for [locationPickerScreenGpsDenied].
void _locationPickerScreenDetectGps(LocationPickerCubit cubit) {
  cubit.detectCurrentLocation();
}

/// Cold open on step 1 — the empty state, and the one every request starts in.
@JeebPreview(
  group: 'location',
  name: 'Pickup · nothing selected',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenPickupEmpty() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.pickupNoSelection());

/// `detectCurrentLocation()` in flight and never landing.
@JeebPreview(
  group: 'location',
  name: 'Pickup · finding GPS',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenLocatingGps() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.pickupLocatingGps());

/// A pin dropped, the reverse geocode still out.
@JeebPreview(
  group: 'location',
  name: 'Pickup · resolving dragged pin',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenResolvingAddress() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.pickupResolvingAddress(),
    );

/// The suggestion dropdown open under the search bar.
@JeebPreview(
  group: 'location',
  name: 'Pickup · suggestions open',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSearchResults() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.pickupSearchResults());

/// One frame after the user tapped "Hamra Street, Beirut" — and a bug you can
@JeebPreview(
  group: 'location',
  name: 'Pickup · just tapped a suggestion',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSuggestionSelected() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.pickupSuggestionSelected(),
    );

/// Step 2, the pickup locked in.
@JeebPreview(
  group: 'location',
  name: 'Dropoff · pickup confirmed',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenDropoff() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.dropoffPickupConfirmed(),
    );

/// The layout ceiling: the longest pickup AND the longest dropoff at once.
@JeebPreview(
  group: 'location',
  name: 'Dropoff · longest addresses',
  size: _locationPickerScreenPhoneBox,
  matrix: true,
)
Widget locationPickerScreenLongestAddresses() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.dropoffLongestAddresses(),
    );

/// The save in flight and never landing.
@JeebPreview(
  group: 'location',
  name: 'Dropoff · saving',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSaving() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.dropoffSaving());

/// The save failed — the ONLY error affordance this screen has.
@JeebPreview(
  group: 'location',
  name: 'Dropoff · save failed',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSaveFailed() =>
    _LocationPickerScreenAfterFirstFrame(
      cubit: LocationPickerScreenFixtures.dropoffSaveFails(),
      act: _locationPickerScreenConfirm,
    );

/// GPS refused at the OS level — the most common failure on a real first run.
@JeebPreview(
  group: 'location',
  name: 'Pickup · GPS permission denied',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenGpsDenied() => _LocationPickerScreenAfterFirstFrame(
      cubit: LocationPickerScreenFixtures.pickupGpsPermissionDenied(),
      act: _locationPickerScreenDetectGps,
    );

/// Both legs committed and saved — the terminal state the host pops on.
@JeebPreview(
  group: 'location',
  name: 'Confirmed · both legs saved',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenConfirmed() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.confirmedPair());

/// The production wiring: `mapPickerLauncher` supplied, so "Use current GPS" and
@JeebPreview(
  group: 'location',
  name: 'Pickup · GPS + Pin on map row',
  size: _locationPickerScreenPhoneBox,
  matrix: true,
)
Widget locationPickerScreenMapPinRow() => _locationPickerScreenHostedWithMap(
      LocationPickerScreenFixtures.pickupNoSelection(),
    );
