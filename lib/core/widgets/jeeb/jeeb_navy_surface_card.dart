import 'package:flutter/material.dart';

import '../../theme/jeeb_semantic_colors.dart';
import 'jeeb_surface_tone.dart';

/// Which ink a decorative [JeebNavyRing] is stroked in.
enum JeebNavyRingInk {
  /// `JeebSemanticColors.accentRing` — orange at 30%. The board default
  /// (04 `tpl 167`, 19 `tpl 23`, 23 `tpl 21`, 02's inner ring).
  accent,

  /// `colorScheme.onPrimary` at 8% — 02's outer band ring only.
  onPrimaryFaint,
}

/// One off-canvas decorative circle on a navy surface.
///
/// Positioned with `PositionedDirectional`, so it mirrors under RTL — 19 §7.1
/// calls a `Positioned(right:)` here a kit bug, and it would be.
@immutable
class JeebNavyRing {
  const JeebNavyRing({
    required this.diameter,
    this.top,
    this.bottom,
    this.start,
    this.end,
    this.ink = JeebNavyRingInk.accent,
    this.strokeWidth = 1.5,
  });

  /// 04's request hero: Ø140 at top-END, offset −40/−40 (`tpl 167`).
  static const JeebNavyRing heroTopEnd =
      JeebNavyRing(diameter: 140, top: -40, end: -40);

  /// 19's earnings hero: Ø160 at top-END, offset −50/−50 (`tpl 23`).
  static const JeebNavyRing statTopEnd =
      JeebNavyRing(diameter: 160, top: -50, end: -50);

  /// 23's wallet hero: Ø170 at **bottom**-END, offset −50/−50 (`tpl 21`).
  /// The corner is a parameter precisely because 23 disagrees with 04/19.
  static const JeebNavyRing statBottomEnd =
      JeebNavyRing(diameter: 170, bottom: -50, end: -50);

  /// 02's outer band ring: Ø200 at top-END, white 8% (`tpl 12`).
  static const JeebNavyRing bandOuter = JeebNavyRing(
    diameter: 200,
    top: -60,
    end: -60,
    ink: JeebNavyRingInk.onPrimaryFaint,
  );

  /// 02's inner band ring: Ø120 at top-END (`tpl 13`).
  static const JeebNavyRing bandInner =
      JeebNavyRing(diameter: 120, top: -24, end: -24);

  /// Circle diameter in logical px (140–200 on the board).
  final double diameter;

  /// Directional offsets; negative values push the circle off-canvas. The clip
  /// is what turns it into the arc the renders show.
  final double? top;
  final double? bottom;
  final double? start;
  final double? end;

  /// Stroke ink.
  final JeebNavyRingInk ink;

  /// Stroke width; 1.5 everywhere on the board.
  final double strokeWidth;
}

/// The navy surface (redesign-2026-08 §5 #4).
///
/// `colorScheme.primary` fill, parametric radius (14–24) and a parametric
/// shadow **including none** — 04's r24 hero has no shadow at all; it reads as
/// a surface because of the clip plus the accent ring.
///
/// This is also the `selected` state of `JeebOutlinedCard`: selection is a
/// **fill swap, never a thicker border**. Because it publishes
/// [JeebSurfaceTone] to its subtree, every kit child inside it re-tones itself
/// (chip `rgba(255,255,255,.14)` / ink `.7` / empty dots `.25`) with nothing for
/// the consumer to remember.
///
/// Always clipped: the decorative rings depend on it, and no board element
/// overhangs a navy card.
class JeebNavySurfaceCard extends StatelessWidget {
  const JeebNavySurfaceCard({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding = defaultPadding,
    this.shadow = noShadow,
    this.rings = const <JeebNavyRing>[],
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
    this.selected = false,
  }) : topBand = false;

  /// The full-bleed band mode — screen 02's registration hero, its only
  /// consumer. Bottom-only radius (`0 0 36 36`), no shadow, and the status-bar
  /// inset folded into the top padding so the band paints under it.
  const JeebNavySurfaceCard.topBand({
    super.key,
    required this.child,
    this.radius = 36,
    this.padding = topBandPadding,
    this.shadow = noShadow,
    this.rings = const <JeebNavyRing>[],
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
    this.selected = false,
  }) : topBand = true;

  /// Explicit "no elevation". Named rather than nullable so `shadow: none` is a
  /// visible decision at the call site (§5 #4).
  static const List<BoxShadow> noShadow = <BoxShadow>[];

  /// `0 10 22 rgba(11,19,81,.28)` — the selected state of `JeebOutlinedCard`
  /// (08's chosen tier). Deliberately **not** `JeebShadows.ctaNavy`, which is
  /// `0 10 24`; the CTA pill and the selected card are different values and
  /// per-screen-revised/08 §3 pins the difference.
  static const List<BoxShadow> selectedShadow = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.28),
      offset: Offset(0, 10),
      blurRadius: 22,
    ),
  ];

  /// `0 8 20 rgba(11,19,81,.25)` — 21's pinned summary strip. (16's availability
  /// strip is `JeebShadows.ctaNavy`; wiring/16 §4 corrects the plan on that.)
  static const List<BoxShadow> stripShadow = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.25),
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// 14/16 — the one-line strip padding (16 `tpl 907`). Heroes pass 18–20.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14);

  /// 02's band padding, before the status-bar inset is added.
  static const EdgeInsetsGeometry topBandPadding =
      EdgeInsetsDirectional.fromSTEB(24, 16, 24, 32);

  /// Card content. Wrap it in your own `Semantics(container: true,
  /// explicitChildNodes: true)` when the id belongs to the content rather than
  /// the card (23 does this so the ring stays out of the node).
  final Widget child;

  /// Corner radius in logical px — 14 (21) · 16 (08 16) · 18 (20) · 20 (19 23) ·
  /// 24 (04). Design-exact px are legal here (§4.4 two-tier rule).
  final double radius;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode
  /// left/right.
  final EdgeInsetsGeometry padding;

  /// Elevation. [noShadow] · [selectedShadow] · [stripShadow] ·
  /// `JeebShadows.ctaNavy` · `JeebShadows.heroNavy`.
  final List<BoxShadow> shadow;

  /// Decorative off-canvas circles, painted behind the content and clipped.
  final List<JeebNavyRing> rings;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label for the card node.
  final String? semanticLabel;

  /// Accessibility hint (08 passes `tierSelectionCardSelectedHint`).
  final String? semanticHint;

  /// Reports `Semantics.selected` — set by `JeebOutlinedCard` when this card is
  /// standing in for its selected state.
  final bool selected;

  /// True for [JeebNavySurfaceCard.topBand].
  final bool topBand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadiusGeometry borderRadius = topBand
        ? BorderRadiusDirectional.only(
            bottomStart: Radius.circular(radius),
            bottomEnd: Radius.circular(radius),
          )
        : BorderRadius.circular(radius);

    // The band paints under the status bar, so its inset belongs in the padding
    // rather than in a SafeArea the consumer would have to remember.
    final EdgeInsetsGeometry resolvedPadding = topBand
        ? padding.add(EdgeInsets.only(top: MediaQuery.paddingOf(context).top))
        : padding;

    Widget content = Padding(padding: resolvedPadding, child: child);

    if (rings.isNotEmpty) {
      content = Stack(
        children: <Widget>[
          for (final JeebNavyRing ring in rings)
            PositionedDirectional(
              top: ring.top,
              bottom: ring.bottom,
              start: ring.start,
              end: ring.end,
              child: IgnorePointer(
                child: Container(
                  width: ring.diameter,
                  height: ring.diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _ringInk(context, ring.ink, scheme),
                      width: ring.strokeWidth,
                    ),
                  ),
                ),
              ),
            ),
          content,
        ],
      );
    }

    // Ink splashes must land above the navy fill, so the Material sits inside
    // the DecoratedBox rather than around it.
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: borderRadius,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: onTap == null
            ? content
            : Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );

    if (identifier != null || semanticLabel != null || onTap != null) {
      surface = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: onTap != null,
        selected: selected ? true : null,
        // Both flags are mandatory (§7.5): without them this node swallows the
        // ids of everything the consumer nests inside.
        container: true,
        explicitChildNodes: true,
        child: surface,
      );
    }

    return JeebSurfaceTone(
      tone: JeebSurfaceToneData.navy(context),
      child: surface,
    );
  }

  Color _ringInk(
    BuildContext context,
    JeebNavyRingInk ink,
    ColorScheme scheme,
  ) {
    switch (ink) {
      case JeebNavyRingInk.accent:
        // Defensive read: a bare `!` crashes under harnesses that theme with
        // ThemeData.light() (see `wrapForTest`).
        final JeebSemanticColors semantics =
            Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light();
        return semantics.accentRing;
      case JeebNavyRingInk.onPrimaryFaint:
        return scheme.onPrimary.withValues(alpha: 0.08);
    }
  }
}
