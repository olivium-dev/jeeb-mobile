import 'package:flutter/material.dart';

import 'jeeb_midnight_palette.dart';

/// App-specific tokens with no Material 3 `ColorScheme` slot (token sheet §3).
/// Only [mutedText] and [inkSoft] are contrast-gated; the rest are decorative.
@immutable
class JeebSemanticColors extends ThemeExtension<JeebSemanticColors> {
  const JeebSemanticColors({
    required this.mutedText,
    required this.mutedSurface,
    required this.readTick,
    required this.accentTint,
    required this.accentRing,
    required this.inkSoft,
    required this.amber,
    required this.orangeBright,
    required this.orangeSoft,
    required this.orangePressed,
    required this.glassFill,
    required this.glassFillEmphasis,
    required this.glassFillPressed,
    required this.glassBorder,
    required this.glassBorderStrong,
    required this.glassBorderVivid,
    required this.accentSelectedFill,
    required this.bubbleOutFill,
    required this.bubbleOutBorder,
  });

  /// Named `.light()` for API stability only.
  factory JeebSemanticColors.light() => JeebSemanticColors.midnight();

  /// Named `.dark()` for API stability only.
  factory JeebSemanticColors.dark() => JeebSemanticColors.midnight();

  /// Token sheet §3.
  factory JeebSemanticColors.midnight() => const JeebSemanticColors(
        mutedText: JeebMidnight.inkMuted,
        mutedSurface: JeebMidnight.surfaceHigh,
        readTick: JeebMidnight.readTick,
        accentTint: JeebMidnight.accentTint,
        accentRing: JeebMidnight.accentRing,
        inkSoft: JeebMidnight.inkSoft,
        amber: JeebMidnight.amber,
        orangeBright: JeebMidnight.orangeBright,
        orangeSoft: JeebMidnight.orangeSoft,
        orangePressed: JeebMidnight.orangePressed,
        glassFill: JeebMidnight.glassFill,
        glassFillEmphasis: JeebMidnight.glassFillEmphasis,
        glassFillPressed: JeebMidnight.glassFillPressed,
        glassBorder: JeebMidnight.glassBorder,
        glassBorderStrong: JeebMidnight.glassBorderStrong,
        glassBorderVivid: JeebMidnight.glassBorderVivid,
        accentSelectedFill: JeebMidnight.accentSelectedFill,
        bubbleOutFill: JeebMidnight.bubbleOutFill,
        bubbleOutBorder: JeebMidnight.bubbleOutBorder,
      );

  /// `#8A93D8`, AA as body text on every navy. Supersedes `#777FC0`/`#9DA3E0`.
  final Color mutedText;

  /// `#10175E` raised navy. A fill only — pair with `onSurface` or [inkSoft].
  final Color mutedSurface;

  /// Read-receipt tick, outgoing bubbles only. Icon ink; not AA as text.
  final Color readTick;

  /// Orange 12% — badge / pill backgrounds.
  final Color accentTint;

  /// Orange 30% — stroke only, never a fill behind content.
  final Color accentRing;

  /// `#B9C0F0` — brighter muted ink; the ink of choice on [mutedSurface].
  final Color inkSoft;

  /// `#FFC107` — stars and ratings. Kept off the accent so it costs no orange.
  final Color amber;

  /// `#FF6A2B` — gradient ends and glow cores.
  final Color orangeBright;

  /// `#FFB27A` — waveform bars and soft accents.
  final Color orangeSoft;

  /// `#C23300` — pressed CTA fill.
  final Color orangePressed;

  /// White 7% — rest glass card fill. No blur: translucency is pre-baked (§4).
  final Color glassFill;

  /// White 10% — capsule / raised glass fill.
  final Color glassFillEmphasis;

  /// White 14% — pressed / active glass fill.
  final Color glassFillPressed;

  /// White 12% — the 1px border every glass surface carries.
  final Color glassBorder;

  /// White 16% — hero capsule border.
  final Color glassBorderStrong;

  /// White 22% — the board's .20–.25 cluster: page-dot inactive, radio ring.
  final Color glassBorderVivid;

  /// Orange 20% — R9's selected card fill. Pair with a 2px accent border and
  /// `JeebShadows.accentSelected`; never use it as ink.
  final Color accentSelectedFill;

  /// Orange 24% — R20's outgoing bubble fill.
  final Color bubbleOutFill;

  /// Orange 45% — R20's outgoing bubble 1px border.
  final Color bubbleOutBorder;

  @override
  JeebSemanticColors copyWith({
    Color? mutedText,
    Color? mutedSurface,
    Color? readTick,
    Color? accentTint,
    Color? accentRing,
    Color? inkSoft,
    Color? amber,
    Color? orangeBright,
    Color? orangeSoft,
    Color? orangePressed,
    Color? glassFill,
    Color? glassFillEmphasis,
    Color? glassFillPressed,
    Color? glassBorder,
    Color? glassBorderStrong,
    Color? glassBorderVivid,
    Color? accentSelectedFill,
    Color? bubbleOutFill,
    Color? bubbleOutBorder,
  }) {
    return JeebSemanticColors(
      mutedText: mutedText ?? this.mutedText,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      readTick: readTick ?? this.readTick,
      accentTint: accentTint ?? this.accentTint,
      accentRing: accentRing ?? this.accentRing,
      inkSoft: inkSoft ?? this.inkSoft,
      amber: amber ?? this.amber,
      orangeBright: orangeBright ?? this.orangeBright,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      orangePressed: orangePressed ?? this.orangePressed,
      glassFill: glassFill ?? this.glassFill,
      glassFillEmphasis: glassFillEmphasis ?? this.glassFillEmphasis,
      glassFillPressed: glassFillPressed ?? this.glassFillPressed,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBorderStrong: glassBorderStrong ?? this.glassBorderStrong,
      glassBorderVivid: glassBorderVivid ?? this.glassBorderVivid,
      accentSelectedFill: accentSelectedFill ?? this.accentSelectedFill,
      bubbleOutFill: bubbleOutFill ?? this.bubbleOutFill,
      bubbleOutBorder: bubbleOutBorder ?? this.bubbleOutBorder,
    );
  }

  @override
  JeebSemanticColors lerp(ThemeExtension<JeebSemanticColors>? other, double t) {
    if (other is! JeebSemanticColors) return this;
    return JeebSemanticColors(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      readTick: Color.lerp(readTick, other.readTick, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      accentRing: Color.lerp(accentRing, other.accentRing, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      orangeBright: Color.lerp(orangeBright, other.orangeBright, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      orangePressed: Color.lerp(orangePressed, other.orangePressed, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassFillEmphasis:
          Color.lerp(glassFillEmphasis, other.glassFillEmphasis, t)!,
      glassFillPressed:
          Color.lerp(glassFillPressed, other.glassFillPressed, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBorderStrong:
          Color.lerp(glassBorderStrong, other.glassBorderStrong, t)!,
      glassBorderVivid:
          Color.lerp(glassBorderVivid, other.glassBorderVivid, t)!,
      accentSelectedFill:
          Color.lerp(accentSelectedFill, other.accentSelectedFill, t)!,
      bubbleOutFill: Color.lerp(bubbleOutFill, other.bubbleOutFill, t)!,
      bubbleOutBorder: Color.lerp(bubbleOutBorder, other.bubbleOutBorder, t)!,
    );
  }
}
