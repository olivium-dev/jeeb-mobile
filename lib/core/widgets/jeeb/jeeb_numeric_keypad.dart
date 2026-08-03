import 'package:flutter/material.dart';

import '../../theme/jeeb_text_styles.dart';

/// The in-screen 3×4 digit pad (redesign-2026-08 §5 #13).
///
/// It exists so the OS keyboard stops covering the code: on 03 the software
/// keyboard used to sit on top of the very cells it was filling, which is why
/// the redesign replaces `OmdsOtpInput` there with `JeebCodeCells.input74`
/// plus this pad.
///
/// `3` columns at gap 10, cells `h62 r16 surfaceContainerHigh` with
/// `jeebText.keypadDigit` (23/w700) navy digits, a **blank** cell at
/// bottom-start and a **fill-less** 24 px backspace at bottom-end
/// (`03 tpl 132-147`). The container carries its own `0/20/30` gutter, so it
/// mounts OUTSIDE the screen's 24 pt body padding.
///
/// **The grid is pinned LTR by default** ([forceLtr]). Neither iOS nor Android
/// mirrors a numeric pad in Arabic — `1 2 3` stays `1 2 3` and backspace stays
/// on the right — and a mirrored pad is a data-entry hazard, not a
/// localisation win. Every position is still expressed directionally
/// (start/end, [EdgeInsetsDirectional]) rather than as left/right, so
/// `forceLtr: false` yields a genuinely mirrored pad for a lane that measures
/// otherwise; nothing about the layout is hardcoded to one side.
///
/// Presentation-only: it owns no code string. [onDigit] and [onBackspace]
/// report taps and the screen owns the buffer.
class JeebNumericKeypad extends StatelessWidget {
  /// Creates the pad.
  ///
  /// [backspaceLabel] is required and not defaulted: the backspace key is
  /// icon-only, so without an l10n string it is an unlabelled button to a
  /// screen reader.
  const JeebNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.backspaceLabel,
    this.identifierPrefix,
    this.identifier,
    this.semanticLabel,
    this.forceLtr = true,
    this.padding = defaultPadding,
  });

  /// Key height (62), measured `03 tpl 134`.
  static const double keyHeight = 62;

  /// Gap between keys, both axes (10), measured `03 tpl 133`.
  static const double keyGap = 10;

  /// Key corner radius (16).
  static const double keyRadius = 16;

  /// Backspace glyph size (24), measured `03 tpl 146`.
  static const double backspaceSize = 24;

  /// The pad's own gutter: `0/20/30`, i.e. narrower than the 24 pt body gutter
  /// so the outer keys sit slightly wider than the content above them.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.fromSTEB(20, 0, 20, 30);

  /// Fires with the ASCII digit `'0'`…`'9'`.
  ///
  /// ASCII, never Arabic-Indic: the assembled code is posted verbatim to
  /// `/v1/auth/otp/verify`, and `٠١٢٣` would not verify.
  final ValueChanged<String> onDigit;

  /// Fires when the backspace key is tapped.
  final VoidCallback onBackspace;

  /// Screen-reader label for the icon-only backspace key.
  final String backspaceLabel;

  /// Base for the frozen per-key ids: `'${identifierPrefix}_0'` … `_9` and
  /// `'${identifierPrefix}_backspace'` (§5 #13's `<screen>_keypad_<n>`).
  ///
  /// 03 passes `'phone_otp_keypad'`. Applied via explicit `Semantics`
  /// wrappers, one per key — never OMDS's own `identifier:`.
  final String? identifierPrefix;

  /// Optional id for the pad **as a whole**, applied via its own explicit
  /// `Semantics` wrapper. Separate from [identifierPrefix]: one is a container
  /// node, the other a family of leaves.
  final String? identifier;

  /// Accessibility label for the wrapper node, when [identifier] adds one.
  final String? semanticLabel;

  /// Pin the grid left-to-right regardless of ambient direction. See the class
  /// doc — default `true` is the platform-correct behaviour.
  final bool forceLtr;

  /// The pad's gutter. Override to dock it against a different body inset.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _row(context, const <String>['1', '2', '3']),
        const SizedBox(height: keyGap),
        _row(context, const <String>['4', '5', '6']),
        const SizedBox(height: keyGap),
        _row(context, const <String>['7', '8', '9']),
        const SizedBox(height: keyGap),
        // Bottom row: blank at the START, `0` centred, backspace at the END.
        Row(
          children: <Widget>[
            // Not a key: `tpl 143` draws no fill and there is nothing to tap.
            const Expanded(child: SizedBox(height: keyHeight)),
            const SizedBox(width: keyGap),
            Expanded(child: _digitKey(context, '0')),
            const SizedBox(width: keyGap),
            Expanded(child: _backspaceKey(context)),
          ],
        ),
      ],
    );

    if (forceLtr) {
      grid = Directionality(textDirection: TextDirection.ltr, child: grid);
    }

    // The gutter sits OUTSIDE the isolate so it still resolves against the
    // ambient direction — it is symmetric today, and a lane that overrides it
    // asymmetrically should get the mirrored result.
    Widget pad = Padding(padding: padding, child: grid);

    if (identifier != null || semanticLabel != null) {
      pad = Semantics(
        identifier: identifier,
        label: semanticLabel,
        // Both flags are mandatory: without them this node swallows the
        // per-key ids underneath it.
        container: true,
        explicitChildNodes: true,
        child: pad,
      );
    }
    return pad;
  }

  Widget _row(BuildContext context, List<String> digits) {
    final List<Widget> children = <Widget>[];
    for (var index = 0; index < digits.length; index++) {
      if (index > 0) {
        children.add(const SizedBox(width: keyGap));
      }
      children.add(Expanded(child: _digitKey(context, digits[index])));
    }
    return Row(children: children);
  }

  Widget _digitKey(BuildContext context, String digit) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _KeyCell(
      identifier:
          identifierPrefix == null ? null : '${identifierPrefix}_$digit',
      semanticLabel: digit,
      fill: scheme.surfaceContainerHigh,
      onTap: () => onDigit(digit),
      child: Text(
        digit,
        style: context.jeebText.keypadDigit.copyWith(color: scheme.primary),
      ),
    );
  }

  Widget _backspaceKey(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _KeyCell(
      identifier: identifierPrefix == null
          ? null
          : '${identifierPrefix}_backspace',
      semanticLabel: backspaceLabel,
      // `tpl 145` has no background: the glyph floats on white.
      fill: null,
      onTap: onBackspace,
      // `Icons.backspace` is declared `matchTextDirection: true`, so it points
      // the right way in both a pinned-LTR pad and a mirrored one. Reaching
      // for `DirectionalIcons` here would be wrong twice over: it has no
      // backspace entry, and it reads the ambient direction the isolate has
      // already decided.
      child: Icon(
        Icons.backspace,
        size: backspaceSize,
        color: scheme.primary,
      ),
    );
  }
}

/// One 62 px keypad cell: an optional fill, a centred glyph, an ink splash and
/// exactly one Semantics node.
class _KeyCell extends StatelessWidget {
  const _KeyCell({
    required this.identifier,
    required this.semanticLabel,
    required this.fill,
    required this.onTap,
    required this.child,
  });

  final String? identifier;
  final String semanticLabel;
  final Color? fill;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(JeebNumericKeypad.keyRadius);

    // The splash lands above the fill and inside the rounded rect, so the
    // Material sits inside the decoration and the InkWell owns the shape.
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: JeebNumericKeypad.keyHeight,
            width: double.infinity,
            // scaleDown only shrinks: at 1× the digit is untouched, at 200 %
            // text scale it fits instead of overflowing the fixed h62 box.
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      button: true,
      container: true,
      // The label is the whole node: the digit `Text` underneath would
      // otherwise announce a second time, and the icon announces nothing.
      excludeSemantics: true,
      onTap: onTap,
      child: surface,
    );
  }
}
