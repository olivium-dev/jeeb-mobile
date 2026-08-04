import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';

/// Defensive read: harnesses that theme without the extension must not crash.
JeebSemanticColors _glassOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

/// The rest glass card — token sheet §4.
///
/// `glassFill` (white 7%) behind a 1px `glassBorder` (white 12%) at
/// [JeebRadii.lg], and **no blur**: the translucency is pre-baked, which is what
/// keeps low-end Android affordable. Spends no orange.
class JeebGlassCard extends StatelessWidget {
  const JeebGlassCard({
    super.key,
    required this.child,
    this.padding = defaultPadding,
    this.radius = JeebRadii.lg,
    this.shadow = noShadow,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  });

  /// R1's rest cards draw 16 all round (board `padding:16px`, and `13 16` on the
  /// tighter twin — call sites pass their own).
  static const EdgeInsetsGeometry defaultPadding = EdgeInsets.all(16);

  /// Explicit "no elevation": §7 retires the legacy `card` shadow to none, and
  /// rest glass reads as a surface from its fill and border alone.
  static const List<BoxShadow> noShadow = <BoxShadow>[];

  /// Card content. Wrap it in your own `Semantics` when the id belongs to the
  /// content rather than to the card.
  final Widget child;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode
  /// left/right. No min-height is imposed — doc-13 Pattern E.
  final EdgeInsetsGeometry padding;

  /// Corner radius; a rung of [JeebRadii] (§5 ladder, ±2 tolerance).
  final double radius;

  /// Elevation. [noShadow] here; `JeebShadows.overlay` for a floating chip.
  final List<BoxShadow> shadow;

  /// Makes the whole card tappable, with the white-alpha glass splash.
  final VoidCallback? onTap;

  /// Maestro / `find.bySemanticsIdentifier` id.
  final String? identifier;

  /// Accessibility label for the card node.
  final String? semanticLabel;

  /// Accessibility hint for the card node.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors glass = _glassOf(context);
    return _GlassSurface(
      fill: glass.glassFill,
      borderColor: glass.glassBorder,
      radius: radius,
      padding: padding,
      shadow: shadow,
      blurSigma: 0,
      onTap: onTap,
      identifier: identifier,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      child: child,
    );
  }
}

/// The hero glass capsule — token sheet §4.
///
/// `glassFillEmphasis` (white 10%), a 1px `glassBorderStrong` (white 16%),
/// [JeebRadii.pill] (the board's voice capsule; [JeebRadii.capsule] is the other
/// sanctioned rung) and a **real** `BackdropFilter` at [blurSigma].
///
/// Budget: **≤2 real BackdropFilters per screen**, hero surfaces only (§4) —
/// every other translucent surface is a [JeebGlassCard].
class JeebGlassCapsule extends StatelessWidget {
  const JeebGlassCapsule({
    super.key,
    required this.child,
    this.padding = defaultPadding,
    this.radius = JeebRadii.pill,
    this.blurSigma = standardBlur,
    this.shadow = JeebShadows.floatNav,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  });

  /// The §4 blur ladder: soft 8 · standard 10 · hero 12.
  static const double softBlur = 8;
  static const double standardBlur = 10;
  static const double heroBlur = 12;

  /// R1's voice capsule: a leading disc inset by 10, text side 18.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.fromSTEB(10, 10, 18, 10);

  /// Explicit "no lift", for a capsule that sits inside another elevated
  /// surface.
  static const List<BoxShadow> noShadow = <BoxShadow>[];

  /// Capsule content.
  final Widget child;

  /// Content padding. No min-height is imposed — doc-13 Pattern E.
  final EdgeInsetsGeometry padding;

  /// Corner radius; [JeebRadii.pill] or [JeebRadii.capsule].
  final double radius;

  /// `BackdropFilter` sigma. Zero drops the filter entirely, which is the point
  /// of [JeebGlassCard] — use that instead of `blurSigma: 0` here.
  final double blurSigma;

  /// Elevation; `JeebShadows.floatNav` by default (the board draws a lift under
  /// every hero capsule).
  final List<BoxShadow> shadow;

  /// Makes the whole capsule tappable, with the white-alpha glass splash.
  final VoidCallback? onTap;

  /// Maestro / `find.bySemanticsIdentifier` id.
  final String? identifier;

  /// Accessibility label for the capsule node.
  final String? semanticLabel;

  /// Accessibility hint for the capsule node.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors glass = _glassOf(context);
    return _GlassSurface(
      fill: glass.glassFillEmphasis,
      borderColor: glass.glassBorderStrong,
      radius: radius,
      padding: padding,
      shadow: shadow,
      blurSigma: blurSigma,
      onTap: onTap,
      identifier: identifier,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      child: child,
    );
  }
}

/// The one glass recipe both primitives paint: fill + 1px border + radius, with
/// the blur and the shadow as the only variables.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.fill,
    required this.borderColor,
    required this.radius,
    required this.padding,
    required this.shadow,
    required this.blurSigma,
    required this.onTap,
    required this.identifier,
    required this.semanticLabel,
    required this.semanticHint,
  });

  final Widget child;
  final Color fill;
  final Color borderColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadow;
  final double blurSigma;
  final VoidCallback? onTap;
  final String? identifier;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors glass = _glassOf(context);
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: glass.glassFillPressed,
          highlightColor: glass.glassFill,
          child: content,
        ),
      );
    }

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: content,
    );

    if (blurSigma > 0) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    }

    surface = ClipRRect(borderRadius: borderRadius, child: surface);

    // The lift has to sit outside the clip, or the clip eats it.
    if (shadow.isNotEmpty) {
      surface = DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
        child: surface,
      );
    }

    if (identifier != null || semanticLabel != null || onTap != null) {
      surface = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: onTap != null,
        container: true,
        explicitChildNodes: true,
        child: surface,
      );
    }

    return surface;
  }
}
