import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import 'jeeb_outlined_card.dart';
import 'jeeb_surface_tone.dart';

/// What sits *inside* the accent frame — the frame form's one measured variable
/// (wave-C ruling 10). Every rung is an existing token; no new value is coined.
///
/// R21's in-motion row measures [accentTint]; R16/R18/R20 are the other frame
/// consumers and are re-measured against this enum, so a tile that lands on the
/// lit rung has [accentSelected] rather than inventing a fourth alpha.
enum JeebAccentFrameFill {
  /// [JeebOutlinedCard]'s rest glass, white 7%. Today's behaviour, and the
  /// default — an accent frame does not imply an accent fill.
  glass,

  /// `accentTint`, orange 12% (the board's 10–12% cluster). R21's in-motion row.
  accentTint,

  /// `accentSelectedFill`, orange 20% — R9's lit rung. Ruled **too hot** for
  /// R21; offered here only for a tile that actually measures it.
  accentSelected,
}

/// The orange-framed card (redesign-2026-08 §5 #5) — the board's "this one is
/// live" treatment.
///
/// Two forms, and the difference is *loud on purpose*: the frame is a highlight,
/// the fill is an alarm.
///
///  * **Unnamed (frame)** — the card's own glass fill, `2px jeebRoles.accent`,
///    radius `JeebRadii.lg`, **no shadow**. 16's active-delivery card, 18's
///    at-door handoff panel, 20's Become-a-Jeeber row, 24's in-motion order row.
///    [fill] swaps the glass rung for an accent tint where a tile measures one.
///  * **[JeebAccentFrameCard.filled]** — `jeebRoles.accent` fill plus
///    `JeebShadows.ctaOrange` (the ratified successor to the dead navy-tinted
///    `accentBanner`), padding `14/16`. Exactly one consumer: 13's arrival
///    banner (`13-otp-handover.html` `tpl 799`).
///
/// It is **not** a fourth card primitive. The frame form is a
/// [JeebOutlinedCard] with `borderColor: accent, borderWidth: 2` — one card
/// implementation, one border-box padding correction, one semantics contract.
/// Only the filled form paints its own surface, because no primitive has an
/// accent fill.
///
/// **Screen 12 is not a consumer.** 12's proposal to restyle `OtpAtDoorCard`
/// with `filled` was cut in review (12 §A-1: the at-door state is not on the
/// board). Do not reintroduce it.
///
/// **Orange budget.** Every screen that uses this spends its single orange
/// element on it (20 R5). If a screen already has an accent CTA or an accent
/// disc, it should not also have an accent frame.
class JeebAccentFrameCard extends StatelessWidget {
  const JeebAccentFrameCard({
    super.key,
    required this.child,
    this.radius = JeebRadii.lg,
    this.padding = defaultPadding,
    this.borderWidth = 2,
    this.fill = JeebAccentFrameFill.glass,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : filled = false;

  /// 13's arrival banner: accent fill + [JeebShadows.ctaOrange]. The one place
  /// on the board where orange is a surface rather than an outline.
  const JeebAccentFrameCard.filled({
    super.key,
    required this.child,
    this.radius = JeebRadii.lg,
    this.padding = filledPadding,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : filled = true,
        borderWidth = 0,
        fill = JeebAccentFrameFill.glass;

  /// `13/16` — the frame form's padding (16 `tpl 1179`, 20 §3.4). 18 passes 16
  /// all round; 24 passes `14/16`.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13);

  /// `14/16` — 13's banner (`tpl 799`).
  static const EdgeInsetsGeometry filledPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14);

  /// Card content.
  final Widget child;

  /// Corner radius; the board's 16s and 18s both snap to `JeebRadii.lg` (§5).
  final double radius;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode
  /// left/right.
  final EdgeInsetsGeometry padding;

  /// Frame width (`2` — this is the one card whose border is not 1.5). Always 0
  /// for [JeebAccentFrameCard.filled].
  final double borderWidth;

  /// Which fill sits inside the frame. Ignored by
  /// [JeebAccentFrameCard.filled], which is a solid accent surface.
  final JeebAccentFrameFill fill;

  /// Makes the whole card tappable (20's row, 24's order row).
  final VoidCallback? onTap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`). No node is added when
  /// this, [semanticLabel] and [onTap] are all null — so a screen that owns the
  /// id itself can nest its own wrapper inside.
  final String? identifier;

  /// Accessibility label for the card node.
  final String? semanticLabel;

  /// Accessibility hint.
  final String? semanticHint;

  /// True for [JeebAccentFrameCard.filled].
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      // One card implementation. The frame form is literally the outlined card
      // with a different stroke, so it inherits the border-box padding
      // correction, the clip, the ink splash and the semantics contract.
      final ThemeData theme = Theme.of(context);
      final ThemeData? tinted = _tintedTheme(theme);
      final Widget card = JeebOutlinedCard(
        radius: radius,
        padding: padding,
        borderColor: context.jeebRoles.accent,
        borderWidth: borderWidth,
        onTap: onTap,
        identifier: identifier,
        semanticLabel: semanticLabel,
        semanticHint: semanticHint,
        // The tint is scoped to the card's own decoration: the content reads
        // the real theme back, so a nested kit widget still sees true glass.
        child: tinted == null ? child : Theme(data: theme, child: child),
      );
      return tinted == null ? card : Theme(data: tinted, child: card);
    }

    final JeebRoles roles = context.jeebRoles;
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: roles.accent,
        borderRadius: borderRadius,
        boxShadow: JeebShadows.ctaOrange,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(padding: padding, child: child),
                ),
              ),
      ),
    );

    if (identifier != null || semanticLabel != null || onTap != null) {
      surface = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: onTap != null,
        // Both flags are mandatory (§7.5): without them this node swallows the
        // ids of everything the consumer nests inside.
        container: true,
        explicitChildNodes: true,
        child: surface,
      );
    }

    return JeebSurfaceTone(tone: _filledTone(roles), child: surface);
  }

  /// [theme] with ONLY `glassFill` re-pointed at [fill]'s rung, or null when
  /// [fill] is the default glass.
  ///
  /// A layered tint would composite over the white-7% glass instead of
  /// replacing it (navy+orange12%+white7% is visibly greyer than the measured
  /// navy+orange12%), and [JeebOutlinedCard] takes no fill override — so the
  /// rung is swapped in the theme the card reads, not painted on top of it.
  ThemeData? _tintedTheme(ThemeData theme) {
    if (fill == JeebAccentFrameFill.glass) {
      return null;
    }
    final JeebSemanticColors semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final Color tint = fill == JeebAccentFrameFill.accentTint
        ? semantics.accentTint
        : semantics.accentSelectedFill;
    final List<ThemeExtension<dynamic>> extensions =
        theme.extensions.values.toList()
          ..add(semantics.copyWith(glassFill: tint));
    return theme.copyWith(extensions: extensions);
  }

  /// The filled banner is a dark surface with light ink, so kit children inside
  /// it must re-tone exactly as they do on navy.
  ///
  /// [JeebSurfaceKind] has two values and no third is added here — that file
  /// belongs to the card primitives. `navy` is the "light ink on a saturated
  /// fill" kind, which is what a consumer means when it reads `tone.onNavy`;
  /// the *inks* are the accent surface's own (`onAccent`, `#FFFFFF`), not the
  /// navy card's. The alphas match `JeebSurfaceToneData.navy` so a chip looks
  /// the same on both.
  JeebSurfaceToneData _filledTone(JeebRoles roles) {
    final Color ink = roles.onAccent;
    return JeebSurfaceToneData(
      kind: JeebSurfaceKind.navy,
      titleInk: ink,
      mutedInk: ink.withValues(alpha: 0.7),
      chipFill: ink.withValues(alpha: 0.14),
      chipInk: ink,
      meterFill: ink,
      meterEmpty: ink.withValues(alpha: 0.25),
      dividerInk: ink.withValues(alpha: 0.14),
    );
  }
}
