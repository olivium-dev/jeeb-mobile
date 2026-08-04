import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import 'jeeb_surface_tone.dart';

/// Which ink a decorative [JeebNavyRing] is stroked in.
enum JeebNavyRingInk {
  /// `JeebSemanticColors.accentRing` — orange at 30%. The board default
  /// (04 `tpl 167`, 19 `tpl 23`, 23 `tpl 21`, 02's inner ring).
  accent,

  /// Ink at 8% — the board's quiet white orbit arc (sheet §8). Named
  /// `onPrimaryFaint` for API stability; it reads `onSurface`, never orange.
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

  /// 02's outer band ring: Ø200 at top-END, ink 8% (`tpl 12`).
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

/// The emphasis surface (MIDNIGHT sheet §4 hero glass).
///
/// `glassFillEmphasis` fill + 1px `glassBorderStrong`, parametric radius and a
/// parametric shadow **including none** — the board's heroes and pinned strips
/// carry no lift; the fill step and the stroke are what raise them. No
/// `BackdropFilter`: the ≤2-per-screen blur budget belongs to the screen.
///
/// This is also the `selected` state of `JeebOutlinedCard`: selection is a
/// **fill swap, never a thicker border**. Because it publishes
/// [JeebSurfaceTone] to its subtree, every kit child inside it re-tones itself
/// with nothing for the consumer to remember.
///
/// Always clipped: the decorative rings depend on it, and no board element
/// overhangs a navy card.
class JeebNavySurfaceCard extends StatelessWidget {
  const JeebNavySurfaceCard({
    super.key,
    required this.child,
    this.radius = JeebRadii.lg,
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
  /// consumer. Bottom-only `hero` radius, no shadow, no stroke, and the
  /// status-bar inset folded into the top padding so the band paints under it.
  const JeebNavySurfaceCard.topBand({
    super.key,
    required this.child,
    this.radius = JeebRadii.hero,
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

  /// The selected state of `JeebOutlinedCard`. Wave-A: **none** — the fill swap
  /// IS the selection; a glow ships only where a tile draws one (opt in with
  /// `selectedShadow: JeebShadows.glowRest`, or use `accentSelected`).
  static const List<BoxShadow> selectedShadow = noShadow;

  /// 21's pinned summary strip — a small floating surface, so `overlay`.
  static const List<BoxShadow> stripShadow = JeebShadows.overlay;

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

  /// Corner radius — a [JeebRadii] rung; heroes pass `xl`/`sheet`.
  final double radius;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode
  /// left/right.
  final EdgeInsetsGeometry padding;

  /// Elevation. [noShadow] · [selectedShadow] · [stripShadow] ·
  /// `JeebShadows.floatNav`.
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
    final JeebSemanticColors semantics = _semantics(context);
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
        : padding.add(const EdgeInsets.all(_borderWidth));

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
                      color: _ringInk(ring.ink, scheme, semantics),
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
        color: semantics.glassFillEmphasis,
        borderRadius: borderRadius,
        // A full-bleed band has no edges to stroke but the bottom curve.
        border: topBand
            ? null
            : Border.all(color: semantics.glassBorderStrong),
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
    JeebNavyRingInk ink,
    ColorScheme scheme,
    JeebSemanticColors semantics,
  ) {
    switch (ink) {
      case JeebNavyRingInk.accent:
        return semantics.accentRing;
      case JeebNavyRingInk.onPrimaryFaint:
        return scheme.onSurface.withValues(alpha: 0.08);
    }
  }
}

/// The 1px stroke every glass surface carries (sheet §4).
const double _borderWidth = 1;

/// Defensive read: a bare `!` crashes under harnesses that theme with
/// `ThemeData.light()` (see `wrapForTest`).
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
