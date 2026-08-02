import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/location_picker_cubit.dart';
import '../cubit/location_picker_state.dart';
import '../data/location_repository.dart';
import '../data/map_picker_launcher.dart';
import 'location_search_bar.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/location_picker_screen_fixtures.dart';

/// Entry-point for the pickup → dropoff selection flow. The host wires the
/// cubit through DI; if [cubit] is left null the screen reads it off the
/// surrounding [BlocProvider] (matches the kyc / registration patterns).
// ORPHAN (JEBV4-227, verified 2026-07-12): real cubit-based picker, unwired — /location route mounts a placeholder instead — see docs/project-understanding/reconciliation/orphans.md
class LocationPickerScreen extends StatelessWidget {
  const LocationPickerScreen({
    super.key,
    this.cubit,
    this.mapPickerLauncher,
    this.onCompleted,
  });

  /// Explicit cubit override — used by tests and the request-creation flow
  /// where the host already owns the lifecycle.
  final LocationPickerCubit? cubit;

  /// Adapter that opens the interactive map picker (production: a thin
  /// wrapper around `ofl_geo_capture`'s `GeoCaptureScreen`). Optional — when
  /// null the "Pin on map" button is hidden and the user picks via GPS or
  /// search alone.
  final MapPickerLauncher? mapPickerLauncher;

  /// Notified once the cubit reaches [LocationPickerStep.done] so the host
  /// can pop / route. Optional — when null the screen pops itself.
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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/location_picker_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, and a two-step wizard whose twelve designed states are
// twelve different readings of ONE `LocationPickerState`. Four things shape the
// section.
//
// 1. **The Scaffold nests.** The screen owns an `OMDSAppBar` + `Scaffold` and
//    [jeebPreviewHost] wraps every child in a Scaffold of its own; the inner one
//    is the real surface and the outer contributes a background. So the canvas
//    box is a whole phone ([_locationPickerScreenPhoneBox], 390x844) rather than
//    the harness default of 390x200 — an app bar, a search dropdown, a spacer
//    and a sticky CTA cannot be judged in a 200 pt strip.
//
// 2. **Every state is a real transition, not a hand-built struct.** The seeds
//    live in [LocationPickerScreenFixtures], shared verbatim with the Screen
//    Catalog entry in `lib/devtool/catalog/entries/batch_06_entries.dart`. The
//    cubit has no `seed:` and `emit` is `@protected`, so each fixture drives the
//    real cubit through its own public API over a local fake repository — which
//    means a fixture cannot describe a state the cubit cannot actually reach.
//    Network-free by construction: no preview builds a Dio-backed repository and
//    the DI graph is never touched, so the guard in [jeebPreviewHost] is a net
//    rather than the plan.
//
// 3. **`mapPickerLauncher:` is null in eleven of the twelve**, matching the
//    catalog entry, because supplying it puts an overflow banner on the screen
//    (see below). [locationPickerScreenMapPinRow] is the one that installs it,
//    and that overflow is its entire subject.
//
// 4. **Two states have to be triggered AFTER the first frame** — see
//    [_LocationPickerScreenAfterFirstFrame] and the note on
//    [locationPickerScreenGpsDenied].
//
// What these previews surfaced in the SCREEN, none of it fixed here:
//
//  * **The GPS + "Pin on map" Row does not fit a phone.** Two `Expanded`
//    [OmdsPrimaryButton]s, each an icon + a label, each with 16 pt of internal
//    horizontal padding and no `TextOverflow` on the label. Measured with
//    `mapPickerLauncher` supplied: 390x844 overflows by 100 pt and 29 pt in
//    English and by 154 pt and 168 pt in Arabic; 320x568 by 135/64 (EN) and
//    189/203 (AR). It is clean at 390 with the map button hidden, and clean at
//    any width the render harness uses — `flutter test` renders on an 800 pt
//    surface, which is why no existing test sees it.
//  * **An error has no surface but a 4-second snackbar.** `state.error` is
//    consumed by `listenWhen`/`listener` and acknowledged immediately; nothing
//    in `builder` renders it. A `LocationPickerCubit` handed to this screen with
//    an error ALREADY set (a host that owns the lifecycle, a rebuild that
//    remounts the view) shows no error at all, because `listenWhen` compares
//    `prev.error != next.error` and there is no previous state to differ from.
//    That is why [locationPickerScreenGpsDenied] and
//    [locationPickerScreenSaveFailed] fire their failing call from a post-frame
//    callback instead of arriving pre-failed — a preview built the obvious way
//    renders a screen that looks completely healthy.
//  * **`_searchController` is only ever seeded from the listener.** There is no
//    initial sync in `initState` or `build`, so mounting the view over a cubit
//    that already holds a `searchQuery` — exactly what the `cubit:` seam is
//    documented for ("the request-creation flow where the host already owns the
//    lifecycle") — draws an EMPTY search field above a populated dropdown. Both
//    [locationPickerScreenSearchResults] and
//    [locationPickerScreenSuggestionSelected] show it.
//  * **Tapping a suggestion leaves "No matching addresses" under it.**
//    `selectSearchResult` copies the chosen address into `searchQuery` and
//    empties `searchResults`, which is byte-for-byte the "nothing matched"
//    triple — see [locationPickerScreenSuggestionSelected]. Every other fixture
//    has to clear the query by hand to avoid inheriting it.
//  * **The Column has one `Spacer` and nothing else flexible.** The search
//    dropdown is an inline child, not an overlay, so every suggestion pushes the
//    draft card, the button row and the CTA down; the `Spacer` surrenders its
//    space first and then the Column overflows. Measured: five suggestions
//    overflow by 44 pt on the 800x600 surface `flutter test` uses and by 116 pt
//    on a 320x568 device. [locationPickerScreenSearchResults] therefore shows
//    THREE — enough to see the push-down, few enough that the state under review
//    is the layout rather than one overflow banner.
//  * **A committed leg can carry no address at all.** `onPinDragged` sets the
//    draft before the reverse geocode answers, and `confirmAndContinue` commits
//    whatever the draft holds — so confirming during
//    [locationPickerScreenResolvingAddress] locks in a `LocationPoint` whose
//    `address` is null and never backfills. `_PairRow` then renders raw
//    `lat, lng` through `locationCoordinatesFallback`, with no `textDirection`,
//    which bidi reorders under Arabic.

/// The canvas box for a whole screen: a real 390x844 phone, not the harness
/// default.
const Size _locationPickerScreenPhoneBox = Size(390, 844);

/// Assembles the real screen from one seeded cubit, in the configuration the
/// Screen Catalog entry uses: no map seam, so "Pin on map" is hidden and
/// "Use current GPS" takes the full width.
///
/// `onCompleted` is overridden so the terminal state cannot try to pop a route
/// the canvas does not have.
Widget _locationPickerScreenHosted(LocationPickerCubit cubit) =>
    LocationPickerScreen(cubit: cubit, onCompleted: (_) {});

/// The same screen with the map seam installed — the production wiring, and the
/// one configuration that does not fit a phone.
Widget _locationPickerScreenHostedWithMap(LocationPickerCubit cubit) =>
    LocationPickerScreen(
      cubit: cubit,
      mapPickerLauncher: LocationPickerScreenFixtures.mapPicker,
      onCompleted: (_) {},
    );

/// Runs [act] against [cubit] once the first frame is on screen.
///
/// Required for any state whose only surface is the `BlocConsumer`'s `listener`.
/// `listenWhen` fires on a CHANGE, and a cubit that already carries the error
/// when `BlocProvider.value` mounts has no previous state to change from — so a
/// pre-failed fixture renders a healthy screen. Deferring the failing call by
/// one frame reproduces what the user experiences: a healthy screen, then a
/// snackbar.
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
///
/// Nothing is pinned, so the draft card reads "No location selected yet" and
/// `canConfirm` is false: the only live affordances are GPS, "Pin on map" and
/// the search field. Note what is NOT here — no map, no recent addresses, no
/// saved-address shortcut — which is why the step badge is doing all the
/// wayfinding.
@JeebPreview(
  group: 'location',
  name: 'Pickup · nothing selected',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenPickupEmpty() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.pickupNoSelection());

/// `detectCurrentLocation()` in flight and never landing.
///
/// The whole loading affordance is one line of body copy swapped into the draft
/// card; there is no spinner anywhere on the screen, and the "Use current GPS"
/// button greys out while "Pin on map" and the CTA stay live. On a slow fix this
/// reads as "nothing happened" rather than "working".
@JeebPreview(
  group: 'location',
  name: 'Pickup · finding GPS',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenLocatingGps() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.pickupLocatingGps());

/// A pin dropped, the reverse geocode still out.
///
/// The draft card shows the raw coordinate fallback with "Resolving address…"
/// under it — and the Continue CTA is ALREADY enabled, because `canConfirm` only
/// asks for a non-null draft. Confirming here commits a `LocationPoint` with a
/// null address that never backfills (`_reverseGeocode` writes to
/// `draftSelection`, not to `pickup`), and every later surface then shows the
/// leg as `lat, lng`.
@JeebPreview(
  group: 'location',
  name: 'Pickup · resolving dragged pin',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenResolvingAddress() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.pickupResolvingAddress(),
    );

/// The suggestion dropdown open under the search bar.
///
/// `_ResultsList` is `shrinkWrap: true` with `NeverScrollableScrollPhysics`, so
/// it takes the height its rows want and cannot give any back; the only flexible
/// child in the screen's Column is the `Spacer`, which is exhausted first. Three
/// rows already push the draft card, the GPS button and the CTA down by ~130 pt
/// — five overflow the Column outright (44 pt on the 800x600 render surface,
/// 116 pt on a 320x568 device), which is why this shows three.
///
/// Also the clearest look at the missing controller sync: `state.searchQuery` is
/// `beirut`, the dropdown is filtered by it, and the field above it is empty.
@JeebPreview(
  group: 'location',
  name: 'Pickup · suggestions open',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSearchResults() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.pickupSearchResults());

/// One frame after the user tapped "Hamra Street, Beirut" — and a bug you can
/// see.
///
/// The draft card correctly shows the chosen address. Directly under the search
/// bar, "No matching addresses" is also showing, because `selectSearchResult`
/// leaves a non-empty `searchQuery` with an empty `searchResults` and that is
/// indistinguishable from a query nothing matched. Nothing failed; the
/// empty-state line simply cannot tell "you picked this" from "there was
/// nothing".
@JeebPreview(
  group: 'location',
  name: 'Pickup · just tapped a suggestion',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSuggestionSelected() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.pickupSuggestionSelected(),
    );

/// Step 2, the pickup locked in.
///
/// Three things change at once and they are worth reading together: the app-bar
/// title and the step badge advance, the committed pickup appears in the pair
/// preview above the CTA, and the dropoff draft is PRE-SEEDED with the pickup
/// pin — so the CTA is enabled and a user who taps straight through saves a
/// delivery whose two legs are the same address.
@JeebPreview(
  group: 'location',
  name: 'Dropoff · pickup confirmed',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenDropoff() => _locationPickerScreenHosted(
      LocationPickerScreenFixtures.dropoffPickupConfirmed(),
    );

/// The layout ceiling: the longest pickup AND the longest dropoff at once.
///
/// Two different clamps meet here. `_PairRow` is a `RichText` with `maxLines: 1`
/// and an ellipsis, so a long committed leg is truncated to something a user
/// cannot verify — "Beirut Souks — Parking…" is not an address you can confirm a
/// courier will find. `_DraftPreviewCard`, one card up, has NO clamp at all, so
/// the same class of string wraps to three or four lines and pushes the rest of
/// the column into the `Spacer`. Matrixed: Arabic runs materially longer than
/// English and 200% is where the two clamps stop coexisting.
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
///
/// The CTA swaps to "Saving…" and goes inert, and the GPS button goes inert with
/// it — but the search bar does NOT. It has no `isSaving` input at all, so a
/// suggestion tapped while the request is out runs `selectSearchResult` and
/// moves `draftSelection` under a save that was sent with the old one. The user
/// sees the new address in the card and gets the old pair persisted.
@JeebPreview(
  group: 'location',
  name: 'Dropoff · saving',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenSaving() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.dropoffSaving());

/// The save failed — the ONLY error affordance this screen has.
///
/// A floating snackbar over an otherwise unchanged step 2: the pair is intact,
/// the CTA is live again, and four seconds later there is no trace that the
/// delivery was not saved. Fired from a post-frame callback because a cubit that
/// arrives already-failed never triggers `listenWhen`.
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
///
/// The screen returns to exactly the state it was in before the tap; the
/// snackbar is the only thing that says the permission was denied, and it does
/// not offer the "Open Settings" action its copy tells the user to use.
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
///
/// The pair preview finally carries both rows, and the CTA has become a label:
/// it repeats the app-bar title, stays enabled, and `confirmAndContinue()`
/// returns immediately on `done`, so it is a full-width primary button that does
/// nothing.
@JeebPreview(
  group: 'location',
  name: 'Confirmed · both legs saved',
  size: _locationPickerScreenPhoneBox,
)
Widget locationPickerScreenConfirmed() =>
    _locationPickerScreenHosted(LocationPickerScreenFixtures.confirmedPair());

/// The production wiring: `mapPickerLauncher` supplied, so "Use current GPS" and
/// "Pin on map" share one Row — and the Row does not fit a phone.
///
/// Every other preview here hides the map button, which is also what the Screen
/// Catalog entry does, so this is the ONLY place the third affordance is under
/// review. Matrixed because the failure scales with the copy: two `Expanded`
/// buttons, each holding an 18 pt icon, an 8 pt gap, an unclamped label and
/// 16 pt of internal padding, overflow a 390 pt phone by 100 pt and 29 pt in
/// English and by 154 pt and 168 pt in Arabic. The render tests cannot see any
/// of it — `flutter test` renders on an 800 pt-wide surface, where both buttons
/// fit comfortably.
@JeebPreview(
  group: 'location',
  name: 'Pickup · GPS + Pin on map row',
  size: _locationPickerScreenPhoneBox,
  matrix: true,
)
Widget locationPickerScreenMapPinRow() => _locationPickerScreenHostedWithMap(
      LocationPickerScreenFixtures.pickupNoSelection(),
    );
