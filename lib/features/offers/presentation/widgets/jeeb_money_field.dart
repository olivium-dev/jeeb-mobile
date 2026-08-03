import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_stepper_pill.dart';

/// The money input of the offer composer (redesign-2026-08 §4.2, screen 17
/// `tpl 995-1000`): a `h64 / r16 / 2px navy` field holding a currency mark, the
/// amount, and the `−1` / `+1` [JeebStepperPill] pair.
///
/// **Why this is not an `OmdsTextField`.** The board needs three things OMDS
/// cannot express: a caller-set text style (the amount is w800, far above any
/// input style OMDS ships), `textDirection` on the editable core, and no
/// decoration at all (the border and fill belong to this box, which also hosts
/// the steppers). Verified against `omds_text_field.dart` — it exposes none of
/// the three.
///
/// **Where it should live.** Wave 1 §5 left `JeebMoneyField` "screen-17-local
/// by assignment", so it sits in this feature directory for now. Two design
/// values are therefore snapped instead of exact: `lib/features` may not write
/// `fontSize:` literals (`tool/check_design_tokens.sh`), so the `$` mark uses
/// `jeebText.price` (21/w800, board 24) and the amount uses `jeebText.h1` at
/// w800 (24/w800, board 26). Wiring request WR-1 moves the file into
/// `lib/core/widgets/jeeb/` where the exact sizes are legal; nothing else about
/// the widget changes on that move.
///
/// RTL: a plain `Row`, so the mark/amount/steppers mirror as a block, while the
/// editable core is pinned to [TextDirection.ltr] so the digits and the decimal
/// point never reorder. The amount hugs the currency mark in both directions.
class JeebMoneyField extends StatelessWidget {
  const JeebMoneyField({
    super.key,
    required this.controller,
    required this.currencyMark,
    required this.onChanged,
    required this.onStep,
    this.placeholder,
    this.errorText,
    this.inputFormatters,
    this.canDecrement = true,
    this.identifier,
    this.decrementIdentifier,
    this.incrementIdentifier,
    this.decrementSemanticLabel,
    this.incrementSemanticLabel,
  });

  /// `height: 64` (`tpl 995`) — a MINIMUM, not a fixed height, so the box grows
  /// with the text scale instead of clipping at 200%.
  static const double minHeight = Sizes.sixXLarge;

  /// `2px` navy stroke (`tpl 995`).
  static const double borderWidth = 2;

  /// The decrement label — a real U+2212 MINUS SIGN, as the board draws it.
  static const String decrementLabel = '−1';

  /// The increment label.
  static const String incrementLabel = '+1';

  /// The amount being edited. Owned by the screen so the draft survives a 402
  /// round-trip.
  final TextEditingController controller;

  /// `$` for USD, else the ISO code — resolved by the caller's l10n.
  final String currencyMark;

  /// Fired on every keystroke with the raw text.
  final ValueChanged<String> onChanged;

  /// Fired by the pills with `-1` / `+1`. The caller owns the floor and the
  /// formatting; this widget never computes money.
  final ValueChanged<int> onStep;

  /// Placeholder shown while the field is empty (`0.00`).
  final String? placeholder;

  /// Validation error. Non-null also swaps the stroke to `colorScheme.error`.
  final String? errorText;

  /// Keystroke filters (the composer allows digits and a decimal point).
  final List<TextInputFormatter>? inputFormatters;

  /// False at the floor: the `−1` pill dims and stops responding.
  final bool canDecrement;

  /// Identifier for the editable core — the frozen
  /// `offer_composer_price_field`. It must stay the thing a tap focuses.
  final String? identifier;

  /// Identifier for the `−1` pill.
  final String? decrementIdentifier;

  /// Identifier for the `+1` pill.
  final String? incrementIdentifier;

  /// a11y label for the `−1` pill (`−1` alone reads badly).
  final String? decrementSemanticLabel;

  /// a11y label for the `+1` pill.
  final String? incrementSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    final hasError = errorText != null;

    final markStyle =
        context.jeebText.price.copyWith(color: semantics.mutedText);
    final amountStyle = context.jeebText.h1.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.primary,
    );

    final field = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(
          color: hasError ? scheme.error : scheme.primary,
          width: borderWidth,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
          ),
          child: Row(
            children: [
              Text(currencyMark, style: markStyle),
              const SizedBox(width: Spacing.xSmall),
              Expanded(child: _editableCore(context, amountStyle, semantics)),
              const SizedBox(width: Spacing.xSmall),
              JeebStepperPill(
                label: decrementLabel,
                onTap: () => onStep(-1),
                isEnabled: canDecrement,
                identifier: decrementIdentifier,
                semanticLabel: decrementSemanticLabel,
              ),
              const SizedBox(width: JeebStepperPill.spacing),
              JeebStepperPill(
                label: incrementLabel,
                onTap: () => onStep(1),
                identifier: incrementIdentifier,
                semanticLabel: incrementSemanticLabel,
              ),
            ],
          ),
        ),
      ),
    );

    if (!hasError) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: Spacing.xSmall),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: Spacing.twoXSmall),
          child: Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
      ],
    );
  }

  Widget _editableCore(
    BuildContext context,
    TextStyle amountStyle,
    JeebSemanticColors semantics,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // The row mirrors, so the digits must hug the currency mark from whichever
    // side it lands on — while the run itself stays LTR.
    final alignment = Directionality.of(context) == TextDirection.rtl
        ? TextAlign.end
        : TextAlign.start;

    return Semantics(
      identifier: identifier,
      textField: true,
      child: TextField( // EXEMPT(flutter-omds-design-system-usage): see class doc.
        controller: controller,
        onChanged: onChanged,
        style: amountStyle,
        textDirection: TextDirection.ltr,
        textAlign: alignment,
        cursorColor: scheme.primary,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: placeholder,
          hintStyle: amountStyle.copyWith(color: semantics.mutedText),
        ),
      ),
    );
  }
}
