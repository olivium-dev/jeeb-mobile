import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';

/// The "Location" section row on the Request type screen (Figma 56535:2392):
/// a start-aligned "Current Location" label and an end-aligned "Change
/// Location" text action with a trailing chevron. The action area is the tap
/// target and navigates to the location picker.
class RequestLocationRow extends StatelessWidget {
  const RequestLocationRow({
    super.key,
    required this.currentLabel,
    required this.changeLabel,
    required this.onChange,
  });

  final String currentLabel;
  final String changeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    // `explicitChildNodes` makes this row a Semantics *boundary*: without it the
    // ambient merge folds the label's `request_type_current_location_label` and
    // the action's `request_type_change_location_button` into one node and the
    // button identifier is swallowed (Maestro/screen-reader can't address it).
    // The boundary keeps both inner identifiers as their own queryable nodes.
    return Semantics(
      explicitChildNodes: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: _CurrentLabel(text: currentLabel)),
          const SizedBox(width: Spacing.medium),
          _ChangeAction(label: changeLabel, onTap: onChange),
        ],
      ),
    );
  }
}

class _CurrentLabel extends StatelessWidget {
  const _CurrentLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'request_type_current_location_label',
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ChangeAction extends StatelessWidget {
  const _ChangeAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_type_change_location_button',
      button: true,
      label: label,
      child: InkWell(
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: onTap,
        child: _ActionContent(label: label),
      ),
    );
  }
}

class _ActionContent extends StatelessWidget {
  const _ActionContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: scheme.primary);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xSmall,
        vertical: Spacing.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: Spacing.twoXSmall),
          Icon(DirectionalIcons.disclosure(context),
              size: Sizes.large, color: scheme.primary),
        ],
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
// Render tests: test/previews/request_type/request_location_row_preview_test.dart
// ===========================================================================

// Widget previews for [RequestLocationRow] — run with
// `flutter widget-preview start`.
//
// The row takes no repository and no cubit: its whole surface is two strings
// and a tap callback, so these previews are network-free by construction and
// need no fixture beyond the strings themselves.
//
// Production (`_LocationSection` in `request_type_screen.dart`) always feeds it
// the localized pair `requestTypeCurrentLocation` / `requestTypeChangeLocation`,
// so the default preview resolves the SAME keys through a [Builder] rather than
// hardcoding English — otherwise the AR RTL rendering of the matrix would show
// English text and prove nothing about Arabic.
//
// The remaining states push the one dimension the row cannot control: label
// length. `_CurrentLabel` is wrapped in a [Flexible] with
// `TextOverflow.ellipsis`, i.e. it is explicitly built for a label longer than
// the box; `_ChangeAction` is NOT flexible and takes whatever intrinsic width
// it wants first. Those two facts together are what the long-content previews
// below are for.

/// A list row: full phone width, and tall enough for the 200%-text rendering.
/// The row measures 44pt at 1x and 64pt at 2x, so 88 leaves headroom without
/// padding the canvas with dead space.
const Size _requestLocationRowBox = Size(390, 88);

/// Builds the row the way `_LocationSection` does.
///
/// Both labels default to the real ARB values for the current locale; pass an
/// override to exercise content the static keys can't produce.
Widget _requestLocationRowHosted({String? currentLabel, String? changeLabel}) =>
    Builder(
      builder: (BuildContext context) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        return RequestLocationRow(
          currentLabel: currentLabel ?? l10n.requestTypeCurrentLocation,
          changeLabel: changeLabel ?? l10n.requestTypeChangeLocation,
          onChange: () {},
        );
      },
    );

/// The only state production actually renders (Figma 56535:2392): both labels
/// come from the ARB, so this is also the state that proves the row is
/// localized end to end.
///
/// The AR RTL rendering is the one to look at — the label must sit on the
/// right, the action on the left, and `DirectionalIcons.disclosure` must flip
/// the chevron to point left. A hardcoded `Icons.chevron_right` would be
/// invisible here in English and wrong in Arabic.
///
/// The 200% rendering is not decoration either: the label needs ~233pt at that
/// scale and the row hands it 106, so even the static ARB pair truncates.
@JeebPreview(
  group: 'request_type',
  name: 'Localized default',
  size: _requestLocationRowBox,
)
Widget requestLocationRowDefault() => _requestLocationRowHosted();

/// The label slot holding a real place instead of the static placeholder.
///
/// Short enough to still fit beside the action on a 390pt phone — this is the
/// baseline the long-content previews below are measured against.
@JeebPreview(
  group: 'request_type',
  name: 'Resolved address',
  size: _requestLocationRowBox,
)
Widget requestLocationRowResolvedAddress() =>
    _requestLocationRowHosted(currentLabel: 'Hamra St, Beirut');

/// Layout ceiling: the longest plausible geocoded address.
///
/// `_CurrentLabel` sets `overflow: TextOverflow.ellipsis` and leaves `maxLines`
/// null. That combination truncates to a single line rather than wrapping, so
/// the row must stay 44pt tall here — same as 'Localized default'. If this
/// preview ever renders two lines, the row has started pushing the rest of the
/// Request-type screen down, and `maxLines: 1` is the missing guard.
@JeebPreview(
  group: 'request_type',
  name: 'Long address',
  size: _requestLocationRowBox,
)
Widget requestLocationRowLongAddress() => _requestLocationRowHosted(
      currentLabel:
          'Beirut Central District, Bloc B, Building 27, Floor 4, Apartment 12',
    );

/// The action side growing instead of the label side.
///
/// `_ChangeAction` is not wrapped in [Flexible], so it claims its full
/// intrinsic width first and the [Flexible] label absorbs 100% of the
/// shortfall. Measured at 390pt with the real Inter face: at 200% text this
/// label is squeezed to 16pt — the ellipsis and nothing else, i.e. the
/// current-location text vanishes while the action keeps every pixel it asked
/// for. The 200% rendering of THIS preview is the one to look at; the 1x
/// rendering still looks fine.
@JeebPreview(
  group: 'request_type',
  name: 'Long action label',
  size: _requestLocationRowBox,
)
Widget requestLocationRowLongAction() =>
    _requestLocationRowHosted(changeLabel: 'Change pickup location');

/// A label with no break opportunity — a plus code / raw coordinate token,
/// which is exactly what a reverse geocode returns when it cannot name a place.
///
/// Wrapping cannot help here, so this is the one long-content state that must
/// genuinely ellipsize. If it paints past the trailing edge instead, the row
/// has no horizontal guard at all.
@JeebPreview(
  group: 'request_type',
  name: 'Unbreakable token',
  size: _requestLocationRowBox,
)
Widget requestLocationRowUnbreakableToken() => _requestLocationRowHosted(
      currentLabel: '8G4Q+X9R,BeirutCentralDistrict,Lebanon',
    );
