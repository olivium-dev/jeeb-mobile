import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import 'selectable_radio_glyph.dart';

/// Selectable tier card for the Request type screen (Figma 56535:2392).
///
/// Layout: a leading OMDS vector [icon] + [title] row, a two-line description
/// ([speed] then [value]) on the leading side, and a radio glyph on the
/// trailing side. The whole card is one tap target. There is no OMDS radio
/// primitive, so the glyph is drawn from `colorScheme` roles
/// ([SelectableRadioGlyph]).
///
/// The [icon] replaces the legacy emoji prefix that used to be baked into the
/// localized [title] — the design-system iconography idiom (`IconData`) is
/// used across the app and renders crisply in dark mode + RTL.
///
/// Selected state mirrors the Figma "Flash selected" frame: navy fill
/// (`colorScheme.primary`) + white foreground; unselected cards are a white
/// surface with a 1dp navy outline and periwinkle description text
/// (`onSecondaryContainer`).
class RequestTierCard extends StatelessWidget {
  const RequestTierCard({
    super.key,
    required this.icon,
    required this.title,
    required this.speed,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.semanticIdentifier,
    required this.semanticLabel,
    required this.selectedHint,
  });

  final IconData icon;
  final String title;
  final String speed;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final String semanticIdentifier;
  final String semanticLabel;
  final String selectedHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: semanticIdentifier,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: semanticLabel,
      hint: selected ? selectedHint : null,
      button: true,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: OmdsBorderRadius.uiLarge,
          child: InkWell(
            borderRadius: OmdsBorderRadius.uiLarge,
            onTap: onTap,
            child: _body(scheme),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    final border = selected ? scheme.primary : scheme.outlineVariant;
    return Container(
      padding: const EdgeInsetsDirectional.all(Spacing.medium),
      decoration: BoxDecoration(
        borderRadius: OmdsBorderRadius.uiLarge,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(child: _TierCopy(card: this)),
          const SizedBox(width: Spacing.medium),
          SelectableRadioGlyph(selected: selected),
        ],
      ),
    );
  }
}

class _TierCopy extends StatelessWidget {
  const _TierCopy({required this.card});

  final RequestTierCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final descColor =
        card.selected ? scheme.onPrimary : scheme.onSecondaryContainer;
    final titleColor = card.selected ? scheme.onPrimary : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(card.icon, size: Sizes.large, color: titleColor),
            const SizedBox(width: Spacing.twoXSmall),
            Flexible(child: Text(card.title, style: _titleStyle(text, scheme))),
          ],
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(card.speed, style: text.bodySmall?.copyWith(color: descColor)),
        Text(card.value, style: _valueStyle(text, descColor)),
      ],
    );
  }

  TextStyle? _titleStyle(TextTheme text, ColorScheme scheme) =>
      text.labelLarge?.copyWith(
        color: card.selected ? scheme.onPrimary : scheme.primary,
        fontWeight: FontWeight.w700,
      );

  TextStyle? _valueStyle(TextTheme text, Color color) =>
      text.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700);
}
