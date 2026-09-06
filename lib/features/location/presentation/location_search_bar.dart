import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../data/location_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';

class LocationSearchBar extends StatelessWidget {
  const LocationSearchBar({
    super.key,
    required this.hintText,
    required this.query,
    required this.results,
    required this.isSearching,
    required this.onChanged,
    required this.onResultSelected,
    this.controller,
    this.emptyResultsLabel,
    this.failure,
    this.onRetry,
  });

  final String hintText;
  final String query;
  final List<LocationPoint> results;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final ValueChanged<LocationPoint> onResultSelected;
  final TextEditingController? controller;

  final String? emptyResultsLabel;

  /// A failed search. Without this the cubit's `searchFailed` is rendered
  /// nowhere and the bar looks like it simply found nothing.
  final AppFailure? failure;

  /// Re-runs the last query.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final hasQuery = query.trim().isNotEmpty;
    final showResults = hasQuery && (results.isNotEmpty || !isSearching);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `OmdsSearchBar` hardcodes its focus ring to `colorScheme.primary` in
        // the decoration, so app_theme's periwinkle `focusedBorder` never lands.
        Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.secondary,
                ),
          ),
          child: OmdsSearchBar(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
            onClear: () => onChanged(''),
          ),
        ),
        if (isSearching)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Spacing.small),
            child: LinearProgressIndicator(
              minHeight: 2,
              // Was `colorScheme.primary` — #D73B00 under Midnight, i.e. a
              // 2px orange bar for a query nobody has answered yet.
              color: semantic.mutedText,
              backgroundColor: semantic.glassFillPressed,
            ),
          ),
        if (failure != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Spacing.small),
            child: JeebInfoNote.error(
              text: AppLocalizations.of(context).locationSearchFailed,
              identifier: 'location_search_error',
              trailing: onRetry == null
                  ? null
                  : Semantics(
                      identifier: 'location_search_retry_cta',
                      button: true,
                      container: true,
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: AppLocalizations.of(context).actionRetry,
                        onPressed: onRetry,
                      ),
                    ),
            ),
          ),
        if (showResults)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Spacing.small),
            child: JeebOutlinedCard(
              padding: EdgeInsetsDirectional.zero,
              child: _ResultsList(
                results: results,
                emptyLabel: emptyResultsLabel,
                onSelected: onResultSelected,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.emptyLabel,
    required this.onSelected,
  });

  final List<LocationPoint> results;
  final String? emptyLabel;
  final ValueChanged<LocationPoint> onSelected;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    if (results.isEmpty) {
      // One row inside a dropdown, so no §2.7 block fits; the Material type
      // scale is what the M4 sweep replaces here.
      return Semantics(
        identifier: 'location_search_empty',
        container: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(Spacing.medium),
          child: Text(
            emptyLabel ?? AppLocalizations.of(context).locationSearchEmpty,
            style: context.jeebText.body.copyWith(color: semantic.mutedText),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.zero,
      itemCount: results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: semantic.glassBorder,
      ),
      itemBuilder: (context, index) {
        final point = results[index];
        return _ResultTile(
          point: point,
          onTap: () => onSelected(point),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.point, required this.onTap});

  final LocationPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Row(
          children: [
            // Was `colorScheme.primary`: an orange pin on every result row.
            Icon(Icons.place_outlined, color: semantic.mutedText, size: 20),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                point.address ?? '${point.latitude}, ${point.longitude}',
                style: context.jeebText.body.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

/// A bar with no dropdown, plus a slice of the card below it.
const Size _locationSearchBarBox = Size(390, 240);

/// Room for a two-row dropdown.
const Size _locationSearchBarShortListBox = Size(390, 320);

/// Room for the five-row dropdown plus the card it pushes down.
const Size _locationSearchBarListBox = Size(390, 460);

/// Marks the stand-in for the draft card that sits under the bar on the picker
/// screen. The render test measures its top edge: how far the dropdown pushed
const Key locationSearchBarPreviewCardKey =
    Key('location-search-bar-preview-card');

class _LocationSearchBarDraftCardStandIn extends StatelessWidget {
  const _LocationSearchBarDraftCardStandIn({required this.fixture});

  /// Which triple fed the bar — `nothing typed`, `no matches`, … Rendered so a
  /// preview wired to the wrong fixture fails the render test instead of
  final String fixture;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: locationSearchBarPreviewCardKey,
      width: double.infinity,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(Spacing.small),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.uiMedium,
      ),
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

class _LocationSearchBarHost extends StatefulWidget {
  const _LocationSearchBarHost({
    super.key,
    required this.fixture,
    required this.query,
    required this.results,
    required this.isSearching,
  });

  final String fixture;
  final String query;
  final List<LocationPoint> results;
  final bool isSearching;

  @override
  State<_LocationSearchBarHost> createState() => _LocationSearchBarHostState();
}

class _LocationSearchBarHostState extends State<_LocationSearchBarHost> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);
  late String _query = widget.query;
  late List<LocationPoint> _results = widget.results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The cubit's `selectSearchResult`, reproduced: commit the point, clear the
  /// list, and put its address in the query. The bar's reaction to that exact
  void _onResultSelected(LocationPoint point) {
    setState(() {
      _query = point.address ?? _query;
      _controller.text = _query;
      _results = const <LocationPoint>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LocationSearchBar(
            controller: _controller,
            // Resolved from the ambient localizations rather than passed as a
            hintText: l10n.locationSearchHint,
            emptyResultsLabel: l10n.locationSearchEmpty,
            query: _query,
            results: _results,
            isSearching: widget.isSearching,
            onChanged: (String value) => setState(() => _query = value),
            onResultSelected: _onResultSelected,
          ),
          const SizedBox(height: Spacing.medium),
          Expanded(child: _LocationSearchBarDraftCardStandIn(fixture: widget.fixture)),
        ],
      ),
    );
  }
}

Widget _locationSearchBarHosted({
  required String fixture,
  String query = '',
  List<LocationPoint> results = const <LocationPoint>[],
  bool isSearching = false,
}) =>
    _LocationSearchBarHost(
      // Keyed by fixture so pumping a second preview into the same tester
      key: ValueKey<String>(fixture),
      fixture: fixture,
      query: query,
      results: results,
      isSearching: isSearching,
    );

/// The five Beirut addresses `InMemoryLocationRepository` serves — the catalogue
/// production actually searches until the gateway endpoints land, reused so the
const LocationPoint _locationSearchBarDowntown = LocationPoint(
  latitude: 33.8938,
  longitude: 35.5018,
  address: 'Downtown, Beirut',
);
const LocationPoint _locationSearchBarHamra = LocationPoint(
  latitude: 33.8889,
  longitude: 35.4955,
  address: 'Hamra Street, Beirut',
);
const LocationPoint _locationSearchBarGemmayze = LocationPoint(
  latitude: 33.8869,
  longitude: 35.5131,
  address: 'Gemmayze, Beirut',
);
const LocationPoint _locationSearchBarAchrafieh = LocationPoint(
  latitude: 33.8703,
  longitude: 35.5380,
  address: 'Achrafieh, Beirut',
);
const LocationPoint _locationSearchBarVerdun = LocationPoint(
  latitude: 33.9081,
  longitude: 35.4806,
  address: 'Verdun, Beirut',
);

@JeebPreview(group: 'location', name: 'Idle · nothing typed', size: _locationSearchBarBox)
Widget locationSearchBarIdle() => _locationSearchBarHosted(fixture: 'nothing typed');

@JeebPreview(group: 'location', name: 'Searching · nothing to list', size: _locationSearchBarBox)
Widget locationSearchBarSearching() => _locationSearchBarHosted(
      fixture: 'searching, nothing yet',
      query: 'ham',
      isSearching: true,
    );

@JeebPreview(
  group: 'location',
  name: 'Five matches',
  size: _locationSearchBarListBox,
  matrix: true,
)
Widget locationSearchBarResults() => _locationSearchBarHosted(
      fixture: 'five matches',
      query: 'beirut',
      results: const <LocationPoint>[
        _locationSearchBarDowntown,
        _locationSearchBarHamra,
        _locationSearchBarGemmayze,
        _locationSearchBarAchrafieh,
        _locationSearchBarVerdun,
      ],
    );

@JeebPreview(group: 'location', name: 'No matches', size: _locationSearchBarBox)
Widget locationSearchBarNoMatches() => _locationSearchBarHosted(
      fixture: 'no matches',
      query: 'atlantis',
    );

@JeebPreview(
  group: 'location',
  name: 'Just selected · false empty state',
  size: _locationSearchBarBox,
)
Widget locationSearchBarJustSelected() => _locationSearchBarHosted(
      fixture: 'just selected downtown',
      query: 'Downtown, Beirut',
    );

@JeebPreview(
  group: 'location',
  name: 'Long address + coordinates only',
  size: _locationSearchBarShortListBox,
  matrix: true,
)
Widget locationSearchBarLongAndCoordinateOnly() => _locationSearchBarHosted(
      fixture: 'long + coordinate-only',
      query: 'beirut souks',
      results: const <LocationPoint>[
        LocationPoint(
          latitude: 33.8975,
          longitude: 35.5062,
          address: 'Beirut Souks — Parking Level B2, '
              'Weygand Street, Downtown Beirut',
        ),
        LocationPoint(latitude: 33.8938, longitude: 35.5018),
      ],
    );
