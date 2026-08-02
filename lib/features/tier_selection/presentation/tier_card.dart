import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/formatting/money_format.dart';
import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';

/// OMDS-styled selectable card for a single delivery tier.
///
/// Highlights the selected card with the primary container colour + a thicker
/// outline (matching the KYC vehicle grid pattern) and surfaces the
/// recommended badge on the tier the back-office flagged. The card is a
/// full-tap target with `Semantics` so screen readers announce the tier as a
/// button in a list.
class TierCard extends StatelessWidget {
  const TierCard({
    super.key,
    required this.name,
    required this.description,
    required this.estimatedTime,
    required this.priceRange,
    required this.vehicleLabel,
    required this.vehicleIcon,
    required this.selected,
    required this.onTap,
    this.identifier,
    this.recommendedBadgeText,
    this.semanticLabel,
    this.selectedHint,
  });

  /// Stable, screen-scoped accessibility identifier for the whole card tap
  /// target (e.g. `tier_selection_card_flash`). Applied to the card's own
  /// [Semantics] node so QA/maestro can target the tier without depending on
  /// the localized label. Null in generic/preview usages that don't need one.
  final String? identifier;

  /// Localized tier name (Express / Standard / On-the-way).
  final String name;

  /// Localized one-line description shown under the title.
  final String description;

  /// Localized SLA copy (e.g. "≤ 120 min", "≤ 4 hr", "No SLA").
  final String estimatedTime;

  /// Localized price range string (e.g. "45,000 – 70,000 LBP").
  final String priceRange;

  /// Localized vehicle category copy ("Bike / Scooter", "Any vehicle", …).
  final String vehicleLabel;

  /// Icon rendered next to the vehicle label.
  final IconData vehicleIcon;

  final bool selected;
  final VoidCallback onTap;

  /// When non-null, renders the recommended pill in the top-right corner.
  final String? recommendedBadgeText;

  /// Accessibility label for the whole card. When omitted falls back to a
  /// concatenation of the visible strings.
  final String? semanticLabel;

  /// Accessibility hint announced when the card is selected.
  final String? selectedHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background =
        selected ? scheme.primaryContainer : scheme.surfaceContainerLow;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final mutedForeground = selected
        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
        : scheme.onSurfaceVariant;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;

    final cardChild = Material(
      color: background,
      borderRadius: OmdsBorderRadius.medium,
      child: InkWell(
        borderRadius: OmdsBorderRadius.medium,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Spacing.medium),
          decoration: BoxDecoration(
            borderRadius: OmdsBorderRadius.medium,
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                name: name,
                foreground: foreground,
                textTheme: textTheme,
                selected: selected,
                primary: scheme.primary,
                recommendedBadgeText: recommendedBadgeText,
                badgeBackground: scheme.tertiaryContainer,
                badgeForeground: scheme.onTertiaryContainer,
              ),
              const SizedBox(height: Spacing.xSmall),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(color: mutedForeground),
              ),
              const SizedBox(height: Spacing.small),
              _MetaRow(
                icon: Icons.schedule_rounded,
                label: estimatedTime,
                foreground: foreground,
                textTheme: textTheme,
              ),
              const SizedBox(height: Spacing.twoXSmall),
              _MetaRow(
                icon: vehicleIcon,
                label: vehicleLabel,
                foreground: foreground,
                textTheme: textTheme,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                priceRange,
                style: textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel ??
          '$name. $estimatedTime. $vehicleLabel. $priceRange.',
      hint: selected ? selectedHint : null,
      child: cardChild,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.foreground,
    required this.textTheme,
    required this.selected,
    required this.primary,
    required this.recommendedBadgeText,
    required this.badgeBackground,
    required this.badgeForeground,
  });

  final String name;
  final Color foreground;
  final TextTheme textTheme;
  final bool selected;
  final Color primary;
  final String? recommendedBadgeText;
  final Color badgeBackground;
  final Color badgeForeground;

  @override
  Widget build(BuildContext context) {
    final badge = recommendedBadgeText;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: Spacing.xSmall),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.small,
              vertical: Spacing.twoXSmall,
            ),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: OmdsBorderRadius.large,
            ),
            child: Text(
              badge,
              style: textTheme.labelSmall?.copyWith(
                color: badgeForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (selected) ...[
          const SizedBox(width: Spacing.xSmall),
          Icon(Icons.check_circle_rounded, color: primary, size: Sizes.large),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: foreground, size: Sizes.medium),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: foreground),
            overflow: TextOverflow.ellipsis,
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
// Render tests: test/previews/tier_selection/tier_card_preview_test.dart
// ===========================================================================
//
// Widget previews for [TierCard] — run with `flutter widget-preview start`.
//
// The card is one row of the tier list on `/tier-selection`. It is pure
// presentation: every string, both icons and the `selected` flag are passed in
// by `_TierListEntry` in `tier_selection_screen.dart`, and the tap callback is
// the caller's. **No cubit, no repository, nothing to seed** — these previews
// are network-free by construction and the guard in [jeebPreviewHost] never has
// anything to reject.
//
// **The state space is `selected` × `recommendedBadgeText` × copy length.**
// `selected` swaps FOUR things at once (fill `surfaceContainerLow` →
// `primaryContainer`, ink → `onPrimaryContainer`, border `outlineVariant` →
// `primary`, border width 1 → 2) and adds the trailing check; the badge adds a
// second child to the same header `Row`; copy length decides how far the header
// title and the two `_MetaRow` labels get squeezed.
//
// **Where the copy comes from.** Four states read the ARB through the same
// `tierSelection*` keys `_TierListEntry` uses and format their prices through
// the same [MoneyFormat], so the AR rendering of the matrix reviews the
// shipping Arabic (and the LTR-isolated money tokens inside it) rather than
// English sitting in an RTL box. Only [tierCardLongCopy] carries fixture copy,
// and it has to: no shipping tier name, footer or vehicle label is long enough
// to reach any of the three constrained `Text`s in this widget.
//
// **What to look at.**
// * `Recommended + selected` in EN light: the badge pill disappears. Its fill
//   is `tertiaryContainer` and the selected card's fill is `primaryContainer`,
//   and in the light scheme those are the SAME colour (#FFDBD1) — as is its
//   ink against the card's `onPrimaryContainer`. Pinned in
//   `test/previews/tier_selection/tier_card_preview_test.dart`. The AR RTL
//   rendering of the same state is dark, where the seeded scheme separates the
//   two roles, so the matrix shows the broken and the working reading together.
// * Any unselected state: the card is `surfaceContainerLow` (#FAF8FA) inside a
//   white `Scaffold`, hairlined with 1 dp of `outlineVariant` (#E5E1E5). At
//   1.21:1 that boundary is the only thing separating one tappable tier from
//   the next.
// * 200%: both `_MetaRow` glyphs are a raw `Icon(size: Sizes.medium)` and the
//   selected check is `Sizes.large`, so all three stay 16/20 dp while the copy
//   beside them doubles.
// * `Long copy`: every `overflow: TextOverflow.ellipsis` in this widget is
//   inert. None of the three carries `maxLines`, and the card is measured
//   against unbounded height (a `ListView` child in the app, a shrink-wrapping
//   column here), so the title and the meta labels WRAP and grow the card
//   instead of truncating.

/// Canvas boxes at a 390 dp phone width. Inside [_tierCardListInset] that
/// leaves the card its production 350 dp, so its copy wraps where the app wraps
/// it rather than at the 800 dp a default test surface would give it.
///
/// The heights are the **200% rendering's**, not the 100% one's: one box serves
/// all three renderings of a matrix state, and this card grows instead of
/// clipping. A box sized for the English light reading would render the
/// accessibility one as a stripe of overflow paint, which tells you nothing
/// about the widget. Measured ceilings are 584 dp (Express, the shipping footer
/// that wraps furthest) and 944 dp, both in EN — Arabic runs shorter here. The
/// numbers are pinned by a test — see
/// `test/previews/tier_selection/tier_card_preview_test.dart`.
const Size _tierCardShippingCopyBox = Size(390, 600);
const Size _tierCardLongCopyBox = Size(390, 960);

/// What surrounds ONE card in the tier list: the `ListView.separated`'s
/// horizontal [Spacing.large] padding and, vertically, the [Spacing.small]
/// separator between two cards.
const EdgeInsetsDirectional _tierCardListInset =
    EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.large,
  vertical: Spacing.small,
);

/// Every tier in the bundled catalog is priced in Lebanese pounds, which is
/// also the currency that produces the longest money token — `LBP 160,000.00`
/// against `$160.00`. Previewing the short one would hide the wrap.
const String _tierCardCurrency = 'LBP';

/// Mounts the card the way `_LoadedView`'s `ListView` does: the list inset,
/// full-bleed width, and a shrink-wrapping column.
///
/// `mainAxisSize: MainAxisSize.min` is load-bearing. In the app the card is a
/// `ListView` child, so it is measured against an unbounded height and takes
/// its intrinsic one. Dropped straight into the preview host's `Scaffold`, the
/// card's own `Column` (which is `crossAxisAlignment: stretch`, main axis
/// `max`) would stretch to the whole canvas and spread the five rows over a
/// height the app never draws.
Widget _tierCardHosted({
  required String identifier,
  required String name,
  required String description,
  required String estimatedTime,
  required String priceRange,
  required String vehicleLabel,
  required IconData vehicleIcon,
  required bool selected,
  required String semanticLabel,
  required String selectedHint,
  String? recommendedBadgeText,
}) {
  return Padding(
    padding: _tierCardListInset,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TierCard(
          identifier: identifier,
          name: name,
          description: description,
          estimatedTime: estimatedTime,
          priceRange: priceRange,
          vehicleLabel: vehicleLabel,
          vehicleIcon: vehicleIcon,
          selected: selected,
          recommendedBadgeText: recommendedBadgeText,
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

/// Reads the ARB the way `_TierListEntry` does, so a localized state's AR
/// rendering is a real review of the shipping Arabic.
Widget _tierCardLocalized(Widget Function(AppLocalizations l10n) build) =>
    Builder(builder: (BuildContext ctx) => build(AppLocalizations.of(ctx)));

/// The indicative price band, assembled exactly as `_TierListEntry` assembles
/// it: two [MoneyFormat] tokens (each wrapped in a Unicode LTR isolate) joined
/// by the ARB's en-dash pattern.
String _tierCardPriceRange(AppLocalizations l10n, int low, int high) =>
    l10n.tierSelectionPriceRange(
      MoneyFormat.format(low.toDouble(), currency: _tierCardCurrency),
      MoneyFormat.format(high.toDouble(), currency: _tierCardCurrency),
    );

/// Builds one card from a tier's parts the way `_TierListEntry` does —
/// including the `tier_selection_card_<id>` identifier QA targets and the
/// composed semantic label, so the semantics tree in the preview is the one the
/// screen produces.
Widget _tierCardTier(
  AppLocalizations l10n, {
  required String slug,
  required String name,
  required String description,
  required String estimatedTime,
  required String vehicleLabel,
  required IconData vehicleIcon,
  required int priceLow,
  required int priceHigh,
  required bool selected,
  bool recommended = false,
}) {
  final String priceRange = _tierCardPriceRange(l10n, priceLow, priceHigh);
  return _tierCardHosted(
    identifier: 'tier_selection_card_$slug',
    name: name,
    description: description,
    estimatedTime: estimatedTime,
    priceRange: priceRange,
    vehicleLabel: vehicleLabel,
    vehicleIcon: vehicleIcon,
    selected: selected,
    recommendedBadgeText:
        recommended ? l10n.tierSelectionRecommendedBadge : null,
    semanticLabel: l10n.tierSelectionCardSemanticLabel(
      name: name,
      sla: estimatedTime,
      radius: vehicleLabel,
      price: priceRange,
    ),
    selectedHint: l10n.tierSelectionCardSelectedHint,
  );
}

/// The resting state: on arrival every card on the screen looks like this, and
/// four of the five still do after the customer has chosen.
///
/// It is also where the card's weakest signal lives. Unselected means a
/// `surfaceContainerLow` fill (#FAF8FA) on the white `Scaffold` behind it —
/// 1.04:1 — outlined with 1 dp of `outlineVariant` (#E5E1E5) at 1.21:1. WCAG
/// 1.4.11 asks 3:1 of a boundary that identifies a control, and this boundary
/// is the only thing telling a customer where one tappable tier ends and the
/// next begins.
@JeebPreview(
  group: 'tier_selection',
  name: 'Unselected · Standard',
  size: _tierCardShippingCopyBox,
)
Widget tierCardUnselected() => _tierCardLocalized(
      (AppLocalizations l10n) => _tierCardTier(
        l10n,
        slug: 'standard',
        name: l10n.tierSelectionTierStandard,
        description: l10n.tierSelectionFooterStandard,
        estimatedTime: l10n.tierSelectionSlaHours(4),
        vehicleLabel: l10n.tierSelectionVehicleBikeScooter,
        vehicleIcon: Icons.two_wheeler_rounded,
        priceLow: 45000,
        priceHigh: 70000,
        selected: false,
      ),
    );

/// The chosen tier, with no back-office recommendation on it: peach fill, dark
/// ink, a 2 dp navy border and the trailing check.
///
/// Worth reading beside the unselected state above, because `selected` changes
/// the fill, both ink colours, the border colour AND the border width at once —
/// and the only one of those that survives a grayscale or colour-blind reading
/// is the check glyph.
@JeebPreview(
  group: 'tier_selection',
  name: 'Selected · Express',
  size: _tierCardShippingCopyBox,
)
Widget tierCardSelected() => _tierCardLocalized(
      (AppLocalizations l10n) => _tierCardTier(
        l10n,
        slug: 'express',
        name: l10n.tierSelectionTierExpress,
        description: l10n.tierSelectionFooterExpress,
        estimatedTime: l10n.tierSelectionSlaHours(3),
        vehicleLabel: l10n.tierSelectionVehicleScooterCar,
        vehicleIcon: Icons.directions_car_rounded,
        priceLow: 80000,
        priceHigh: 120000,
        selected: true,
      ),
    );

/// The full header: title + recommended pill + check, all in one `Row`.
///
/// Flash is the only tier the catalog ever flags (`recommended: id ==
/// TierId.flash` in `DioTierRepository`), so this is the exact state the screen
/// reaches the moment a customer taps the recommendation — and it is broken in
/// the light scheme. The pill paints `tertiaryContainer` on a card painted
/// `primaryContainer`, and `AppTheme` sets both to #FFDBD1; its ink is
/// `onTertiaryContainer`, which is `onPrimaryContainer`. The badge is therefore
/// invisible on precisely the card it is meant to endorse — the word
/// "Recommended" reads as a stray run of header text.
///
/// `matrix: true` because the AR RTL rendering is DARK, where
/// `ColorScheme.fromSeed` separates the two roles and the pill comes back. The
/// three cards side by side are the shortest proof that this is a light-scheme
/// palette collision and not a layout bug.
@JeebPreview(
  group: 'tier_selection',
  name: 'Recommended + selected · Flash',
  size: _tierCardShippingCopyBox,
  matrix: true,
)
Widget tierCardRecommendedSelected() => _tierCardLocalized(
      (AppLocalizations l10n) => _tierCardTier(
        l10n,
        slug: 'flash',
        name: l10n.tierSelectionTierFlash,
        description: l10n.tierSelectionFooterFlash,
        estimatedTime: l10n.tierSelectionSlaHours(1),
        vehicleLabel: l10n.tierSelectionVehicleScooterCar,
        vehicleIcon: Icons.directions_car_rounded,
        // The widest shipping money token: `LBP 120,000.00 – LBP 160,000.00`.
        priceLow: 120000,
        priceHigh: 160000,
        selected: true,
        recommended: true,
      ),
    );

/// The opportunistic tier — the one row where the SLA is not a duration.
///
/// `Tier.slaMinutes` is null for On-the-way, so `_slaCopy` returns
/// `tierSelectionSlaNone` ("No SLA" / "بدون موعد محدد") and the schedule glyph
/// ends up labelling the ABSENCE of a schedule. Every other tier reaches the
/// same `_MetaRow` with a "≤ N hr" token, so this is the only preview where
/// that row is prose, and the only one where the Arabic runs long enough to
/// test the label's `Expanded`.
@JeebPreview(
  group: 'tier_selection',
  name: 'No SLA · On-the-way',
  size: _tierCardShippingCopyBox,
)
Widget tierCardNoSla() => _tierCardLocalized(
      (AppLocalizations l10n) => _tierCardTier(
        l10n,
        // `TierSelectionScreen` derives this from `TierId.onTheWay.name`, so
        // the one identifier in the set is camelCase where the rest are not.
        slug: 'onTheWay',
        name: l10n.tierSelectionTierOnTheWay,
        description: l10n.tierSelectionFooterOnTheWay,
        estimatedTime: l10n.tierSelectionSlaNone,
        vehicleLabel: l10n.tierSelectionVehicleAny,
        vehicleIcon: Icons.commute_rounded,
        priceLow: 30000,
        priceHigh: 55000,
        selected: false,
      ),
    );

/// The wrap ceiling — the only state that reaches all three constrained
/// `Text`s at once.
///
/// The header title (`Expanded`) and both `_MetaRow` labels (`Expanded`) are
/// the widget's only width-constrained strings, and each declares
/// `overflow: TextOverflow.ellipsis` with **no `maxLines`**. Against the
/// unbounded height a `ListView` child is measured with, that combination never
/// truncates: the strings wrap and the card grows. Nothing in the shipping
/// catalog is long enough to show you that — the longest tier name is
/// "On-the-way" and the longest vehicle label is "Bike / Scooter".
///
/// Fixture copy, deliberately: the catalog is served (`GET /tiers`) with
/// ops-authored labels, so a longer tier is a product decision away, and the
/// Arabic of any of these runs longer than its English source. What to look at
/// is the title wrapping to a second line UNDER the badge rather than
/// ellipsizing beside it, the price band breaking mid-token, and — at 200% —
/// the two 16 dp meta glyphs pinned to the top of labels three lines tall.
///
/// `matrix: true`: this is the state where RTL mirroring has the most to
/// mirror, and the state whose 200% rendering is three times the height of its
/// English light one.
@JeebPreview(
  group: 'tier_selection',
  name: 'Longest plausible copy · unreleased tier',
  size: _tierCardLongCopyBox,
  matrix: true,
)
Widget tierCardLongCopy() => _tierCardLocalized(
      (AppLocalizations l10n) => _tierCardTier(
        l10n,
        slug: 'refrigerated',
        name: 'Temperature-controlled overnight freight',
        description: 'Collected after the shops close and delivered before '
            'they open the next morning, with a signed cold-chain log.',
        estimatedTime: l10n.tierSelectionSlaHours(18),
        vehicleLabel: 'Refrigerated van with a two-person crew',
        vehicleIcon: Icons.ac_unit_rounded,
        priceLow: 1250000,
        priceHigh: 1900000,
        selected: true,
        recommended: true,
      ),
    );
