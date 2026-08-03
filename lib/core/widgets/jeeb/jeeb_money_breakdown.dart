import 'package:flutter/material.dart';

import '../../jeeb_commission.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_outlined_card.dart';
import 'jeeb_surface_tone.dart';

/// One label/value line of a [JeebMoneyBreakdown].
///
/// [value] is nullable on purpose: 17's empty state (no price entered yet)
/// renders each row as a single explanatory sentence with no amount beside it
/// ("Platform fee: 10% of your offer"), so the card looks deliberate rather
/// than blank.
///
/// Amounts should arrive already formatted through `MoneyFormat.format` — it
/// wraps the token in a Unicode LTR isolate, which is what keeps `$0.80` from
/// scrambling inside an Arabic paragraph.
@immutable
class JeebMoneyLine {
  const JeebMoneyLine({
    required this.label,
    this.value,
    this.identifier,
    this.semanticLabel,
  });

  /// The qualifier side of the row — `mutedText` w600 (navy w800 on the total).
  final String label;

  /// The amount. Null renders the label alone (the pending state).
  final String? value;

  /// Maestro/`find.bySemanticsIdentifier` id for this line, applied via an
  /// explicit `Semantics` wrapper. 17 re-homes `offer_composer_offer_line`,
  /// `offer_composer_fee_line` and `offer_composer_net_line` here.
  final String? identifier;

  /// Replaces the merged "label value" announcement when the visual string
  /// does not read well aloud.
  final String? semanticLabel;
}

/// The fee breakdown card (redesign-2026-08 §5 #24).
///
/// Outlined r16, pad `15/16`; label/value rows at 13.5 (`mutedText` w600 label,
/// navy w700 value) spaced 8; a 1px `outlineVariant` rule with a `10/0` margin;
/// a total row at 15/w800 whose value is 17px; and a footnote at 11.5/w500 with
/// a 14px lock glyph.
///
/// ## This is the single enforcement point for D41/D44
///
/// Every platform-fee row in the app goes through this widget, so this is the
/// only place the framing can be checked at all: the app says **"Platform
/// fee"** and **never "Commission"** (pinned by
/// `test/decision_violations_test.dart`). Two debug asserts hold that line —
/// one on the banned framing, one on any `N%` in the copy disagreeing with
/// [kJeebCommissionPercent].
///
/// The numbers come from the same constant: derive the fee with
/// [platformFeeOn] and the take-home with [netKeptFrom] rather than multiplying
/// by a literal, so the label and the amount beside it cannot drift apart.
///
/// ## Consumers
///
/// **17 (offer composer) only.** The plan's §5 #24 row lists 14 and 19 too, and
/// both lanes measured and refused it: 14 is a *customer* surface and must show
/// no fee line at all (`receipt_no_commission_line` is a negative assertion),
/// and 19's fee strip is a single-value row with no rows/divider/total/footnote
/// — a plain [JeebOutlinedCard]. Do not re-add either.
class JeebMoneyBreakdown extends StatelessWidget {
  const JeebMoneyBreakdown({
    super.key,
    required this.rows,
    this.total,
    this.footnote,
    this.footnoteIcon = Icons.lock,
    this.footnoteIdentifier,
    this.identifier,
    this.semanticLabel,
    this.radius = 16,
    this.padding = defaultPadding,
    this.rowSpacing = 8,
    this.dividerSpacing = 10,
    this.footnoteSpacing = 10,
    this.footnoteIconSize = 14,
    this.valueSpacing = 12,
  });

  /// `15/16` — measured on 17 (`tpl 1010`). The card folds its own 1.5px stroke
  /// on top of this, so the realized content inset is 16.5/17.5.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15);

  /// Gap between the footnote glyph and its copy (`tpl 1021`).
  static const double footnoteIconSpacing = 8;

  /// The platform fee on [amount] — the ONE derivation, from
  /// [kJeebCommissionRate]. Never multiply by a literal at a call site.
  static double platformFeeOn(double amount) => amount * kJeebCommissionRate;

  /// What the Jeeber keeps: [amount] minus the platform fee.
  static double netKeptFrom(double amount) => amount - platformFeeOn(amount);

  /// The rate as a whole-number percentage, for label interpolation
  /// ("Platform fee ($feePercent%)"). Re-exported so a lane never types `10`.
  static int get feePercent => kJeebCommissionPercent;

  /// Framing this app refuses (D41/D44), EN + AR.
  static const List<String> _bannedFraming = <String>['commission', 'عمولة'];

  /// Any whole-number percentage in the copy.
  static final RegExp _percentPattern = RegExp(r'(\d+)\s*%');

  /// The label/value lines above the rule — 17 passes `[your offer, fee]`.
  final List<JeebMoneyLine> rows;

  /// The emphasised line below the rule (17: "You keep (cash)"). Null renders
  /// neither the rule nor the total.
  final JeebMoneyLine? total;

  /// The small print under the total (17: the wallet-reserve sentence).
  final String? footnote;

  /// Glyph beside [footnote]. Filled, per R10 — no outline variants.
  final IconData? footnoteIcon;

  /// Identifier for the footnote line (17: `offer_composer_reserve_note`).
  final String? footnoteIdentifier;

  /// Identifier for the card itself. Omit it when the consumer owns the node.
  final String? identifier;

  /// Accessibility label for the card node.
  final String? semanticLabel;

  /// Corner radius; 16 on every board occurrence.
  final double radius;

  /// Content padding. Directional — never hardcode left/right.
  final EdgeInsetsGeometry padding;

  /// Vertical gap between [rows] (`margin-top: 8`).
  final double rowSpacing;

  /// Margin above and below the rule (`margin: 10 0`).
  final double dividerSpacing;

  /// Gap between the total row and [footnote] (`margin-top: 10`).
  final double footnoteSpacing;

  /// Footnote glyph size — 14px, the smallest of R10's five sizes.
  final double footnoteIconSize;

  /// Minimum gap between a label and its amount before the label wraps.
  final double valueSpacing;

  @override
  Widget build(BuildContext context) {
    // D41/D44 is a *wording* rule and wording arrives as strings, so the one
    // widget every fee row passes through is the only place it can be held.
    assert(
      _isFeeOnly(),
      'JeebMoneyBreakdown: D41/D44 — this app frames the platform cut as a '
      '"Platform fee" and the word "Commission" appears NOWHERE (pinned by '
      'test/decision_violations_test.dart). Fix the l10n value, not this '
      'assert.',
    );
    assert(
      _percentsMatchTheRate(),
      'JeebMoneyBreakdown: a percentage in the copy disagrees with '
      'kJeebCommissionRate ($kJeebCommissionPercent%). Interpolate '
      'kJeebCommissionPercent into the label so the word and the number beside '
      'it cannot drift.',
    );

    return JeebOutlinedCard(
      radius: radius,
      padding: padding,
      identifier: identifier,
      semanticLabel: semanticLabel,
      // Built inside the card so the ink resolves against the tone the card
      // publishes, not against whatever surface the breakdown sits on.
      child: Builder(builder: _content),
    );
  }

  Widget _content(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final JeebTextStyles text = context.jeebText;

    // Every style is a Wave-0 token plus the one documented delta the board
    // asks for; `lib/core/widgets/jeeb/` is the tier allowed design-exact px.
    final TextStyle labelStyle = text.body.copyWith(
      fontWeight: FontWeight.w600,
      color: tone.mutedInk,
    );
    final TextStyle valueStyle = text.body.copyWith(
      fontWeight: FontWeight.w700,
      color: tone.titleInk,
    );
    final TextStyle totalLabelStyle = text.cardTitle.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: tone.titleInk,
    );
    final TextStyle totalValueStyle = text.titleProminent.copyWith(
      fontWeight: FontWeight.w800,
      color: tone.titleInk,
    );
    final TextStyle footnoteStyle = text.caption.copyWith(
      fontWeight: FontWeight.w500,
      color: tone.mutedInk,
    );

    final List<Widget> children = <Widget>[];
    for (var index = 0; index < rows.length; index++) {
      if (index > 0) {
        children.add(SizedBox(height: rowSpacing));
      }
      children.add(
        _line(rows[index], labelStyle: labelStyle, valueStyle: valueStyle),
      );
    }

    if (total != null) {
      if (rows.isNotEmpty) {
        children.add(
          Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: dividerSpacing),
            child: ColoredBox(
              color: tone.dividerInk,
              child: const SizedBox(height: 1, width: double.infinity),
            ),
          ),
        );
      }
      children.add(
        _line(
          total!,
          labelStyle: totalLabelStyle,
          valueStyle: totalValueStyle,
        ),
      );
    }

    if (footnote != null) {
      children.add(SizedBox(height: footnoteSpacing));
      children.add(_footnote(footnoteStyle, tone));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _line(
    JeebMoneyLine line, {
    required TextStyle labelStyle,
    required TextStyle valueStyle,
  }) {
    return _identified(
      lineIdentifier: line.identifier,
      semanticLabel: line.semanticLabel,
      child: Row(
        // The board flexes these; the amount tracks the label's FIRST line, so
        // a wrapped pending sentence keeps its amount at the top.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(child: Text(line.label, style: labelStyle)),
          if (line.value != null) ...<Widget>[
            SizedBox(width: valueSpacing),
            Text(
              line.value!,
              style: valueStyle,
              textAlign: TextAlign.end,
            ),
          ],
        ],
      ),
    );
  }

  Widget _footnote(TextStyle style, JeebSurfaceToneData tone) {
    return _identified(
      lineIdentifier: footnoteIdentifier,
      child: Row(
        children: <Widget>[
          if (footnoteIcon != null) ...<Widget>[
            Icon(footnoteIcon, size: footnoteIconSize, color: tone.mutedInk),
            const SizedBox(width: footnoteIconSpacing),
          ],
          Expanded(child: Text(footnote!, style: style)),
        ],
      ),
    );
  }

  /// One `Semantics` node per identified line, merging its label and amount so
  /// a screen reader announces the row as one sentence. No `explicitChildNodes`
  /// here on purpose — a money line has no nested identifiers to swallow.
  Widget _identified({
    required Widget child,
    String? lineIdentifier,
    String? semanticLabel,
  }) {
    if (lineIdentifier == null && semanticLabel == null) {
      return child;
    }
    return Semantics(
      identifier: lineIdentifier,
      label: semanticLabel,
      container: true,
      child: semanticLabel == null ? child : ExcludeSemantics(child: child),
    );
  }

  Iterable<String> get _copy sync* {
    for (final JeebMoneyLine line in rows) {
      yield line.label;
      if (line.value != null) yield line.value!;
    }
    if (total != null) {
      yield total!.label;
      if (total!.value != null) yield total!.value!;
    }
    if (footnote != null) yield footnote!;
  }

  bool _isFeeOnly() {
    final String haystack = _copy.join(' ').toLowerCase();
    return !_bannedFraming.any(haystack.contains);
  }

  bool _percentsMatchTheRate() {
    for (final String line in _copy) {
      for (final RegExpMatch match in _percentPattern.allMatches(line)) {
        if (int.parse(match.group(1)!) != kJeebCommissionPercent) return false;
      }
    }
    return true;
  }
}
