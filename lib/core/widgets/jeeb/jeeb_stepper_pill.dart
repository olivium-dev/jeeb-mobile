import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

const BorderRadius _pillRadius =
    BorderRadius.all(Radius.circular(JeebRadii.pill));

/// The `−1` / `+1` price adjuster (redesign-2026-08 §5 #27).
///
/// MIDNIGHT (R17 offer composer): pad `6/12`, radius `pill`, `glassFillEmphasis`
/// fill + `1px glassBorderStrong`, label `bodySmall`/w700 in `onSurface` white —
/// **not orange**; a stepper is not a budgeted accent. Screen 17 is the only
/// consumer: a pair sits in the trailing slot of `JeebMoneyField`, [spacing]
/// apart.
///
/// Identifiers are frozen as `<screen>_price_decrement` / `<screen>_price_increment`
/// (17: `offer_composer_price_decrement` / `offer_composer_price_increment`) and
/// are applied through an explicit `Semantics` wrapper.
///
/// **The label is the caller's string.** The kit has no l10n access, and `−1`
/// is a real minus sign (U+2212) on the board, not a hyphen — 17 owns that
/// choice so the AR build can localise the digit shaping.
class JeebStepperPill extends StatelessWidget {
  const JeebStepperPill({
    super.key,
    required this.label,
    required this.onTap,
    this.identifier,
    this.semanticLabel,
    this.isEnabled = true,
    this.padding = defaultPadding,
    this.borderWidth = 1,
  });

  /// `6/12` (17 `tpl 999`).
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6);

  /// Gap between the two pills of a pair (`6` — 17 `tpl 998`). Exposed as a
  /// const rather than as a row widget: the pair only ever exists inside 17's
  /// `JeebMoneyField`, and a `JeebStepperPillRow` with one consumer is a kit
  /// widget nobody else can reuse.
  static const double spacing = 6;

  /// Opacity applied when [isEnabled] is false (clamped at a price floor/ceiling).
  static const double disabledOpacity = 0.4;

  /// Visible label — `−1` / `+1`.
  final String label;

  /// Fired on tap. Ignored while [isEnabled] is false.
  final VoidCallback onTap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label. `−1` alone reads badly; 17 passes a phrase such as
  /// `l10n.offerComposerPriceDecrement`.
  final String? semanticLabel;

  /// False at the price floor/ceiling: the pill dims and stops responding, and
  /// reports `enabled: false` to the a11y tree.
  final bool isEnabled;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode left/right.
  final EdgeInsetsGeometry padding;

  /// Glass border width (`1`).
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();

    Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: semantics.glassFillEmphasis,
        borderRadius: _pillRadius,
        border:
            Border.all(color: semantics.glassBorderStrong, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: _pillRadius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            child: Padding(
              // The board is `box-sizing: border-box`, so the stroke sits
              // outside the 6/12 padding; Flutter paints the border over the
              // child, so it has to be folded into the inset. Same correction
              // the card primitives apply.
              padding: padding.add(EdgeInsets.all(borderWidth)),
              child: Text(
                label,
                // 12.5/w700 — `bodySmall` is exactly 12.5, so only the weight
                // is an override.
                style: context.jeebText.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    if (!isEnabled) {
      pill = Opacity(opacity: disabledOpacity, child: pill);
    }

    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      button: true,
      enabled: isEnabled,
      container: true,
      child: ExcludeSemantics(child: pill),
    );
  }
}
