import 'package:flutter/material.dart';

import '../../theme/jeeb_text_styles.dart';
import '../directional_icons.dart';
import 'jeeb_surface_tone.dart';

/// A navigation row inside a grouped card (MIDNIGHT R19/R22/R23).
///
/// Padding `11/14`, gap 12; leading glyph 19px ink; title `body` w700 ink;
/// subtitle `caption` `mutedText`; trailing 16px `mutedText` chevron via
/// [DirectionalIcons.disclosure].
///
/// ## The divider is NOT drawn here
///
/// §5 #25 says "inset 1px `outlineVariant` divider between rows" — that rule
/// belongs to the card, not the row, because only the card knows which row is
/// last. Compose:
///
/// ```dart
/// JeebOutlinedCard.grouped(
///   radius: 16,
///   children: <Widget>[
///     JeebListRow(icon: Icons.show_chart, title: …, subtitle: …, onTap: …),
///     JeebListRow(icon: Icons.article,    title: …, subtitle: …, onTap: …),
///   ],
/// )
/// ```
///
/// A row also works standalone in a plain [JeebOutlinedCard] — that is 20's
/// sign-out row, which passes `showChevron: false`.
///
/// ## Ink comes from the surface, not from a flag
///
/// Title/subtitle/chevron read [JeebSurfaceTone], so a row dropped on a navy
/// card re-tones itself. There is deliberately no `onNavy` parameter.
///
/// ## Semantics
///
/// A node is added **only** when [identifier] or [semanticLabel] is set, and it
/// merges the title, subtitle and tap action into one labelled button — the
/// same shape `wallet_hub_screen.dart` emits today. When the consumer already
/// owns the node (`Semantics(identifier: 'wallet_earnings_row', button: true,
/// container: true, child: JeebListRow(…))`), pass neither and the row adds
/// nothing, so there is never a second button node inside the first. If your
/// [trailing] carries its own identifier, own the outer node yourself — this
/// row merges rather than using `explicitChildNodes`, which is what makes it
/// read as one sentence aloud.
class JeebListRow extends StatelessWidget {
  const JeebListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconSize = 19,
    this.iconColor,
    this.trailing,
    this.showChevron = true,
    this.chevronSize = 16,
    this.titleStyle,
    this.subtitleStyle,
    this.padding = defaultPadding,
    this.gap = 12,
    this.isEnabled = true,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  });

  /// `11/14` — R19's rows, and the doc-13 Pattern E metric fix (was 14/16, one
  /// size class too loose). Grouped card rows pass R22's 13/16.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 11);

  /// Opacity applied when [isEnabled] is false (20's sign-out row while a
  /// sign-out is in flight).
  static const double disabledOpacity = 0.5;

  /// Row title — the fact, so it takes the surface's title ink.
  final String title;

  /// Optional second line. 20's toggle rows drop theirs; its navigation rows
  /// (and both of 23's) keep it.
  final String? subtitle;

  /// Leading glyph. Filled, single-colour (R10 — no outline variants:
  /// `Icons.show_chart` / `Icons.article`, not their `_outlined` twins).
  final IconData? icon;

  /// Leading glyph size — 19 on 23, 18 on 20's sign-out row.
  final double iconSize;

  /// Leading glyph ink. Defaults to the surface tone's title ink.
  final Color? iconColor;

  /// Replaces the chevron entirely (a value, a switch, a badge).
  final Widget? trailing;

  /// Whether the disclosure chevron is drawn. False for a row that acts in
  /// place rather than navigating — 20's sign-out row (kit ask K2).
  final bool showChevron;

  /// Chevron size (16 on 23).
  final double chevronSize;

  /// Title style, **merged over** the default rather than replacing it — so
  /// 20's sign-out row can pass `jeebText.body.copyWith(fontWeight:
  /// FontWeight.w600)` and still inherit the surface's ink.
  final TextStyle? titleStyle;

  /// Subtitle style, merged over the default the same way.
  final TextStyle? subtitleStyle;

  /// Row padding. Directional — never hardcode left/right.
  final EdgeInsetsGeometry padding;

  /// Gap between glyph, text block and trailing (12 on 23).
  final double gap;

  /// When false the row is dimmed and does not respond to taps.
  final bool isEnabled;

  /// Tap handler. A row with none still renders (a static list line).
  final VoidCallback? onTap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper — never OMDS's own `identifier:` parameter.
  final String? identifier;

  /// Overrides the merged title+subtitle announcement.
  final String? semanticLabel;

  /// Accessibility hint.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final JeebTextStyles text = context.jeebText;

    // R22 inks the glyph and the title with the same white; orange here would
    // spend the accent budget on chrome.
    final Color primaryInk = tone.titleInk;

    // Merged, not replaced: a lane overriding the weight must not silently
    // lose the surface ink.
    final TextStyle titleInk = text.body
        .copyWith(fontWeight: FontWeight.w700, color: primaryInk)
        .merge(titleStyle);
    final TextStyle subtitleInk =
        text.caption.copyWith(color: tone.mutedInk).merge(subtitleStyle);

    final Widget? trailingWidget = _trailing(context, tone);
    final Widget row = Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: iconSize, color: iconColor ?? primaryInk),
          SizedBox(width: gap),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: titleInk),
              if (subtitle != null) Text(subtitle!, style: subtitleInk),
            ],
          ),
        ),
        if (trailingWidget != null) ...<Widget>[
          SizedBox(width: gap),
          trailingWidget,
        ],
      ],
    );

    final bool tappable = onTap != null && isEnabled;
    Widget surface = Padding(padding: padding, child: row);
    if (tappable) {
      // Material inside the row, so the splash lands above the card fill and
      // consumers never need their own.
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: surface),
      );
    }
    if (!isEnabled) {
      surface = Opacity(opacity: disabledOpacity, child: surface);
    }

    if (identifier == null && semanticLabel == null) {
      return surface;
    }
    // With a caller-supplied label the child text has to be excluded, or the
    // node announces both; excluding it also drops the InkWell's action, so
    // re-declare the tap on the node itself.
    final bool overridesLabel = semanticLabel != null;
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      hint: semanticHint,
      button: tappable,
      enabled: onTap == null ? null : isEnabled,
      onTap: overridesLabel && tappable ? onTap : null,
      container: true,
      child: overridesLabel ? ExcludeSemantics(child: surface) : surface,
    );
  }

  Widget? _trailing(BuildContext context, JeebSurfaceToneData tone) {
    if (trailing != null) return trailing;
    if (!showChevron) return null;
    return Icon(
      DirectionalIcons.disclosure(context),
      size: chevronSize,
      color: tone.mutedInk,
    );
  }
}
