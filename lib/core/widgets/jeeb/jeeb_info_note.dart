import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_surface_tone.dart';

/// The six realized tones of [JeebInfoNote] (redesign-2026-08 §5 #22).
///
/// A tone is a *fill + ink pair*, never a size: every tone shares the same
/// geometry so five lanes cannot each invent a grey panel.
enum JeebInfoNoteTone {
  /// `surfaceContainerHigh` fill, muted ink — the default quiet panel.
  /// 08's "Jeebers set the price", 12's door-code strip, 16's offline banner,
  /// 23's KYC-pending banner.
  muted,

  /// `surfaceContainerHigh` fill, **navy** ink, orange trailing link — 17's
  /// wallet strip and 11's countdown strip. The accent is the *link*, not the
  /// fill (the board never tints this panel orange).
  accent,

  /// `jeebRoles.successContainer` + a success-green glyph — 23's "You're set to
  /// bid", 05's sent confirmation.
  success,

  /// `jeebRoles.warningContainer` / `onWarningContainer` — 23's three
  /// non-healthy affordability states, 16's offline banner.
  warning,

  /// White + `1.5px colorScheme.outline`, no shadow — 23's reserve row and 15's
  /// blind-reveal note. Same geometry as [muted]; a border instead of a fill.
  outlined,

  /// `colorScheme.errorContainer` / `onErrorContainer` — 11's dismissible
  /// error banner. Wave 0's soft error family, never the legacy `#B00020` slab.
  error,
}

/// The panel that repeats on more spine screens than any other shape
/// (redesign-2026-08 §5 #22 — 08, 11, 12, 17, 23, plus 15, 16, 22, 05).
///
/// One row, always: `[glyph] gap [text column] gap [trailing]`. Two realized
/// forms, and **the form is structural, not a parameter** — passing a [title]
/// switches the note from the single-line strip (08 11 12 17) to the stacked
/// title/sub panel (23 15), which is what moves padding 12→13, gap 10→12 and
/// the glyph 17→19. Both remain overridable.
///
/// Composition rules:
///  * The kit owns the fill, radius, padding, gap and the two text styles. A
///    consumer that needs different ink passes the [label] widget slot instead
///    of restyling from outside.
///  * [trailing] is the ONE trailing position — 11's `JeebMeter`, 12's
///    `JeebCodeCells.strip`, 23's `$0.80` value, or (via [linkLabel]) 17's
///    orange `Top up` link. `trailing` and `linkLabel` are mutually exclusive.
///  * Semantics: the note adds a node only when [identifier] or [semanticLabel]
///    is set. 12 and 23 own their outer `Semantics` and pass neither — they get
///    a bare panel with nothing to nest inside. See the class docs on
///    [identifier].
///
/// ```dart
/// // 08 — the single-line muted strip.
/// JeebInfoNote.muted(text: l10n.tierCatalogPricingNote)
///
/// // 17 — accent tone with a tappable, identified link.
/// JeebInfoNote.accent(
///   icon: Icons.account_balance_wallet,
///   text: l10n.walletStrip(balance),
///   linkLabel: l10n.walletTopUpCta,
///   onLink: () => context.goNamed('wallet-charge-info'),
///   identifier: 'offer_composer_wallet_strip',
///   linkIdentifier: 'offer_composer_wallet_topup_cta',
/// )
///
/// // 23 — the stacked outlined form with a trailing value.
/// JeebInfoNote.outlined(
///   icon: Icons.lock,
///   title: copy.reservedTitle,
///   text: copy.reservedSub,
///   trailing: Text(money, style: context.jeebText.cardTitle),
/// )
/// ```
class JeebInfoNote extends StatelessWidget {
  const JeebInfoNote({
    super.key,
    required this.tone,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : assert(
          icon == null || leading == null,
          'Pass either icon (IconData) or leading (Widget), not both.',
        ),
        assert(
          text == null || label == null,
          'Pass either text (String) or label (Widget), not both.',
        ),
        assert(
          trailing == null || linkLabel == null,
          'trailing and linkLabel occupy the same slot (§5 #22 lists them as '
          'one "optional trailing"). Build the link into trailing if you need '
          'both.',
        ),
        assert(
          linkLabel == null || onLink != null,
          'A link the user cannot tap is a defect, not a style.',
        ),
        assert(
          title != null || text != null || label != null,
          'An info note with nothing to say is a coloured slab.',
        );

  /// `surfaceContainerHigh` + muted ink (08 12 16 22 23-KYC).
  const JeebInfoNote.muted({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : tone = JeebInfoNoteTone.muted,
        assert(icon == null || leading == null, 'icon xor leading'),
        assert(text == null || label == null, 'text xor label'),
        assert(trailing == null || linkLabel == null, 'one trailing slot'),
        assert(linkLabel == null || onLink != null, 'link needs onLink'),
        assert(title != null || text != null || label != null, 'needs copy');

  /// `surfaceContainerHigh` + navy ink + an orange link (17 11).
  const JeebInfoNote.accent({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : tone = JeebInfoNoteTone.accent,
        assert(icon == null || leading == null, 'icon xor leading'),
        assert(text == null || label == null, 'text xor label'),
        assert(trailing == null || linkLabel == null, 'one trailing slot'),
        assert(linkLabel == null || onLink != null, 'link needs onLink'),
        assert(title != null || text != null || label != null, 'needs copy');

  /// `jeebRoles.successContainer` + a success glyph (23 05).
  const JeebInfoNote.success({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : tone = JeebInfoNoteTone.success,
        assert(icon == null || leading == null, 'icon xor leading'),
        assert(text == null || label == null, 'text xor label'),
        assert(trailing == null || linkLabel == null, 'one trailing slot'),
        assert(linkLabel == null || onLink != null, 'link needs onLink'),
        assert(title != null || text != null || label != null, 'needs copy');

  /// `jeebRoles.warningContainer` / `onWarningContainer` (23 16).
  const JeebInfoNote.warning({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : tone = JeebInfoNoteTone.warning,
        assert(icon == null || leading == null, 'icon xor leading'),
        assert(text == null || label == null, 'text xor label'),
        assert(trailing == null || linkLabel == null, 'one trailing slot'),
        assert(linkLabel == null || onLink != null, 'link needs onLink'),
        assert(title != null || text != null || label != null, 'needs copy');

  /// White + `1.5px colorScheme.outline`, no shadow (23 15).
  const JeebInfoNote.outlined({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : tone = JeebInfoNoteTone.outlined,
        assert(icon == null || leading == null, 'icon xor leading'),
        assert(text == null || label == null, 'text xor label'),
        assert(trailing == null || linkLabel == null, 'one trailing slot'),
        assert(linkLabel == null || onLink != null, 'link needs onLink'),
        assert(title != null || text != null || label != null, 'needs copy');

  /// `colorScheme.errorContainer` / `onErrorContainer` (11).
  const JeebInfoNote.error({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.text,
    this.label,
    this.trailing,
    this.linkLabel,
    this.onLink,
    this.linkIdentifier,
    this.onTap,
    this.radius = defaultRadius,
    this.padding,
    this.gap,
    this.iconSize,
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : tone = JeebInfoNoteTone.error,
        assert(icon == null || leading == null, 'icon xor leading'),
        assert(text == null || label == null, 'text xor label'),
        assert(trailing == null || linkLabel == null, 'one trailing slot'),
        assert(linkLabel == null || onLink != null, 'link needs onLink'),
        assert(title != null || text != null || label != null, 'needs copy');

  /// r16. The board draws 14 on 11/17 and 16 on 08/12/23; §4.4 collapses both
  /// to `OmdsBorderRadius.medium` at feature level, so one default is honest.
  static const double defaultRadius = 16;

  /// `12/16` — the single-line strip (08 `tpl 500`, 12 `tpl 774`).
  static const EdgeInsetsGeometry stripPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12);

  /// `13/16` — the stacked title/sub panel (23 `tpl 1368`, `tpl 1374`).
  static const EdgeInsetsGeometry stackedPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13);

  /// Gap between glyph, copy and trailing on the strip form.
  static const double stripGap = 10;

  /// Gap on the stacked form — the taller block needs the extra 2px (23).
  static const double stackedGap = 12;

  /// Leading glyph on the strip form (08 17 both draw 17px).
  static const double stripIconSize = 17;

  /// Leading glyph on the stacked form (23's padlock is 19, its check 20).
  static const double stackedIconSize = 19;

  /// The 1.5px stroke of [JeebInfoNoteTone.outlined] — matches
  /// `JeebOutlinedCard`, because it is the same stroke.
  static const double outlineWidth = 1.5;

  /// `line-height: 18px` over the ramp's 12px `bodySmall` (08 `tpl 503`).
  /// Applied to the standalone body line only; the stacked sub-line has no
  /// line-height on the board.
  static const double bodyLineHeight = 18 / 12;

  /// Which fill/ink pair to paint.
  final JeebInfoNoteTone tone;

  /// Leading glyph as an [IconData] — the common case. Mutually exclusive with
  /// [leading].
  final IconData? icon;

  /// Leading glyph as an arbitrary widget — 11's Ø8 accent dot. Mutually
  /// exclusive with [icon]; the kit applies no size or ink to it.
  final Widget? leading;

  /// The w700 first line. **Passing it switches the note to the stacked form**
  /// (23 15), which changes the default padding, gap and glyph size.
  final String? title;

  /// The body line. 23's draft calls this `body:` — it is `text:`.
  final String? text;

  /// Escape hatch for a body that needs its own ink or spans (12 renders
  /// `bodySmall` on `onSurfaceVariant` because periwinkle fails AA on
  /// `surfaceContainerHigh`). Mutually exclusive with [text].
  final Widget? label;

  /// The single trailing slot: 11's meter, 12's code strip, 23's value.
  /// Unstyled by the kit — the call site owns it.
  final Widget? trailing;

  /// Convenience trailing link (17's `Top up`): orange w700, tappable.
  final String? linkLabel;

  /// Required when [linkLabel] is set.
  final VoidCallback? onLink;

  /// Maestro id for the link node, e.g. `offer_composer_wallet_topup_cta`.
  final String? linkIdentifier;

  /// Makes the whole note tappable (12's door-code row routes to the OTP
  /// screen). Painted with an ink splash inside the note's own radius.
  final VoidCallback? onTap;

  /// Corner radius; defaults to [defaultRadius].
  final double radius;

  /// Content padding; defaults to [stripPadding] / [stackedPadding] by form.
  final EdgeInsetsGeometry? padding;

  /// Gap between the row's parts; defaults to [stripGap] / [stackedGap].
  final double? gap;

  /// Leading-glyph size; defaults to [stripIconSize] / [stackedIconSize].
  final double? iconSize;

  /// Leading-glyph ink override. Defaults per tone (08 draws the muted note's
  /// glyph periwinkle; 12 draws the same tone's key navy, so 12 overrides).
  final Color? iconColor;

  /// Maestro id, applied via an explicit `Semantics` wrapper — never OMDS's
  /// own `identifier:`.
  ///
  /// The note adds a `Semantics` node **only** when [identifier] or
  /// [semanticLabel] is set — deliberately narrower than the card primitives,
  /// which also add one for [onTap]. 12's call site is exactly `onTap` + a
  /// consumer-owned outer node (`tracking_handover_code_row`, `button: true`,
  /// `value:`); adding a second node there would bury the frozen id.
  final String? identifier;

  /// Accessibility label for the note node.
  final String? semanticLabel;

  /// Accessibility hint.
  final String? semanticHint;

  /// True when the note renders the stacked title/sub form (23 15).
  bool get isStacked => title != null;

  @override
  Widget build(BuildContext context) {
    final _JeebInfoNoteStyle style = _styleFor(context);
    final double resolvedGap = gap ?? (isStacked ? stackedGap : stripGap);
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    // The board is `box-sizing: border-box`, so the 1.5px stroke sits OUTSIDE
    // the 13px padding. Flutter paints a decoration border over the child, so
    // the stroke has to be folded in or the copy creeps under the outline.
    // Same correction JeebOutlinedCard makes — same stroke, same fix.
    final EdgeInsetsGeometry resolvedPadding =
        (padding ?? (isStacked ? stackedPadding : stripPadding))
            .add(EdgeInsets.all(style.borderInk == null ? 0 : outlineWidth));

    final List<Widget> parts = <Widget>[];
    final Widget? glyph = _buildLeading(style);
    if (glyph != null) {
      parts.add(glyph);
      parts.add(SizedBox(width: resolvedGap));
    }
    parts.add(Expanded(child: _buildCopy(context, style)));
    final Widget? tail = _buildTrailing(context);
    if (tail != null) {
      parts.add(SizedBox(width: resolvedGap));
      parts.add(tail);
    }

    final Widget row = Row(children: parts);

    Widget note = DecoratedBox(
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: borderRadius,
        border: style.borderInk == null
            ? null
            : Border.all(color: style.borderInk!, width: outlineWidth),
        // No boxShadow, on any tone. §4.5 outline-over-shadow.
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: onTap == null
            ? Padding(padding: resolvedPadding, child: row)
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(padding: resolvedPadding, child: row),
                ),
              ),
      ),
    );

    if (identifier != null || semanticLabel != null) {
      note = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: onTap != null,
        // Both flags are mandatory (§7.5): without them this node swallows the
        // link's own id.
        container: true,
        explicitChildNodes: true,
        child: note,
      );
    }

    return note;
  }

  Widget? _buildLeading(_JeebInfoNoteStyle style) {
    if (leading != null) {
      return leading;
    }
    if (icon == null) {
      return null;
    }
    return Icon(
      icon,
      size: iconSize ?? (isStacked ? stackedIconSize : stripIconSize),
      color: iconColor ?? style.glyphInk,
    );
  }

  Widget _buildCopy(BuildContext context, _JeebInfoNoteStyle style) {
    final JeebTextStyles ramp = context.jeebText;
    final Widget? body = label ??
        (text == null
            ? null
            : Text(
                text!,
                style: ramp.bodySmall.copyWith(
                  fontWeight: style.textWeight,
                  color: style.textInk,
                  // lh18 on the standalone line (08's two-line note); the
                  // stacked sub-line has no line-height on the board.
                  height: isStacked ? null : bodyLineHeight,
                ),
              ));

    if (title == null) {
      return body ?? const SizedBox.shrink();
    }

    final Widget heading = Text(
      title!,
      // Board 14/w700; `body` (13.5) is the nearest ramp entry, and §4.2 says
      // derive from the ramp rather than reinvent a size.
      style: ramp.body.copyWith(
        fontWeight: FontWeight.w700,
        color: style.titleInk,
      ),
    );

    if (body == null) {
      return heading;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[heading, body],
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    if (trailing != null) {
      return trailing;
    }
    if (linkLabel == null) {
      return null;
    }
    final Widget link = Text(
      linkLabel!,
      style: context.jeebText.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: context.jeebRoles.accent,
      ),
    );
    // Not MinTapTarget: its 48px minimum would push this 40px strip to ~70 and
    // break the one measurement every consumer of this widget shares. The
    // opaque detector plus its own padding is the largest target the board's
    // geometry affords.
    return Semantics(
      identifier: linkIdentifier,
      button: true,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLink,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
          child: link,
        ),
      ),
    );
  }

  _JeebInfoNoteStyle _styleFor(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebRoles roles = context.jeebRoles;
    // Read the surface tone rather than take an `onNavy` flag: a note dropped
    // inside a selected (navy) card re-tones itself, and the neutral tones are
    // the only ones that can — a success/warning/error panel keeps its role
    // colours everywhere, because the state is the message.
    final JeebSurfaceToneData surface = JeebSurfaceTone.of(context);

    switch (tone) {
      case JeebInfoNoteTone.muted:
        return _JeebInfoNoteStyle(
          fill: surface.chipFill,
          glyphInk: surface.mutedInk,
          titleInk: surface.titleInk,
          textInk: surface.mutedInk,
          textWeight: FontWeight.w500,
        );
      case JeebInfoNoteTone.accent:
        return _JeebInfoNoteStyle(
          fill: surface.chipFill,
          glyphInk: surface.chipInk,
          titleInk: surface.titleInk,
          textInk: surface.chipInk,
          textWeight: FontWeight.w600,
        );
      case JeebInfoNoteTone.success:
        return _JeebInfoNoteStyle(
          fill: roles.successContainer,
          glyphInk: roles.success,
          titleInk: scheme.onSurface,
          textInk: surface.mutedInk,
          textWeight: FontWeight.w500,
        );
      case JeebInfoNoteTone.warning:
        return _JeebInfoNoteStyle(
          fill: roles.warningContainer,
          glyphInk: roles.onWarningContainer,
          titleInk: roles.onWarningContainer,
          textInk: roles.onWarningContainer,
          textWeight: FontWeight.w500,
        );
      case JeebInfoNoteTone.outlined:
        return _JeebInfoNoteStyle(
          // On navy the fill has to disappear, or a white slab lands on the
          // hero; the stroke carries the shape instead.
          fill: surface.onNavy ? Colors.transparent : scheme.surface,
          borderInk: surface.onNavy ? surface.dividerInk : scheme.outline,
          glyphInk: surface.titleInk,
          titleInk: surface.titleInk,
          textInk: surface.mutedInk,
          textWeight: FontWeight.w500,
        );
      case JeebInfoNoteTone.error:
        return _JeebInfoNoteStyle(
          fill: scheme.errorContainer,
          glyphInk: scheme.error,
          titleInk: scheme.onErrorContainer,
          textInk: scheme.onErrorContainer,
          textWeight: FontWeight.w500,
        );
    }
  }
}

/// The resolved fill/ink set for one [JeebInfoNoteTone].
@immutable
class _JeebInfoNoteStyle {
  const _JeebInfoNoteStyle({
    required this.fill,
    required this.glyphInk,
    required this.titleInk,
    required this.textInk,
    required this.textWeight,
    this.borderInk,
  });

  final Color fill;
  final Color glyphInk;
  final Color titleInk;
  final Color textInk;
  final FontWeight textWeight;

  /// Null on every tone but [JeebInfoNoteTone.outlined] — the presence of a
  /// stroke is also what triggers the border-box padding correction.
  final Color? borderInk;
}
