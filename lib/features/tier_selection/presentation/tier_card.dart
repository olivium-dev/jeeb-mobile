import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
