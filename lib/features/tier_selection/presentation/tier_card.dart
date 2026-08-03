import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/formatting/money_format.dart';
import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';

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

  final String? identifier;

  final String name;

  final String description;

  final String estimatedTime;

  final String priceRange;

  final String vehicleLabel;

  final IconData vehicleIcon;

  final bool selected;
  final VoidCallback onTap;

  final String? recommendedBadgeText;

  final String? semanticLabel;

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

/// Canvas boxes at a 390 dp phone width. Inside [_tierCardListInset] that
/// leaves the card its production 350 dp, so its copy wraps where the app wraps
const Size _tierCardShippingCopyBox = Size(390, 600);
const Size _tierCardLongCopyBox = Size(390, 960);

/// What surrounds ONE card in the tier list: the `ListView.separated`'s
/// horizontal [Spacing.large] padding and, vertically, the [Spacing.small]
const EdgeInsetsDirectional _tierCardListInset =
    EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.large,
  vertical: Spacing.small,
);

/// Every tier in the bundled catalog is priced in Lebanese pounds, which is
/// also the currency that produces the longest money token — `LBP 160,000.00`
const String _tierCardCurrency = 'LBP';

/// Mounts the card the way `_LoadedView`'s `ListView` does: the list inset,
/// full-bleed width, and a shrink-wrapping column.
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
String _tierCardPriceRange(AppLocalizations l10n, int low, int high) =>
    l10n.tierSelectionPriceRange(
      MoneyFormat.format(low.toDouble(), currency: _tierCardCurrency),
      MoneyFormat.format(high.toDouble(), currency: _tierCardCurrency),
    );

/// Builds one card from a tier's parts the way `_TierListEntry` does —
/// including the `tier_selection_card_<id>` identifier QA targets and the
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
/// Flash is the only tier the catalog ever flags (`recommended: id ==
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
/// `Tier.slaMinutes` is null for On-the-way, so `_slaCopy` returns
@JeebPreview(
  group: 'tier_selection',
  name: 'No SLA · On-the-way',
  size: _tierCardShippingCopyBox,
)
Widget tierCardNoSla() => _tierCardLocalized(
      (AppLocalizations l10n) => _tierCardTier(
        l10n,
        // `TierSelectionScreen` derives this from `TierId.onTheWay.name`, so
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
