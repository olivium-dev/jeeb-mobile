import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';




class DeliveryManMetaRow extends StatelessWidget {
  const DeliveryManMetaRow({
    super.key,
    required this.icon,
    required this.text,
    required this.semanticsId,
  });

  final IconData icon;
  final String text;
  final String semanticsId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    
    
    
    
    
    return Semantics(
      identifier: semanticsId,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: theme.colorScheme.primary),
          const SizedBox(width: Spacing.xSmall),
          Flexible(child: _MetaText(text: text)),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
      overflow: TextOverflow.ellipsis,
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
// Render tests: test/previews/delivery_man_profile/delivery_man_meta_row_preview_test.dart
// ===========================================================================

// Widget previews for [DeliveryManMetaRow] — run with
// `flutter widget-preview start`.
//
// The widget has no cubit, no repository and no async seam: it is an
// [IconData], a [String] and a semantics id turned into one [Icon] and one
// [Text]. So there is no "loading" or "error" state to seed, and these
// previews are network-free because there is nothing to fetch, not merely
// because [jeebPreviewHost] guards the wire.
//
// Its real states are its three call sites in `DeliveryManProfileHeader`
// (`_RatingRow` cold / warm, `_AvailabilityRow` with / without a location)
// crossed with the payloads that reach them. Each state resolves its copy
// through [AppLocalizations] exactly the way the header does, rather than
// hardcoding English, so the AR RTL rendering of the matrix reviews the
// Arabic string that actually ships.
//
// The fixture values are the ones the existing tests already use —
// `Kamal Hajj` 4.3 / 113 / `Lebanon` from `test/delivery_man_profile_screen_test.dart`,
// the 3-review cold start from its D59 case, and the empty/`Riyadh` locations
// from `test/features/delivery_man_profile/delivery_man_profile_header_location_test.dart`.
//
// Four things these previews surface, all in the widget rather than in the
// previews — see the notes on the individual states:
//
//  * the label is inked with `onSecondaryContainer` (periwinkle `#777FC0`),
//    which measures **3.76:1 on the white profile surface** and fails WCAG AA
//    for 14sp body text — while the sibling chip rendering the *same* ARB keys
//    (`CustomerProfileRating`) uses the AA-passing `onSurfaceVariant`;
//  * the class doc says the glyph is "brand orange ([ColorScheme.primary] per
//    design §4)", but after the b02 palette audit `primary` is navy `#0B1351`
//    and the brand orange lives on `tertiary` — so the accent glyph the design
//    asks for is not what renders;
//  * the icon is a fixed `Sizes.medium` (16dp) with `applyTextScaling` left at
//    its false default, so at the 200% ceiling a 16dp star sits beside 28sp
//    text and keeps 24pt of a column the text is already truncating out of;
//  * `_MetaText` is a plain [Text], not the `AutoDirectionText` its sibling
//    `_NameText` uses one row above it, so a Latin-script location inside the
//    Arabic UI gets no per-string direction handling.

/// The width the row actually gets inside `DeliveryManProfileHeader` on a 390pt
/// phone: `Spacing.large` gutters on both sides of the header, an
/// `Sizes.nineXLarge` avatar and a `Spacing.small` gap, then the row sits in the
/// `Expanded` details column. `390 - 20 - 20 - 88 - 12 = 250`.
///
/// Pinned in the fixture rather than left to the canvas [Size], for the same
/// reason `customer_profile_rating_preview.dart` pins it: the canvas honours
/// `size`, but the render tests pump onto a fixed 800 × 600 surface, so a row
/// left to fill its host would truncate on the phone and not truncate under
/// test — the state that breaks would break in only one of the two places it is
/// looked at.
///
/// Applied as a `maxWidth`, not a fixed width, because the row is
/// `MainAxisSize.min` and production hands it a loose [Column] constraint.
/// Keeping it loose means the measured width of each preview is the row's own
/// intrinsic width, which is what tells the long states apart from the short.
const double _deliveryManMetaRowMetaWidth = 390 - 2 * Spacing.large - Sizes.nineXLarge -
    Spacing.small;

/// The same column on a 320pt phone (iPhone SE, small Android):
/// `320 - 20 - 20 - 88 - 12 = 180`. Used by the longest state, where the
/// smallest column and the longest location meet.
const double _deliveryManMetaRowSmallMetaWidth = 320 - 2 * Spacing.large - Sizes.nineXLarge -
    Spacing.small;

/// Canvas box for a meta row: phone width, and tall enough for the 200%
/// rendering (a single 28sp line — this label truncates rather than wrapping).
const Size _deliveryManMetaRowBox = Size(390, 88);

/// Renders the row under the constraint the profile header really gives it,
/// leading-aligned the way `CrossAxisAlignment.start` places it in the details
/// column.
///
/// [text] takes the localizations rather than a [String] so each state resolves
/// its copy the way the header does — the AR rendering must review the Arabic
/// string, not an English one transplanted into an RTL frame.
Widget _deliveryManMetaRowHosted({
  required IconData icon,
  required String Function(AppLocalizations) text,
  required String semanticsId,
  double width = _deliveryManMetaRowMetaWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Builder(
          builder: (BuildContext context) => DeliveryManMetaRow(
            icon: icon,
            text: text(AppLocalizations.of(context)),
            semanticsId: semanticsId,
          ),
        ),
      ),
    );

/// The state the widget was written for: an established jeeber with an
/// aggregate score, `_RatingRow`'s warm branch and its `profile_score`
/// identifier — the id `.maestro` and the D59 screen test both key on.
///
/// Look at the separator in the EN light rendering. The screen copy and the
/// semantics test both write this pair as "4.8 (12)" / "·", but the ARB value is
/// `{rating} . {count}` — a full stop with a space either side. What ships reads
/// "4.3 . 113 Reviews", which parses as a sentence break rather than as a
/// separator, and a screen reader announces it as one.
///
/// This is also the control for the truncation the other states hit, and the
/// clearest frame for the contrast defect: 14sp periwinkle `#777FC0` on white
/// is the whole label, not an accent on it.
@JeebPreview(group: 'delivery_man_profile', name: 'Rating summary', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowRatingSummary() => _deliveryManMetaRowHosted(
      icon: Icons.star,
      text: (AppLocalizations l10n) =>
          l10n.deliveryManProfileRatingSummary('4.3', 113),
      semanticsId: 'profile_score',
    );

/// D59 cold start: under five reviews the header hides the aggregate score and
/// shows the count alone, under a different icon and a *different* identifier
/// (`delivery_man_profile_rating_summary`, never `profile_score` — the screen
/// test asserts that absence).
///
/// Worth putting beside [deliveryManMetaRowRatingSummary] in the canvas: the
/// two states are the same row with the same geometry, and nothing but the
/// glyph tells a reviewer that one of them is deliberately withholding a score
/// the payload contains.
@JeebPreview(group: 'delivery_man_profile', name: 'Cold start (D59)', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowColdStart() => _deliveryManMetaRowHosted(
      icon: Icons.reviews_outlined,
      text: (AppLocalizations l10n) => l10n.deliveryManProfileReviewsCount(3),
      semanticsId: 'delivery_man_profile_rating_summary',
    );

/// The empty state, and the one every jeeber ships with on day one: zero
/// reviews (`rating: 0, reviewCount: 0`, the payload
/// `test/delivery_man_profile_screen_test.dart` seeds).
///
/// The row has no empty copy to fall back on, so it renders the count template
/// literally — "0 Reviews", and in Arabic "0 تقييم" with a Western zero inside
/// Arabic script. The sibling `CustomerProfileRating` faces the identical
/// payload and switches to `deliveryManProfileEmptyReviewsTitle` ("No reviews
/// yet"), a key this widget's own feature owns. Two surfaces, one payload, two
/// different answers.
@JeebPreview(group: 'delivery_man_profile', name: 'No reviews yet', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowNoReviews() => _deliveryManMetaRowHosted(
      icon: Icons.reviews_outlined,
      text: (AppLocalizations l10n) => l10n.deliveryManProfileReviewsCount(0),
      semanticsId: 'delivery_man_profile_rating_summary',
    );

/// `_AvailabilityRow`'s joined branch: a location and an availability label
/// through `deliveryManProfileLocationAvailability`.
///
/// The AR RTL rendering is the one to read here. `location` is free text from
/// the gateway and is very often Latin script ("Lebanon", "Bourj Hammoud")
/// even when the UI is Arabic; `_MetaText` is a plain [Text], while the name
/// one row above it in the same header uses `AutoDirectionText` precisely
/// because user-supplied strings need per-string direction. The bidi
/// reordering of `Lebanon . متاح` under an RTL paragraph is what this state
/// puts on screen.
@JeebPreview(group: 'delivery_man_profile', name: 'Location + availability', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowLocationAvailability() => _deliveryManMetaRowHosted(
      icon: Icons.location_on,
      text: (AppLocalizations l10n) =>
          l10n.deliveryManProfileLocationAvailability(
        'Lebanon',
        l10n.deliveryManProfileAvailable,
      ),
      semanticsId: 'delivery_man_profile_availability',
    );

/// F9 regression guard, made visible: a jeeber with no location on file.
///
/// `_AvailabilityRow` drops the template entirely when `location.trim()` is
/// empty, so the row shows the availability label alone. If this preview ever
/// renders a leading " . Unavailable" or "· Unavailable", the guard in
/// `delivery_man_profile_header_location_test.dart` has been undone —
/// the stray separator is the exact defect F9 was filed for.
///
/// Shown in the unavailable variant because that is the pair a fresh,
/// unlocated, offline jeeber actually renders, and because it is the shortest
/// string the row can hold — the floor against which the truncating states are
/// read.
@JeebPreview(group: 'delivery_man_profile', name: 'Availability only (F9)', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowAvailabilityOnly() => _deliveryManMetaRowHosted(
      icon: Icons.location_on,
      text: (AppLocalizations l10n) => l10n.deliveryManProfileUnavailable,
      semanticsId: 'delivery_man_profile_availability',
    );

/// Longest plausible content in the narrowest column: a real two-part Lebanese
/// location on a 320pt phone (180pt of column, 156pt of it left for the text).
///
/// It is ellipsized at the DEFAULT text size, not only at the accessibility
/// ceiling — and because [Text] truncates the end, what is cut is the
/// availability label. The row degrades to a bare place name, so the one fact
/// on it a client acts on ("can this jeeber take my request right now?")
/// silently disappears on a small phone, while the same string clears the 390pt
/// column and looks fine on the reviewer's device.
@JeebPreview(group: 'delivery_man_profile', name: 'Longest location (small phone)', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowLongestLocation() => _deliveryManMetaRowHosted(
      icon: Icons.location_on,
      text: (AppLocalizations l10n) =>
          l10n.deliveryManProfileLocationAvailability(
        'Bourj Hammoud, Mount Lebanon',
        l10n.deliveryManProfileUnavailable,
      ),
      semanticsId: 'delivery_man_profile_availability',
      width: _deliveryManMetaRowSmallMetaWidth,
    );
