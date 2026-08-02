/// Widget previews for [RequestTierCard] — run with
/// `flutter widget-preview start`.
///
/// The card is one row of the five-tier list on `request-type-selection`
/// (Figma 56535:2392). It is pure presentation: every string, the icon and the
/// `selected` flag are passed in by `RequestTypeScreen`, and the tap callback is
/// the caller's. **No cubit, no repository, nothing to seed** — these previews
/// are network-free by construction, and the guard in [jeebPreviewHost] never
/// has anything to reject.
///
/// **Every state here is a `selected` flag times a copy length.** That is the
/// whole surface: `selected` swaps the fill (`primary` → white ink) for the
/// unselected pair (`surface` + `outlineVariant` border + periwinkle
/// `onSecondaryContainer` description), and copy length decides whether the
/// title's `Flexible` wraps and how tall the card grows.
///
/// **Where the copy comes from.** Four states read the ARB through the same
/// `tier*` keys `RequestTypeScreen` uses, so the AR rendering of the matrix
/// reviews the shipping Arabic rather than English sitting in an RTL box. Only
/// [requestTierCardLongCopy] carries fixture copy, and it has to: the title is
/// the ONE constrained `Text` in this widget (`Flexible`), and not one of the
/// five shipping tier names is long enough to reach it, so its wrap branch is
/// unexercised by production copy.
///
/// **What to look at.**
/// * Unselected, light: the two description lines are `onSecondaryContainer`
///   (#777FC0) on white — 3.76:1, under the 4.5:1 AA floor for `bodySmall`.
///   Pinned in `test/previews/request_type/request_tier_card_preview_test.dart`.
/// * 200%: the leading glyph is a raw `Icon(size: Sizes.large)` and the radio is
///   a raw `SizedBox.square(Sizes.xLarge)`, so both stay put while the copy they
///   sit beside doubles.
/// * AR: the digits + en-dash in the Eco speed line ("24–48") are the one place
///   in this card where a Latin range is embedded in Arabic text.
///
/// One defect the canvas CANNOT show you, so it is pinned in the test instead:
/// the card's `Semantics` node advertises `button` + a checked state and then
/// `ExcludeSemantics` strips the `InkWell` under it, leaving a control with zero
/// semantics actions.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/location/presentation/widgets/delivery_create_layout.dart';
import '../../features/request_type/presentation/request_tier_card.dart';
import '../../features/request_type/presentation/request_type_radio_id.dart';
import '../../features/tier_selection/domain/tier.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// Canvas boxes, in a 390 dp phone width. Inside [_pageInset] that leaves the
/// card its production 350 dp, so its copy wraps where the app wraps it — not at
/// the 800 dp a default test surface would give it.
///
/// The heights are the **200% rendering's**, not the 100% one's: one box serves
/// all three renderings of the matrix, and this card grows instead of clipping
/// (in the app it is a `ListView` child). A box sized for the English light
/// reading would render the accessibility one as a stripe of overflow paint,
/// which tells you nothing about the widget. Measured ceilings are 358 / 430 /
/// 702 dp respectively, all in EN — Arabic runs ~20% shorter here.
const Size _shortCopyBox = Size(390, 370);
const Size _longestShippingCopyBox = Size(390, 440);
const Size _longCopyBox = Size(390, 720);

/// What surrounds ONE card in the tier list: the page's horizontal inset
/// ([DeliveryCreateLayout.pagePadding] is 20 dp each side) and, vertically, the
/// `Spacing.small` gap `_TierList` puts between two cards. The page padding's
/// own 16/32 dp of top and bottom belong to the whole list, not to a card, so
/// spending them here would only shrink the canvas.
const EdgeInsetsDirectional _pageInset = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.large,
  vertical: Spacing.small,
);

/// Mounts the card the way `_TierList` does: the page inset, full-bleed width,
/// and a shrink-wrapping column.
///
/// `mainAxisSize: MainAxisSize.min` is load-bearing. In the app the card sits in
/// a `ListView`, so it is measured against an unbounded height and takes its
/// intrinsic one. Dropped straight into the preview host's `Scaffold` a default
/// (`max`) column would stretch to the canvas and re-centre the radio glyph
/// against a height the app never draws.
Widget _hosted({
  required IconData icon,
  required String title,
  required String speed,
  required String value,
  required bool selected,
  required String semanticIdentifier,
  required String semanticLabel,
  required String selectedHint,
}) {
  return Padding(
    padding: _pageInset,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RequestTierCard(
          icon: icon,
          title: title,
          speed: speed,
          value: value,
          selected: selected,
          semanticIdentifier: semanticIdentifier,
          semanticLabel: semanticLabel,
          selectedHint: selectedHint,
          // Selection is the screen's cubit to own; the card only reports the
          // tap. A no-op here is the honest fixture — a preview that toggled
          // itself would be previewing a widget this one is not.
          onTap: () {},
        ),
      ],
    ),
  );
}

/// Reads the ARB the way `_TierEntry` does, so a localized state's AR rendering
/// is a real review of the Arabic copy.
Widget _localized(Widget Function(AppLocalizations l10n) build) =>
    Builder(builder: (BuildContext ctx) => build(AppLocalizations.of(ctx)));

/// Builds a shipping tier from its ARB copy, id and semantics, exactly as
/// `_TierEntry` assembles it — including [requestTypeRadioId], so the ids the
/// Maestro create-flow asserts are visible in the preview's semantics tree.
Widget _tier(
  AppLocalizations l10n, {
  required TierId id,
  required IconData icon,
  required String title,
  required String speed,
  required String value,
  required bool selected,
}) =>
    _hosted(
      icon: icon,
      title: title,
      speed: speed,
      value: value,
      selected: selected,
      semanticIdentifier: requestTypeRadioId(id),
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: title,
        speed: speed,
        value: value,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
    );

/// The resting state: four of the five cards look like this on arrival, before
/// the customer has chosen anything.
///
/// It is also the state that carries the card's accessibility defect. Unselected
/// means the description pair is `onSecondaryContainer` — the Figma periwinkle
/// #777FC0 — over a white `surface`, which measures 3.76:1 against the 4.5:1
/// AA floor that `bodySmall` (12 sp) is held to. The selected sibling below is
/// white-on-navy and measures 17.1:1, so the legibility of the tier copy a
/// customer is comparing depends on whether they have already chosen it.
@JeebPreview(group: 'request_type', name: 'Unselected · Standard', size: _shortCopyBox)
Widget requestTierCardUnselected() => _localized(
      (AppLocalizations l10n) => _tier(
        l10n,
        id: TierId.standard,
        icon: Icons.balance_outlined,
        title: l10n.tierStandardTitle,
        speed: l10n.tierStandardSpeed,
        value: l10n.tierStandardValue,
        selected: false,
      ),
    );

/// The chosen tier: navy fill, white ink, and the radio glyph's dot filled in.
///
/// Worth pairing with the unselected state in the canvas, because `selected`
/// changes FOUR things at once — `Material.color`, the border colour, the title
/// colour and the description colour — and the only signal that survives a
/// grayscale or colour-blind reading is the 8 dp dot inside the ring.
@JeebPreview(group: 'request_type', name: 'Selected · Flash', size: _shortCopyBox)
Widget requestTierCardSelected() => _localized(
      (AppLocalizations l10n) => _tier(
        l10n,
        id: TierId.flash,
        icon: Icons.bolt_outlined,
        title: l10n.tierFlashTitle,
        speed: l10n.tierFlashSpeed,
        value: l10n.tierFlashValue,
        selected: true,
      ),
    );

/// The longest copy the app actually ships: On-the-Way owns both the longest
/// tier name (and the only hyphenated one) and the longest speed line.
///
/// This is the shipping ceiling for the two UNCONSTRAINED `Text`s — `speed` and
/// `value` are plain children of the copy column with no `maxLines` and no
/// `overflow`, so they wrap and the card grows. At 200% that is where most of
/// the canvas box below goes.
@JeebPreview(group: 'request_type', name: 'Longest shipping copy · On-the-Way',
    size: _longestShippingCopyBox)
Widget requestTierCardLongestShippingCopy() => _localized(
      (AppLocalizations l10n) => _tier(
        l10n,
        id: TierId.onTheWay,
        icon: Icons.handshake_outlined,
        title: l10n.tierOnTheWayTitle,
        speed: l10n.tierOnTheWaySpeed,
        value: l10n.tierOnTheWayValue,
        selected: false,
      ),
    );

/// Selected + a Latin range inside the copy: Eco's speed line is
/// "…24–48 hours", digits and a U+2013 en-dash.
///
/// The AR rendering is the point. Arabic reverses the run direction around that
/// range ("يُوصَّل خلال 24–48 ساعة."), so this is the one card where bidi
/// reordering, not layout, decides whether the number a customer reads is the
/// number ops wrote. Selected so the range is reviewed as white-on-navy, which
/// is how the card looks the moment it becomes the answer to "how long?".
@JeebPreview(group: 'request_type', name: 'Selected · Eco (digit range)', size: _shortCopyBox)
Widget requestTierCardDigitRange() => _localized(
      (AppLocalizations l10n) => _tier(
        l10n,
        id: TierId.eco,
        icon: Icons.eco_outlined,
        title: l10n.tierEcoTitle,
        speed: l10n.tierEcoSpeed,
        value: l10n.tierEcoValue,
        selected: true,
      ),
    );

/// The wrap ceiling — the only state that reaches the title's `Flexible`.
///
/// `title` is the single constrained `Text` in this widget: it shares a `Row`
/// with the leading glyph and is wrapped in `Flexible`, so it is the one string
/// that can wrap against the icon rather than against the card. None of the five
/// shipping names ("Flash" … "On-the-Way") is long enough to get there, so
/// without this state that branch is only ever exercised in production.
///
/// Fixture copy, deliberately: the tier catalogue is served (`GET /v1/tiers`)
/// and its marketing copy is ops-authored, so a longer tier is a product
/// decision away — and Arabic titles run longer than their English sources at
/// the same meaning. What to look at is the second title line, which wraps
/// UNDER the glyph rather than beside it (the icon is a fixed 20 dp pinned to
/// the row's centre), and the radio glyph, which re-centres against a card three
/// times the height of the shipping one.
@JeebPreview(group: 'request_type', name: 'Longest plausible copy · unreleased tier',
    size: _longCopyBox)
Widget requestTierCardLongCopy() => _hosted(
      icon: Icons.local_shipping_outlined,
      title: 'Scheduled Overnight Freight',
      speed: 'Collected after 8 PM and delivered before the shops open '
          'tomorrow morning.',
      value: 'Lowest price per kilogram • Ground-floor drop-off required',
      selected: false,
      semanticIdentifier: 'request_type_overnight_radio',
      semanticLabel: 'Scheduled Overnight Freight. Collected after 8 PM and '
          'delivered before the shops open tomorrow morning. Lowest price per '
          'kilogram • Ground-floor drop-off required.',
      selectedHint: 'Selected',
    );
