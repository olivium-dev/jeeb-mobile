import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
  });

  final String hintText;
  final String query;
  final List<LocationPoint> results;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final ValueChanged<LocationPoint> onResultSelected;
  final TextEditingController? controller;

  final String? emptyResultsLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = query.trim().isNotEmpty;
    final showResults = hasQuery && (results.isNotEmpty || !isSearching);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmdsSearchBar(
          controller: controller,
          hintText: hintText,
          onChanged: onChanged,
          onClear: () => onChanged(''),
        ),
        if (isSearching)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        if (showResults)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: Material(
              color: colorScheme.surfaceContainerLowest,
              elevation: 1,
              borderRadius: OmdsBorderRadius.uiMedium,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Text(
          emptyLabel ?? 'No matches',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: colorScheme.outlineVariant,
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
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                point.address ?? '${point.latitude}, ${point.longitude}',
                style: textTheme.bodyMedium?.copyWith(
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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/location_search_bar_preview_test.dart
// ===========================================================================
// Widget previews for [LocationSearchBar] — run with
// `flutter widget-preview start`.
//
// The bar is pure presentation: eight constructor arguments, no cubit, no
// repository, no plugin. So these previews are network-free by construction —
// nothing here can reach Dio even before [jeebPreviewHost] installs its guard —
// and every state below is just a `(query, results, isSearching)` triple. Each
// triple is one the production cubit actually emits; the states are named after
// the [LocationPickerCubit] transition that produces them.
//
// Two things shape the file:
//
// * **`query` does not fill the field.** [OmdsSearchBar] renders whatever its
//   `controller` holds, and `query` only decides whether the dropdown is shown.
//   `LocationPickerScreen` keeps the two in step by hand, from a `BlocListener`
//   (`location_picker_screen.dart:117`). Every preview therefore seeds a
//   controller with the same text it passes as `query` — that is what the
//   screen does, and a preview that passed only `query` would draw an empty
//   field with a populated dropdown hanging under it.
// * **The dropdown is a Column child, not an overlay.** It pushes whatever sits
//   below the bar down the screen. That is only visible against something, so
//   each preview is composed the way the picker screen composes it — bar, gap,
//   then the draft card — using [_LocationSearchBarDraftCardStandIn], a fixture that is NOT
//   production code. It names the triple that fed the bar, which is also what
//   the render test pins: four of these six states differ only in a string, and
//   a preview wired to the wrong fixture would otherwise look plausible.
//
// Three things these previews surfaced, all in the widget rather than in the
// previews:
//
//  * selecting a suggestion leaves the bar reading **"No matching addresses"**
//    under the address the user just picked — see
//    [locationSearchBarJustSelected];
//  * a search that FAILED renders identically to a search that found nothing,
//    because the cubit's error goes to a transient snackbar and the bar is
//    handed the same empty list either way;
//  * a result with no resolved address falls back to raw `lat, lng` with no
//    `textDirection`, so in Arabic the two coordinates swap places on screen —
//    see [locationSearchBarLongAndCoordinateOnly].

/// A bar with no dropdown, plus a slice of the card below it.
const Size _locationSearchBarBox = Size(390, 240);

/// Room for a two-row dropdown.
const Size _locationSearchBarShortListBox = Size(390, 320);

/// Room for the five-row dropdown plus the card it pushes down.
const Size _locationSearchBarListBox = Size(390, 460);

/// Marks the stand-in for the draft card that sits under the bar on the picker
/// screen. The render test measures its top edge: how far the dropdown pushed
/// the rest of the screen down is the whole point of an inline results list, and
/// it is the only way a test can tell "dropdown open" from "dropdown closed".
const Key locationSearchBarPreviewCardKey =
    Key('location-search-bar-preview-card');

/// Stand-in for the `_DraftPreviewCard` the bar sits above (fixture, not
/// production code).
///
/// Fills whatever the bar and its dropdown left over, and names the
/// `(query, results, isSearching)` triple that produced the state, so the four
/// dropdown-less previews are distinguishable on screen and in the render test.
class _LocationSearchBarDraftCardStandIn extends StatelessWidget {
  const _LocationSearchBarDraftCardStandIn({required this.fixture});

  /// Which triple fed the bar — `nothing typed`, `no matches`, … Rendered so a
  /// preview wired to the wrong fixture fails the render test instead of
  /// looking plausible in the canvas.
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

/// Hosts the bar the way `LocationPickerScreen` hosts it: 16 pt page padding,
/// bar at the top, draft card below, dropdown free to push that card down.
///
/// Stateful for two reasons. It owns (and disposes) the [TextEditingController]
/// the bar needs to show typed text at all, and it mirrors `onChanged` back into
/// `query` — which is what the cubit does — so the canvas stays live: typing
/// keeps the dropdown up, and the clear button collapses it.
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
  /// trio is [locationSearchBarJustSelected].
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
            // literal, so the AR rendering shows the Arabic hint and the Arabic
            // empty-state line the screen really passes.
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
      // builds a fresh State instead of reusing the first one's controller.
      key: ValueKey<String>(fixture),
      fixture: fixture,
      query: query,
      results: results,
      isSearching: isSearching,
    );

/// The five Beirut addresses `InMemoryLocationRepository` serves — the catalogue
/// production actually searches until the gateway endpoints land, reused so the
/// canvas and the cubit tests talk about the same city.
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

/// Cold open: the field is empty, so nothing is shown below it.
///
/// The baseline, and the only state where the hint carries the whole message.
/// Two things to read here rather than in the busier states: the hint is
/// localized (the AR rendering must not say "Search for a place or address"),
/// and the bar is a hard 48 pt tall — [OmdsSearchBar] wraps its `TextField` in
/// `SizedBox(height: UIConstants.textFieldHeight)`, which does not respond to
/// the user's text-size setting. At 200% the hint is what runs out of room
/// first.
@JeebPreview(group: 'location', name: 'Idle · nothing typed', size: _locationSearchBarBox)
Widget locationSearchBarIdle() => _locationSearchBarHosted(fixture: 'nothing typed');

/// First keystrokes: `searchAddress('ham')` has set `isSearching`, the debounce
/// has not fired yet, and there is nothing to list.
///
/// All the user gets is a 2 pt progress line under the field — no skeleton rows,
/// no "searching…", and the dropdown stays shut, because `showResults` needs
/// either results or a finished search. On a slow link this is a bar that looks
/// idle while a request is in flight.
///
/// This is the COLD case. The same `isSearching` flag also flies with the
/// previous query's results still in `state.searchResults` — the cubit's
/// `searchAddress` does not clear them — in which case the same 2 pt line sits
/// over a stale, fully tappable list.
@JeebPreview(group: 'location', name: 'Searching · nothing to list', size: _locationSearchBarBox)
Widget locationSearchBarSearching() => _locationSearchBarHosted(
      fixture: 'searching, nothing yet',
      query: 'ham',
      isSearching: true,
    );

/// The happy path: the full Beirut catalogue as one dropdown.
///
/// Matrixed because this is the state where the three renderings disagree. The
/// row is `icon → address`, so the AR rendering is where the pin has to move to
/// the trailing edge; and the 200% rendering is where five rows stop fitting —
/// measured in this box, they leave 28 pt of the 128 pt the draft card had.
/// `_ResultsList` is `shrinkWrap: true` with `NeverScrollableScrollPhysics`, so
/// it takes the height its rows want and cannot be scrolled to give any of it
/// back; here the card is `Expanded` and merely shrinks, but the picker screen's
/// Column has nothing flexible in it.
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

/// A query nothing matched: the empty-results line, in its own card.
///
/// It is deliberately hidden while the query is empty (so a user who has typed
/// nothing is not told they matched nothing) — compare [locationSearchBarIdle],
/// which is the same widget with one field different.
///
/// This is also what a FAILED search looks like. `_runSearch` catches, emits
/// `LocationPickerError.searchFailed`, and leaves `searchResults` alone; the
/// screen turns that into a snackbar that fades, and the bar — handed the same
/// empty list either way — keeps saying "No matching addresses" long after the
/// snackbar is gone. If this preview ever stops being reachable from a network
/// error, the bar has grown a way to say "we could not search".
@JeebPreview(group: 'location', name: 'No matches', size: _locationSearchBarBox)
Widget locationSearchBarNoMatches() => _locationSearchBarHosted(
      fixture: 'no matches',
      query: 'atlantis',
    );

/// The frame after the user taps a suggestion — and a bug you can see.
///
/// `selectSearchResult` commits the point, clears `searchResults`, and copies
/// the address into `searchQuery`; the screen's listener copies that into the
/// field. The bar is then holding a non-empty query, an empty list and
/// `isSearching: false`, which is precisely the [locationSearchBarNoMatches]
/// triple — so it renders **"No matching addresses"** directly under the address
/// the user just chose. Nothing failed and nothing is missing; the empty-state
/// line simply has no way to tell "you picked this" from "there was nothing".
@JeebPreview(
  group: 'location',
  name: 'Just selected · false empty state',
  size: _locationSearchBarBox,
)
Widget locationSearchBarJustSelected() => _locationSearchBarHosted(
      fixture: 'just selected downtown',
      query: 'Downtown, Beirut',
    );

/// The two ends of one row: an address longer than the bar, and a result with no
/// address at all.
///
/// The long one is a real Beirut Souks parking address; `_ResultTile` sets
/// `maxLines: 1` + `TextOverflow.ellipsis`, so this is where you check the
/// ellipsis lands inside the card and not under the pin icon — and, at 200%,
/// whether one line is still enough to identify an address.
///
/// The second row has `address: null`, which the tile renders as raw
/// `'${latitude}, ${longitude}'`. Two problems, both visible here: a user is
/// being offered "33.8938, 35.5018" as something to choose, and that string
/// carries no `textDirection`, so in the AR rendering bidi reorders it and the
/// longitude is drawn FIRST. Matrixed for exactly that comparison.
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
