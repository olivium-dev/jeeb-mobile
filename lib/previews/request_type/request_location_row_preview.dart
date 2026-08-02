/// Widget previews for [RequestLocationRow] — run with
/// `flutter widget-preview start`.
///
/// The row takes no repository and no cubit: its whole surface is two strings
/// and a tap callback, so these previews are network-free by construction and
/// need no fixture beyond the strings themselves.
///
/// Production (`_LocationSection` in `request_type_screen.dart`) always feeds it
/// the localized pair `requestTypeCurrentLocation` / `requestTypeChangeLocation`,
/// so the default preview resolves the SAME keys through a [Builder] rather than
/// hardcoding English — otherwise the AR RTL rendering of the matrix would show
/// English text and prove nothing about Arabic.
///
/// The remaining states push the one dimension the row cannot control: label
/// length. `_CurrentLabel` is wrapped in a [Flexible] with
/// `TextOverflow.ellipsis`, i.e. it is explicitly built for a label longer than
/// the box; `_ChangeAction` is NOT flexible and takes whatever intrinsic width
/// it wants first. Those two facts together are what the long-content previews
/// below are for.
library;

import 'package:flutter/material.dart';

import '../../features/request_type/presentation/request_location_row.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// A list row: full phone width, and tall enough for the 200%-text rendering.
/// The row measures 44pt at 1x and 64pt at 2x, so 88 leaves headroom without
/// padding the canvas with dead space.
const Size _rowBox = Size(390, 88);

/// Builds the row the way `_LocationSection` does.
///
/// Both labels default to the real ARB values for the current locale; pass an
/// override to exercise content the static keys can't produce.
Widget _hosted({String? currentLabel, String? changeLabel}) => Builder(
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
@JeebPreview(name: 'Localized default', size: _rowBox)
Widget requestLocationRowDefault() => _hosted();

/// The label slot holding a real place instead of the static placeholder.
///
/// Short enough to still fit beside the action on a 390pt phone — this is the
/// baseline the long-content previews below are measured against.
@JeebPreview(name: 'Resolved address', size: _rowBox)
Widget requestLocationRowResolvedAddress() =>
    _hosted(currentLabel: 'Hamra St, Beirut');

/// Layout ceiling: the longest plausible geocoded address.
///
/// `_CurrentLabel` sets `overflow: TextOverflow.ellipsis` and leaves `maxLines`
/// null. That combination truncates to a single line rather than wrapping, so
/// the row must stay 44pt tall here — same as 'Localized default'. If this
/// preview ever renders two lines, the row has started pushing the rest of the
/// Request-type screen down, and `maxLines: 1` is the missing guard.
@JeebPreview(name: 'Long address', size: _rowBox)
Widget requestLocationRowLongAddress() => _hosted(
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
@JeebPreview(name: 'Long action label', size: _rowBox)
Widget requestLocationRowLongAction() =>
    _hosted(changeLabel: 'Change pickup location');

/// A label with no break opportunity — a plus code / raw coordinate token,
/// which is exactly what a reverse geocode returns when it cannot name a place.
///
/// Wrapping cannot help here, so this is the one long-content state that must
/// genuinely ellipsize. If it paints past the trailing edge instead, the row
/// has no horizontal guard at all.
@JeebPreview(name: 'Unbreakable token', size: _rowBox)
Widget requestLocationRowUnbreakableToken() =>
    _hosted(currentLabel: '8G4Q+X9R,BeirutCentralDistrict,Lebanon');
