import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';
import 'jeeb_surface_tone.dart';

/// The realized avatar disc fills (redesign-2026-08 §5 #9).
///
/// [primary], [muted] and [accent] are the three slots of the stack's fill
/// rotation (04 `tpl 208-210`); [dormant] is the honest "we do not know this
/// person" mark; [onAccent] only exists on 13's orange arrival banner.
enum JeebAvatarFill {
  /// Navy `colorScheme.primary` + white ink — 21's Karim, 12's courier, 16's O.
  ///
  /// Re-tones on a navy surface (20 `tpl 1172`): a navy disc on a navy card is
  /// invisible, so it becomes the published chip tone (`onPrimary` @ 14 %).
  primary,

  /// Periwinkle `JeebSemanticColors.mutedText` + white ink — 04's `N`, 11's Nour.
  muted,

  /// `jeebRoles.accent` + `onAccent` ink — 04's `R`.
  accent,

  /// Unknown / no name on file: `surfaceContainerHighest` + periwinkle initial
  /// (11's Rami `tpl 696`, 04's own user). Never fabricate a name to avoid it.
  dormant,

  /// On the orange banner: `onAccent` @ 20 % + `onAccent` ink (13 `tpl 800`).
  onAccent;

  /// The stack's fill rotation, in board order (04 `tpl 208-210`).
  static const List<JeebAvatarFill> rotation = <JeebAvatarFill>[
    JeebAvatarFill.primary,
    JeebAvatarFill.muted,
    JeebAvatarFill.accent,
  ];

  /// The fill for slot [index] of a stack, wrapping every three.
  static JeebAvatarFill forIndex(int index) =>
      rotation[index % rotation.length];
}

/// The Ø12 corner dot. One shape, two meanings, both **directional**.
enum JeebAvatarDot {
  /// `jeebRoles.success` at the **bottom-END** — the counterpart is online (21).
  presence,

  /// `jeebRoles.accent` at the **top-END** — unread activity (04).
  unread,
}

/// The Ø26 corner badge (15's ratee identity).
enum JeebAvatarBadge {
  /// Orange disc + 3px `colorScheme.surface` ring + 13px white check at the
  /// bottom-END. A **completion** mark — never "verified": on the `?mode=jeeber`
  /// leg the ratee is a customer with no KYC.
  completed,
}

/// The Jeeb identity disc (redesign-2026-08 §5 #9).
///
/// Four realized sizes — [JeebAvatar.stack] Ø30, [JeebAvatar.thread] Ø42,
/// [JeebAvatar.header] Ø46, [JeebAvatar.hero] Ø74 — plus the unnamed
/// constructor for the two off-table diameters the board also draws (16's Ø44,
/// 20's Ø50).
///
/// It **composes `OmdsProfileAvatar`** rather than re-implementing the
/// photo→initial fallback: five shipped tests match on that type
/// (`client_home_greeting_test.dart:75`, `offer_card_test.dart:219`,
/// `jeeber_feed_card_test.dart:83`, …). Pass [avatarKey] to put a `Key` on the
/// composed avatar so `tester.widget<OmdsProfileAvatar>(find.byKey(…))` keeps
/// working; the widget's own `key` stays on the `JeebAvatar`.
class JeebAvatar extends StatelessWidget {
  const JeebAvatar({
    super.key,
    required this.initial,
    this.diameter = threadDiameter,
    this.initialSize,
    this.fill = JeebAvatarFill.primary,
    this.imageUrl,
    this.dot,
    this.badge,
    this.ringWidth = 0,
    this.ringColor,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.avatarKey,
  }) : assert(
          dot == null || badge == null,
          'A dot and a badge occupy the same corner — pass one.',
        );

  /// Ø30 + a 2px surface ring — the overlapped run on 04's replies card.
  /// [JeebAvatarStack] builds these; use it directly for a lone ringed disc.
  const JeebAvatar.stack({
    super.key,
    required this.initial,
    this.fill = JeebAvatarFill.primary,
    this.imageUrl,
    this.ringColor,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.avatarKey,
  })  : diameter = stackDiameter,
        initialSize = 11,
        ringWidth = stackRingWidth,
        dot = null,
        badge = null;

  /// Ø42 / 15px initial — list and thread rows (11, 12, 13, 21).
  const JeebAvatar.thread({
    super.key,
    required this.initial,
    this.fill = JeebAvatarFill.primary,
    this.imageUrl,
    this.dot,
    this.badge,
    this.ringWidth = 0,
    this.ringColor,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.avatarKey,
  })  : diameter = threadDiameter,
        initialSize = 15,
        assert(
          dot == null || badge == null,
          'A dot and a badge occupy the same corner — pass one.',
        );

  /// Ø46 / 17px initial — the screen header inside `JeebProfileHeader` (04, 16, 19).
  const JeebAvatar.header({
    super.key,
    required this.initial,
    this.fill = JeebAvatarFill.primary,
    this.imageUrl,
    this.dot,
    this.ringWidth = 0,
    this.ringColor,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.avatarKey,
  })  : diameter = headerDiameter,
        initialSize = 17,
        badge = null;

  /// Ø74 / 26px initial — 15's ratee identity block.
  const JeebAvatar.hero({
    super.key,
    required this.initial,
    this.fill = JeebAvatarFill.primary,
    this.imageUrl,
    this.badge,
    this.ringWidth = 0,
    this.ringColor,
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.avatarKey,
  })  : diameter = heroDiameter,
        initialSize = 26,
        dot = null;

  /// 04 `tpl 208`.
  static const double stackDiameter = 30;

  /// 21 `tpl 1236`, 11 `tpl 668`, 12 `tpl 766`, 13 `tpl 800`.
  static const double threadDiameter = 42;

  /// 04 `tpl 159`. (16 draws 44 and 20 draws 50 — pass [diameter].)
  static const double headerDiameter = 46;

  /// 15 `tpl 863`.
  static const double heroDiameter = 74;

  /// The 2px surface ring that separates overlapping stack discs.
  static const double stackRingWidth = 2;

  /// The stack's negative overlap, applied directionally (04 `tpl 209`).
  static const double stackOverlap = 9;

  /// Ø12 + a 2px surface ring, offset −1 into the corner (04 `tpl 160`,
  /// 21 `tpl 1237`).
  static const double dotDiameter = 12;

  /// Ring around [dotDiameter].
  static const double dotRingWidth = 2;

  /// How far the dot's outer edge sits past the disc.
  static const double dotOffset = -1;

  /// Ø26 + a 3px surface ring, offset −4 (15 `tpl 864`).
  static const double badgeDiameter = 26;

  /// Ring around [badgeDiameter].
  static const double badgeRingWidth = 3;

  /// How far the badge's outer edge sits past the disc.
  static const double badgeOffset = -4;

  /// The check inside a [JeebAvatarBadge.completed] badge.
  static const double badgeGlyphSize = 13;

  /// Every realized size sits within a rounding of `0.36 × Ø`; the four exact
  /// values are hardcoded in [initialSizeFor], this covers the rest.
  static const double initialSizeRatio = 0.36;

  /// Key on the corner [dot], so a consumer or a test can address it without
  /// reaching for a private type.
  static const Key dotKey = ValueKey<String>('jeeb_avatar.dot');

  /// Key on the corner [badge].
  static const Key badgeKey = ValueKey<String>('jeeb_avatar.badge');

  /// The letter, or the display name it should be derived from — the first
  /// non-blank character is used, `?` when there is none.
  final String initial;

  /// Disc diameter in logical px. Design-exact px are legal here (§4.4).
  final double diameter;

  /// Initial font size; defaults to [initialSizeFor].
  final double? initialSize;

  /// Which disc fill this identity gets.
  final JeebAvatarFill fill;

  /// Profile photo; falls back to the initial disc when null, blank, or
  /// un-loadable. Blank strings are normalised to null.
  final String? imageUrl;

  /// Optional Ø12 corner dot. Mutually exclusive with [badge].
  final JeebAvatarDot? dot;

  /// Optional Ø26 corner badge. Mutually exclusive with [dot].
  final JeebAvatarBadge? badge;

  /// Ring painted **outside** the disc, so the footprint is
  /// `diameter + 2 × ringWidth`. 2 on the stack, 1 on 04's header, 0 elsewhere.
  final double ringWidth;

  /// Ring ink; defaults to `colorScheme.surface` — the board's "white" ring is
  /// a cutout of the surface behind it, not a literal `#FFFFFF` (§4.1).
  final Color? ringColor;

  /// Makes the disc tappable.
  final VoidCallback? onTap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label for the avatar node.
  final String? semanticLabel;

  /// `Key` forwarded to the composed `OmdsProfileAvatar` — the widget's own
  /// `key` cannot be in two places (04's `client-home-greeting-avatar`).
  final Key? avatarKey;

  /// The measured initial size for [diameter]: exact on the four realized
  /// sizes, [initialSizeRatio] elsewhere (44 → 15.84 ≈ 16, 50 → 18).
  static double initialSizeFor(double diameter) {
    if (diameter == stackDiameter) return 11;
    if (diameter == threadDiameter) return 15;
    if (diameter == headerDiameter) return 17;
    if (diameter == heroDiameter) return 26;
    return diameter * initialSizeRatio;
  }

  /// The letter [initial] resolves to: first non-blank character, uppercased,
  /// `?` when empty. Matches `_GreetingAvatar` and `FeedbackAvatar._initial`, so
  /// a lane may pass either `'N'` or `'Nour'` and the composed
  /// `OmdsProfileAvatar.initial` is `'N'` either way.
  static String initialFrom(String? name) {
    final String trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ({Color fill, Color ink}) ink = _ink(context, scheme);
    final String? url = imageUrl?.trim();

    Widget avatar = OmdsProfileAvatar(
      key: avatarKey,
      initial: initialFrom(initial),
      profilePicUrl: (url == null || url.isEmpty) ? null : url,
      size: diameter,
      backgroundColor: ink.fill,
      initialColor: ink.ink,
      initialFontSize: initialSize ?? initialSizeFor(diameter),
      onTap: onTap,
    );

    if (ringWidth > 0) {
      // Painted as a disc behind the avatar rather than through
      // `OmdsProfileAvatar.border`, whose photo and initial paths disagree on
      // whether the stroke grows the box.
      avatar = Container(
        width: diameter + ringWidth * 2,
        height: diameter + ringWidth * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor ?? scheme.surface,
        ),
        child: avatar,
      );
    }

    final Widget? mark = _mark(context, scheme);
    if (mark != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[avatar, mark],
      );
    }

    if (identifier == null && semanticLabel == null && onTap == null) {
      return avatar;
    }
    // Deliberately NOT `container: true` / `explicitChildNodes: true`: the disc
    // is a leaf whose initial should merge into this node, which is what the
    // shipped `_GreetingAvatar` wrapper does and what its 7 tests read.
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      image: onTap == null,
      button: onTap != null,
      onTap: onTap,
      child: avatar,
    );
  }

  /// The corner dot or badge, positioned directionally so it mirrors in AR.
  Widget? _mark(BuildContext context, ColorScheme scheme) {
    final JeebAvatarDot? dot = this.dot;
    if (dot != null) {
      return PositionedDirectional(
        end: dotOffset,
        top: dot == JeebAvatarDot.unread ? dotOffset : null,
        bottom: dot == JeebAvatarDot.presence ? dotOffset : null,
        child: _Disc(
          key: dotKey,
          diameter: dotDiameter,
          ringWidth: dotRingWidth,
          fill: dot == JeebAvatarDot.presence
              ? context.jeebRoles.success
              : context.jeebRoles.accent,
          ringColor: ringColor ?? scheme.surface,
        ),
      );
    }
    if (badge == null) return null;
    return PositionedDirectional(
      end: badgeOffset,
      bottom: badgeOffset,
      child: _Disc(
        key: badgeKey,
        diameter: badgeDiameter,
        ringWidth: badgeRingWidth,
        fill: context.jeebRoles.accent,
        ringColor: ringColor ?? scheme.surface,
        child: Icon(
          Icons.check,
          size: badgeGlyphSize,
          color: context.jeebRoles.onAccent,
        ),
      ),
    );
  }

  ({Color fill, Color ink}) _ink(BuildContext context, ColorScheme scheme) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final JeebRoles roles = context.jeebRoles;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.light();
    switch (fill) {
      case JeebAvatarFill.primary:
        return tone.onNavy
            ? (fill: tone.chipFill, ink: tone.chipInk)
            : (fill: scheme.primary, ink: scheme.onPrimary);
      case JeebAvatarFill.muted:
        return (fill: semantics.mutedText, ink: scheme.onPrimary);
      case JeebAvatarFill.accent:
        return (fill: roles.accent, ink: roles.onAccent);
      case JeebAvatarFill.dormant:
        return tone.onNavy
            ? (fill: tone.chipFill, ink: tone.mutedInk)
            : (
                fill: scheme.surfaceContainerHighest,
                ink: semantics.mutedText,
              );
      case JeebAvatarFill.onAccent:
        return (
          fill: roles.onAccent.withValues(alpha: 0.2),
          ink: roles.onAccent,
        );
    }
  }
}

/// A filled circle with a ring painted outside it — the dot and the badge share
/// one shape, per §5 #9.
class _Disc extends StatelessWidget {
  const _Disc({
    super.key,
    required this.diameter,
    required this.ringWidth,
    required this.fill,
    required this.ringColor,
    this.child,
  });

  final double diameter;
  final double ringWidth;
  final Color fill;
  final Color ringColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter + ringWidth * 2,
      height: diameter + ringWidth * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: child,
      ),
    );
  }
}
