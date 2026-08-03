import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';

/// The four realized forms of a delivery/OTP code on the board.
///
/// Exposed (rather than private) so a consumer can branch on
/// `JeebCodeCells.variant` in a test without re-deriving it from the fields.
enum JeebCodeCellsVariant {
  /// 03's h74 keypad-driven entry row.
  input74,

  /// 18's h52 keyboard-driven entry row.
  input52,

  /// 13's 74×94 backlit-glass display tiles.
  display,

  /// 12's one-line `2144` strip.
  strip,
}

/// Every form the 4-digit code takes across the board (redesign-2026-08 §5 #12).
///
/// **Digits never mirror.** All four forms sit inside a
/// `Directionality(textDirection: TextDirection.ltr)` isolate, so `2144` reads
/// `2144` in Arabic. This is the widget's single most important job — a bidi
/// reorder here hands the customer the wrong door code.
///
/// The two entry forms are deliberately **not** the same mechanism, because the
/// two screens are not the same interaction:
///
///  * [JeebCodeCells.input74] (03) is **presentation-only**. The screen owns a
///    `String` filled by [JeebNumericKeypad] and passes it down; there is no
///    `TextField`, no focus node and no OS keyboard — removing the keyboard
///    that covered the code is the whole point of the redesign of 03. The
///    active cell is drawn with a **static** 2×30 accent caret; there is no
///    blink animation, because an endless ticker in a kit widget deadlocks
///    every `pumpAndSettle` downstream.
///  * [JeebCodeCells.input52] (18) **wraps `OmdsOtpInput`**. 18 has no keypad
///    (its render's lower 40 % is empty), so it keeps the OS keyboard — and its
///    frozen Maestro per-cell ids `<base>_0..3` must keep coming from OMDS,
///    where they merge onto the `TextField`'s own editable leaf. Nothing
///    outside `OmdsOtpInput` can tag that leaf.
///
/// Presentation-only: no cubit, no repository, everything arrives through the
/// constructor.
class JeebCodeCells extends StatelessWidget {
  /// 03's entry row: `h74 r18` glass cells at gap 12, digits
  /// `jeebText.codeInput` (29/w800) in ink, the next empty cell tinted accent
  /// and framed `2px jeebRoles.accent` around a 2×30 caret (R7).
  ///
  /// [value] is the digits entered so far (`''` … `'1234'`); [length] is the
  /// cell count. Cells past `value.length` render empty — no placeholder, no
  /// underscore, exactly as the board draws them.
  const JeebCodeCells.input74({
    super.key,
    required int length,
    required this.value,
    this.hasError = false,
    this.identifier,
    this.cellIdentifier,
    this.semanticLabel,
  })  : variant = JeebCodeCellsVariant.input74,
        _cellCount = length,
        onChanged = null,
        onCompleted = null,
        autoFocus = false,
        textKey = null,
        assert(length > 0, 'JeebCodeCells: a code needs at least one cell.');

  /// 18's entry row: `h52` glass cells at gap 9, digits 22/w800 in ink,
  /// focused cell framed `2px jeebRoles.accent` (`18 tpl 1077-1082`).
  ///
  /// Wraps `OmdsOtpInput`, so [value] is not read — the field owns its own
  /// controllers and reports through [onChanged] / [onCompleted].
  ///
  /// Accepted divergence from the board: the caret is the platform's, tinted
  /// `jeebRoles.accent`, not the drawn 2×22 bar.
  const JeebCodeCells.input52({
    super.key,
    int length = 4,
    this.hasError = false,
    this.identifier,
    this.cellIdentifier,
    this.semanticLabel,
    this.onChanged,
    this.onCompleted,
    this.autoFocus = false,
  })  : variant = JeebCodeCellsVariant.input52,
        _cellCount = length,
        value = '',
        textKey = null,
        assert(length > 0, 'JeebCodeCells: a code needs at least one cell.');

  /// 13's share form: 74×94 `r22` backlit-glass tiles at gap 13, digits
  /// `jeebText.statDisplay` (44/w800) in ink, `JeebShadows.glowRest` (R13).
  ///
  /// The row scales down (never up) on narrow devices: 4×74 + 3×13 is 335 px,
  /// which overflows a 360 pt phone inside 24 pt gutters.
  const JeebCodeCells.display(
    this.value, {
    super.key,
    this.identifier,
    this.semanticLabel,
  })  : variant = JeebCodeCellsVariant.display,
        _cellCount = 0,
        hasError = false,
        cellIdentifier = null,
        onChanged = null,
        onCompleted = null,
        autoFocus = false,
        textKey = null;

  /// 12's inline form: the whole code as **one** `Text` at 20/w800, letter
  /// spacing 5 (`12 tpl 779`).
  ///
  /// Deliberately not split into per-character widgets:
  /// `live_tracking_handover_code_test.dart` asserts `find.text('1234')` and
  /// `find.byKey(Key('tracking.codeRowValue'))`. Pass that key as [textKey] to
  /// land it on the `Text` itself, or as `key` to land it on this widget —
  /// both resolve for `find.byKey`.
  const JeebCodeCells.strip(
    this.value, {
    super.key,
    this.textKey,
    this.identifier,
    this.semanticLabel,
  })  : variant = JeebCodeCellsVariant.strip,
        _cellCount = 0,
        hasError = false,
        cellIdentifier = null,
        onChanged = null,
        onCompleted = null,
        autoFocus = false;

  // ── input74, measured from 03 `tpl 121-126` ──────────────────────────────

  /// Cell height (74). Public so 13's jeeber leg can size its own
  /// `OmdsOtpInput` without a literal px in `lib/features`.
  static const double inputBoxHeight = 74;

  /// A safe **fixed** cell width for consumers that cannot use `flex:1`
  /// (13's jeeber leg styles a bare `OmdsOtpInput`).
  ///
  /// The board's cells are `flex: 1 1 0%`, so no width exists to copy. 68 is
  /// the largest value that still fits four cells + three 12 px gaps inside a
  /// 360 pt phone's 24 pt gutters — `OmdsOtpInput` centres its row, so wider
  /// screens simply gain slack.
  static const double inputBoxWidth = 68;

  /// Gap between input74 cells (12).
  static const double inputCellGap = 12;

  /// input74 corner radius — R7 draws 18, the [JeebRadii.lg] rung.
  static const double inputRadius = JeebRadii.lg;

  /// The accent frame on the active cell, and the error frame on every cell
  /// (2). The board is `box-sizing: border-box` and a [DecoratedBox] border
  /// paints inside the box without insetting the child, so h74 stays h74 —
  /// no padding fold is needed here (unlike `JeebOutlinedCard`).
  static const double activeBorderWidth = 2;

  /// The 1px glass stroke every resting cell/tile carries (token sheet §4).
  static const double glassBorderWidth = 1;

  /// Caret width (2), shared by both entry forms.
  static const double caretWidth = 2;

  /// input74 caret height (30).
  static const double caretHeight = 30;

  // ── input52, measured from 18 `tpl 1077-1082` ────────────────────────────

  /// Cell height (52).
  static const double compactBoxHeight = 52;

  /// Gap between input52 cells (9).
  static const double compactCellGap = 9;

  /// Digit size for input52 (22).
  ///
  /// `jeebText.codeInput` is 29/w800 — sized for 03's h74 cells — so the size
  /// is overridden here while family, weight and the rest of the ramp entry
  /// still come from the Wave 0 token. `lib/core/widgets/jeeb/` is the one
  /// directory exempt from the `fontSize:` ban (§4.4).
  static const double compactDigitSize = 22;

  // ── display, measured from 13 `tpl 808-812` ──────────────────────────────

  /// Display tile width (74).
  static const double displayTileWidth = 74;

  /// Display tile height (94).
  static const double displayTileHeight = 94;

  /// Display tile corner radius — R13 draws 22, the [JeebRadii.xl] rung.
  static const double displayTileRadius = JeebRadii.xl;

  /// Gap between display tiles (13).
  static const double displayTileGap = 13;

  // ── strip, measured from 12 `tpl 779` ────────────────────────────────────

  /// Strip font size (20). `jeebText.price` is 21/w800 — same family and
  /// weight, one point larger — so it is the base and only the size moves.
  static const double stripFontSize = 20;

  /// Strip letter spacing (5). Note this is a **type** metric: never reach for
  /// a `Spacing` token here (the bug this const replaces).
  static const double stripLetterSpacing = 5;

  /// Which of the four forms this is.
  final JeebCodeCellsVariant variant;

  /// The digits. For the entry forms this is what has been typed so far; for
  /// [JeebCodeCells.display] and [JeebCodeCells.strip] it is the whole code.
  ///
  /// Always ASCII `0`-`9` — never Arabic-Indic. The code travels to the
  /// gateway verbatim.
  final String value;

  /// Error frame: every cell is stroked `2px colorScheme.error`. Carries
  /// today's `OmdsOtpInput.hasError` signal forward unchanged.
  final bool hasError;

  /// Maestro/`find.bySemanticsIdentifier` id for the row **as a whole**,
  /// applied via an explicit `Semantics` wrapper (never OMDS's own
  /// `identifier:`).
  ///
  /// Both current consumers already own that wrapper at their own call site
  /// (`phone_otp_input` at `otp_verification_screen.dart:278`,
  /// `mark_delivered_otp_input` at `mark_delivered_panel.dart:164`), so they
  /// pass **nothing** here and the kit adds no node at all. Two nested nodes
  /// carrying the same id would make every Maestro `tapOn` ambiguous.
  final String? identifier;

  /// Base for the **per-cell** ids `'${cellIdentifier}_0'` … `_(length-1)`
  /// (RC-7: a driver types one digit per cell, so each cell needs its own
  /// addressable node).
  ///
  /// A separate parameter from [identifier] on purpose: one value is a
  /// container node, the other is a family of leaves, and the two screens set
  /// them from the same string but in different places.
  final String? cellIdentifier;

  /// Accessibility label for the wrapper node, when [identifier] adds one.
  final String? semanticLabel;

  /// Cell count for the entry forms. [JeebCodeCells.display] and
  /// [JeebCodeCells.strip] report `value.length` instead.
  int get length => switch (variant) {
        JeebCodeCellsVariant.input74 ||
        JeebCodeCellsVariant.input52 =>
          _cellCount,
        JeebCodeCellsVariant.display || JeebCodeCellsVariant.strip =>
          value.length,
      };

  /// input52 only: fires on every keystroke with the full code so far.
  final ValueChanged<String>? onChanged;

  /// input52 only: fires once the last cell is filled (18 auto-submits here).
  final ValueChanged<String>? onCompleted;

  /// input52 only: focus the first cell on mount, opening the OS keyboard.
  ///
  /// Defaults to **false**, unlike `OmdsOtpInput`. 18 mounts this input inside
  /// a card that is already on screen; stealing focus there would shove the
  /// keyboard over the handoff tiles the moment the stage flips to at-door.
  final bool autoFocus;

  /// [JeebCodeCells.strip] only: key forwarded to the single `Text`.
  final Key? textKey;

  final int _cellCount;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (variant) {
      JeebCodeCellsVariant.input74 => _buildInputCells(context),
      JeebCodeCellsVariant.input52 => _buildCompactInput(context),
      JeebCodeCellsVariant.display => _buildDisplayTiles(context),
      JeebCodeCellsVariant.strip => _buildStrip(context),
    };

    // THE bidi guard. A 4-digit code is not text: it must read start-to-end in
    // the order it was issued, in every locale.
    final Widget isolated = Directionality(
      textDirection: TextDirection.ltr,
      child: body,
    );

    if (identifier == null && semanticLabel == null) {
      return isolated;
    }
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      // Both flags are mandatory: without them this node swallows the per-cell
      // ids underneath it.
      container: true,
      explicitChildNodes: true,
      child: isolated,
    );
  }

  Widget _buildInputCells(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors glass = _glass(context);
    final Color accent = context.jeebRoles.accent;
    final TextStyle digitStyle =
        context.jeebText.codeInput.copyWith(color: scheme.onSurface);
    // The next cell to be filled. `value.length == length` (a complete code)
    // puts this out of range, so nothing is framed — which is what the board
    // draws once the 4th digit lands.
    final int activeIndex = value.length;

    final List<Widget> cells = <Widget>[];
    for (var index = 0; index < _cellCount; index++) {
      if (index > 0) {
        cells.add(const SizedBox(width: inputCellGap));
      }
      final bool isActive = index == activeIndex && !hasError;
      final BoxBorder border = switch ((hasError, isActive)) {
        (true, _) => Border.all(color: scheme.error, width: activeBorderWidth),
        (false, true) => Border.all(color: accent, width: activeBorderWidth),
        (false, false) => Border.all(
            color: glass.glassBorderStrong,
            width: glassBorderWidth,
          ),
      };

      Widget cell = DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? glass.accentTint : glass.glassFillEmphasis,
          borderRadius: BorderRadius.circular(inputRadius),
          border: border,
          boxShadow: isActive ? JeebShadows.glowRest : null,
        ),
        child: SizedBox(
          height: inputBoxHeight,
          width: double.infinity,
          child: Center(
            child: index < value.length
                // scaleDown only shrinks: at 1× the digit is untouched, at 200 %
                // text scale it fits instead of overflowing the fixed h74 box.
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value[index], style: digitStyle),
                  )
                : isActive
                    ? _Caret(color: accent, height: caretHeight)
                    : const SizedBox.shrink(),
          ),
        ),
      );

      if (cellIdentifier != null) {
        // A plain leaf: no `container`, no `textField` flag. These cells are
        // not editable — the keypad is.
        cell = Semantics(identifier: '${cellIdentifier}_$index', child: cell);
      }
      cells.add(Expanded(child: cell));
    }
    return Row(children: cells);
  }

  Widget _buildCompactInput(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors glass = _glass(context);
    final Color accent = context.jeebRoles.accent;
    final TextStyle digitStyle = context.jeebText.codeInput.copyWith(
      fontSize: compactDigitSize,
      color: scheme.onSurface,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // `OmdsOtpInput` takes a fixed box width, so `flex:1` is emulated here.
        // Unbounded width (a horizontal scroll view) falls back to the const.
        final double available =
            constraints.maxWidth - compactCellGap * (_cellCount - 1);
        final double boxWidth = constraints.maxWidth.isFinite
            ? (available / _cellCount).clamp(1.0, double.infinity)
            : inputBoxWidth;

        return TextSelectionTheme(
          // The platform caret stands in for the board's drawn 2×22 bar.
          data: TextSelectionThemeData(cursorColor: accent),
          child: OmdsColorTokensProvider(
            // Midnight: the resting hairline IS the glass stroke, so OMDS's
            // own `inputBorderColor` is re-pointed rather than hidden.
            tokens: context.omdsColorTokens
                .copyWith(inputBorderColor: glass.glassBorderStrong),
            child: OmdsOtpInput(
              length: _cellCount,
              boxWidth: boxWidth,
              boxHeight: compactBoxHeight,
              spacing: compactCellGap,
              autoFocus: autoFocus,
              fillColor: glass.glassFillEmphasis,
              focusedBorderColor: accent,
              errorBorderColor: scheme.error,
              hasError: hasError,
              textStyle: digitStyle,
              // The ONE place the kit passes OMDS's own `identifier:`. The
              // per-cell id has to merge onto the `TextField`'s editable leaf
              // (`omds_otp_input.dart:289-296`); a `Semantics` wrapper added
              // from out here would sit ABOVE the field as a separate node and
              // Maestro's `tapOn` + `inputText` would find no editable target
              // — the RC-7 failure. The row-level id still comes from this
              // widget's own explicit wrapper, above.
              identifier: cellIdentifier,
              onChanged: onChanged,
              onCompleted: onCompleted,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisplayTiles(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors glass = _glass(context);
    final TextStyle digitStyle =
        context.jeebText.statDisplay.copyWith(color: scheme.onSurface);

    final List<Widget> tiles = <Widget>[];
    for (var index = 0; index < value.length; index++) {
      if (index > 0) {
        tiles.add(const SizedBox(width: displayTileGap));
      }
      tiles.add(
        DecoratedBox(
          decoration: BoxDecoration(
            color: glass.glassFillEmphasis,
            borderRadius: BorderRadius.circular(displayTileRadius),
            border: Border.all(
              color: glass.glassBorderStrong,
              width: glassBorderWidth,
            ),
            // Backlit, not lifted: the room's orange glow is the depth cue.
            boxShadow: JeebShadows.glowRest,
          ),
          child: SizedBox(
            width: displayTileWidth,
            height: displayTileHeight,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value[index], style: digitStyle),
              ),
            ),
          ),
        ),
      );
    }
    // 4×74 + 3×13 = 335: wider than a 360 pt phone inside 24 pt gutters.
    // scaleDown keeps the design exact wherever it fits and shrinks the whole
    // row proportionally where it does not.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: tiles),
    );
  }

  Widget _buildStrip(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Text(
      value,
      key: textKey,
      style: context.jeebText.price.copyWith(
        fontSize: stripFontSize,
        letterSpacing: stripLetterSpacing,
        color: scheme.onSurface,
      ),
    );
  }
}

/// Read defensively: a bare `!` crashes under harnesses that theme with a
/// bare `ThemeData`, and every kit widget must survive that.
JeebSemanticColors _glass(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

/// The static entry caret: a 2×[height] accent bar, stadium-capped.
///
/// Static, not blinking, on purpose — see [JeebCodeCells].
class _Caret extends StatelessWidget {
  const _Caret({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: JeebCodeCells.caretWidth,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(JeebCodeCells.caretWidth),
        ),
      ),
    );
  }
}
